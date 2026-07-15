#include "SysBackend.h"
#include <QFile>
#include <QDir>
#include <QDebug>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#include <QFileInfo>
#include <QDirIterator>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QStandardPaths>
#include <libudev.h>

namespace {
constexpr int kCommandTimeoutMs = 500;
constexpr int kAudioEventDebounceMs = 80;
}

SysBackend::SysBackend(QObject *parent)
    : QObject(parent),
      m_paSubscriber(nullptr),
      m_volumeQueryProcess(nullptr),
      m_defaultSinkQueryProcess(nullptr),
      m_brightnessWatcher(nullptr),
      m_batteryNotifier(nullptr),
      m_audioDebounceTimer(nullptr),
      m_volumeQueryTimeoutTimer(nullptr),
      m_defaultSinkQueryTimeoutTimer(nullptr),
      m_lyricsProcess(nullptr),
      m_lyricsRestartTimer(nullptr),
      m_maxBrightness(1.0),
      m_lyricsStdoutBuffer(),
      m_lyricsExecutablePath(),
      m_lyricsCurrentLyric(),
      m_lyricsBackendStatus("idle"),
      m_lyricsIsSynced(false),
      m_batteryCap(0),
      m_batteryStatus("Unknown"),
      m_upowerBatteryPath(),
      m_hasBatteryState(false),
      m_udev(nullptr),
      m_batteryMonitor(nullptr) {
    setupBattery();
    setupAudio();
    setupBrightness();
    setupLyrics();
}

SysBackend::~SysBackend() {
    stopLyricsBackend();
    if (m_batteryMonitor) udev_monitor_unref(m_batteryMonitor);
    if (m_udev) udev_unref(m_udev);
}

int SysBackend::batteryCapacity() const {
    return m_batteryCap;
}

QString SysBackend::batteryStatus() const {
    return m_batteryStatus;
}

QString SysBackend::lyricsCurrentLyric() const {
    return m_lyricsCurrentLyric;
}

bool SysBackend::lyricsIsSynced() const {
    return m_lyricsIsSynced;
}

QString SysBackend::lyricsBackendStatus() const {
    return m_lyricsBackendStatus;
}

QString SysBackend::readSysfsTextFile(const QString &path) const {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) return "";

    const QString value = QString::fromUtf8(file.readAll()).trimmed();
    file.close();
    return value;
}

// Battery
void SysBackend::setupBattery() {
    detectPowerSupplyPaths();

    updateBatterySysfs();
    setupBatteryUpower();

    if (!m_udev) {
        m_udev = udev_new();
        if (!m_udev) {
            qWarning() << "[Battery] Failed to create udev context for power_supply monitoring";
            return;
        }
    }

    m_batteryMonitor = udev_monitor_new_from_netlink(m_udev, "udev");
    if (!m_batteryMonitor) {
        qWarning() << "[Battery] Failed to create udev monitor for power_supply monitoring";
        return;
    }

    if (udev_monitor_filter_add_match_subsystem_devtype(m_batteryMonitor, "power_supply", nullptr) < 0 ||
        udev_monitor_enable_receiving(m_batteryMonitor) < 0) {
        qWarning() << "[Battery] Failed to enable udev monitor for power_supply monitoring";
        udev_monitor_unref(m_batteryMonitor);
        m_batteryMonitor = nullptr;
        return;
    }

    const int monitorFd = udev_monitor_get_fd(m_batteryMonitor);
    if (monitorFd < 0) {
        qWarning() << "[Battery] Failed to get udev monitor fd for power_supply monitoring";
        udev_monitor_unref(m_batteryMonitor);
        m_batteryMonitor = nullptr;
        return;
    }

    m_batteryNotifier = new QSocketNotifier(monitorFd, QSocketNotifier::Read, this);
    connect(m_batteryNotifier, &QSocketNotifier::activated, this, &SysBackend::handleBatteryMonitorEvent);
}

void SysBackend::detectPowerSupplyPaths() {
    m_batteryPath.clear();
    m_acPath.clear();

    const QDir dir("/sys/class/power_supply");
    const QFileInfoList supplies = dir.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);

    for (const QFileInfo &supplyInfo : supplies) {
        const QString supplyName = supplyInfo.fileName();
        const QString supplyPath = supplyInfo.absoluteFilePath();
        const QString supplyType = readSysfsTextFile(supplyPath + "/type");

        if (m_batteryPath.isEmpty() && (supplyType == "Battery" || supplyName.startsWith("BAT"))) {
            m_batteryPath = supplyPath;
            continue;
        }

        if (m_acPath.isEmpty() &&
            (supplyType == "Mains" || supplyType == "USB" || supplyName.startsWith("AC") || supplyName.startsWith("ADP"))) {
            m_acPath = supplyPath;
        }
    }
}

void SysBackend::setupBatteryUpower() {
    QDBusConnection bus = QDBusConnection::systemBus();
    if (!bus.isConnected()) {
        qWarning() << "[Battery] System DBus is not available for UPower monitoring";
        return;
    }

    QDBusInterface upower(
        "org.freedesktop.UPower",
        "/org/freedesktop/UPower",
        "org.freedesktop.UPower",
        bus,
        this
    );

    if (!upower.isValid()) {
        qWarning() << "[Battery] UPower service is not available";
        return;
    }

    QDBusReply<QDBusObjectPath> displayDeviceReply = upower.call("GetDisplayDevice");
    if (!displayDeviceReply.isValid()) {
        qWarning() << "[Battery] Failed to get UPower display device:" << displayDeviceReply.error().message();
        return;
    }

    m_upowerBatteryPath = displayDeviceReply.value().path();
    if (m_upowerBatteryPath.isEmpty() || m_upowerBatteryPath == "/") {
        qWarning() << "[Battery] Invalid UPower display device path";
        return;
    }

    const bool changedConnected = bus.connect(
        "org.freedesktop.UPower",
        m_upowerBatteryPath,
        "org.freedesktop.UPower.Device",
        "Changed",
        this,
        SLOT(handleUpowerBatteryChanged())
    );

    const bool propertiesConnected = bus.connect(
        "org.freedesktop.UPower",
        m_upowerBatteryPath,
        "org.freedesktop.DBus.Properties",
        "PropertiesChanged",
        this,
        SLOT(handleBatteryPropertiesChanged(QString,QVariantMap,QStringList))
    );

    if (!changedConnected && !propertiesConnected) {
        qWarning() << "[Battery] Failed to connect to UPower battery change signals";
        m_upowerBatteryPath.clear();
        return;
    }

    updateBatteryUpower();
}

void SysBackend::updateBatteryState(int capacity, const QString &statusString) {
    const bool capacityChanged = !m_hasBatteryState || capacity != m_batteryCap;
    const bool statusChanged = !m_hasBatteryState || statusString != m_batteryStatus;

    if (!capacityChanged && !statusChanged) return;

    m_batteryCap = capacity;
    m_batteryStatus = statusString;
    m_hasBatteryState = true;

    qDebug() << "[Battery] State:" << m_batteryCap << "% -" << m_batteryStatus;

    if (capacityChanged) emit batteryCapacityChanged(m_batteryCap);
    if (statusChanged) emit batteryStatusChanged(m_batteryStatus);
    emit batteryChanged(m_batteryCap, m_batteryStatus);
}

QString SysBackend::upowerStateToBatteryStatus(uint state) const {
    switch (state) {
        case 1:
        case 5:
            return "Charging";
        case 2:
        case 6:
            return "Discharging";
        case 3:
            return "Empty";
        case 4:
            return "Full";
        default:
            return "Unknown";
    }
}

void SysBackend::updateBatterySysfs() {
    int currentCap = m_batteryCap;
    QString currentStatus = m_batteryStatus;

    if (!m_batteryPath.isEmpty()) {
        QFile capFile(m_batteryPath + "/capacity");
        if (capFile.open(QIODevice::ReadOnly)) {
            currentCap = capFile.readAll().trimmed().toInt();
            capFile.close();
        }

        QFile statusFile(m_batteryPath + "/status");
        if (statusFile.open(QIODevice::ReadOnly)) {
            currentStatus = QString::fromUtf8(statusFile.readAll()).trimmed();
            statusFile.close();
        }
    }

    if ((currentStatus.isEmpty() || currentStatus == "Unknown") && !m_acPath.isEmpty()) {
        QFile acFile(m_acPath + "/online");
        if (acFile.open(QIODevice::ReadOnly)) {
            int isPlugged = acFile.readAll().trimmed().toInt();
            currentStatus = (isPlugged > 0) ? "Charging" : "Discharging";
            acFile.close();
        }
    }

    updateBatteryState(currentCap, currentStatus);
}

void SysBackend::updateBatteryUpower() {
    if (m_upowerBatteryPath.isEmpty()) return;

    QDBusInterface batteryProps(
        "org.freedesktop.UPower",
        m_upowerBatteryPath,
        "org.freedesktop.DBus.Properties",
        QDBusConnection::systemBus(),
        this
    );

    if (!batteryProps.isValid()) {
        qWarning() << "[Battery] Failed to create UPower battery properties interface";
        return;
    }

    QDBusReply<QVariant> percentageReply = batteryProps.call("Get", "org.freedesktop.UPower.Device", "Percentage");
    QDBusReply<QVariant> stateReply = batteryProps.call("Get", "org.freedesktop.UPower.Device", "State");

    if (!percentageReply.isValid() || !stateReply.isValid()) {
        qWarning() << "[Battery] Failed to read UPower battery properties";
        return;
    }

    const int currentCap = qRound(percentageReply.value().toDouble());
    const QString currentStatus = upowerStateToBatteryStatus(stateReply.value().toUInt());
    updateBatteryState(currentCap, currentStatus);
}

void SysBackend::handleBatteryMonitorEvent() {
    if (!m_batteryMonitor) return;

    bool shouldRefresh = false;
    udev_device *device = nullptr;
    while ((device = udev_monitor_receive_device(m_batteryMonitor)) != nullptr) {
        shouldRefresh = true;
        udev_device_unref(device);
    }

    if (shouldRefresh) updateBatterySysfs();
}

void SysBackend::handleBatteryPropertiesChanged(const QString &interfaceName, const QVariantMap &changedProperties, const QStringList &invalidatedProperties) {
    Q_UNUSED(invalidatedProperties)

    if (interfaceName != "org.freedesktop.UPower.Device") return;
    if (!changedProperties.contains("Percentage") && !changedProperties.contains("State")) return;

    updateBatteryUpower();
}

void SysBackend::handleUpowerBatteryChanged() {
    updateBatteryUpower();
}

// 3. volume
void SysBackend::setupAudio() {
    m_paSubscriber = new QProcess(this);
    m_paSubscriber->setProcessChannelMode(QProcess::MergedChannels);
    connect(m_paSubscriber, &QProcess::readyReadStandardOutput, this, &SysBackend::handleVolumeEvent);

    m_volumeQueryProcess = new QProcess(this);
    m_volumeQueryTimeoutTimer = new QTimer(this);
    m_volumeQueryTimeoutTimer->setSingleShot(true);
    m_volumeQueryTimeoutTimer->setInterval(kCommandTimeoutMs);
    connect(m_volumeQueryTimeoutTimer, &QTimer::timeout, this, [this]() {
        if (m_volumeQueryProcess && m_volumeQueryProcess->state() != QProcess::NotRunning)
            m_volumeQueryProcess->kill();
    });
    connect(m_volumeQueryProcess, qOverload<int, QProcess::ExitStatus>(&QProcess::finished),
            this, &SysBackend::handleVolumeQueryFinished);
    connect(m_volumeQueryProcess, &QProcess::errorOccurred, this, [this](QProcess::ProcessError) {
        if (m_volumeQueryTimeoutTimer) m_volumeQueryTimeoutTimer->stop();
    });

    m_defaultSinkQueryProcess = new QProcess(this);
    m_defaultSinkQueryTimeoutTimer = new QTimer(this);
    m_defaultSinkQueryTimeoutTimer->setSingleShot(true);
    m_defaultSinkQueryTimeoutTimer->setInterval(kCommandTimeoutMs);
    connect(m_defaultSinkQueryTimeoutTimer, &QTimer::timeout, this, [this]() {
        if (m_defaultSinkQueryProcess && m_defaultSinkQueryProcess->state() != QProcess::NotRunning)
            m_defaultSinkQueryProcess->kill();
    });
    connect(m_defaultSinkQueryProcess, qOverload<int, QProcess::ExitStatus>(&QProcess::finished),
            this, &SysBackend::handleDefaultSinkQueryFinished);
    connect(m_defaultSinkQueryProcess, &QProcess::errorOccurred, this, [this](QProcess::ProcessError) {
        if (m_defaultSinkQueryTimeoutTimer) m_defaultSinkQueryTimeoutTimer->stop();
    });

    m_audioDebounceTimer = new QTimer(this);
    m_audioDebounceTimer->setSingleShot(true);
    m_audioDebounceTimer->setInterval(kAudioEventDebounceMs);
    connect(m_audioDebounceTimer, &QTimer::timeout, this, [this]() {
        fetchCurrentVolume();
        checkDefaultAudioDevice();
    });

    m_paSubscriber->start("pactl", QStringList() << "subscribe");
    fetchCurrentVolume();
    checkDefaultAudioDevice();
}

void SysBackend::handleVolumeEvent() {
    QByteArray output = m_paSubscriber->readAllStandardOutput();

    if (output.contains("sink") || output.contains("card") || output.contains("server")) {
        if (m_audioDebounceTimer) m_audioDebounceTimer->start();
    }
}

void SysBackend::fetchCurrentVolume() {
    startTimedProcess(
        m_volumeQueryProcess,
        m_volumeQueryTimeoutTimer,
        QStringLiteral("wpctl"),
        QStringList() << QStringLiteral("get-volume") << QStringLiteral("@DEFAULT_AUDIO_SINK@")
    );
}

void SysBackend::handleVolumeQueryFinished(int exitCode, QProcess::ExitStatus exitStatus) {
    if (m_volumeQueryTimeoutTimer) m_volumeQueryTimeoutTimer->stop();
    if (!m_volumeQueryProcess || exitStatus != QProcess::NormalExit || exitCode != 0) return;

    const QString output = QString::fromUtf8(m_volumeQueryProcess->readAllStandardOutput()).trimmed();

    if (output.startsWith("Volume:")) {
        const bool isMuted = output.contains("[MUTED]");
        const QString valStr = output.section(' ', 1, 1);
        bool ok = false;
        const int volPercentage = static_cast<int>(valStr.toDouble(&ok) * 100);
        if (!ok) return;

        emit volumeChanged(volPercentage, isMuted);
    }
}

// 4. brightness
void SysBackend::setupBrightness() {
    detectBacklightPath();
    if (m_backlightPath.isEmpty()) return;

    const QString maxBrightnessPath = m_backlightPath + "/max_brightness";
    const QString brightnessPath = m_backlightPath + "/brightness";

    const QString maxBrightnessValue = readSysfsTextFile(maxBrightnessPath);
    if (!maxBrightnessValue.isEmpty()) {
        m_maxBrightness = maxBrightnessValue.toDouble();
    }

    QFile bFile(brightnessPath);
    if (!bFile.exists()) return;

    m_brightnessWatcher = new QFileSystemWatcher(this);
    m_brightnessWatcher->addPath(brightnessPath);
    connect(m_brightnessWatcher, &QFileSystemWatcher::fileChanged, this, &SysBackend::updateBrightness);
    updateBrightness();
}

void SysBackend::detectBacklightPath() {
    m_backlightPath.clear();

    const QDir dir("/sys/class/backlight");
    const QFileInfoList backlights = dir.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);

    double bestMaxBrightness = -1.0;
    for (const QFileInfo &backlightInfo : backlights) {
        const QString candidatePath = backlightInfo.absoluteFilePath();
        const QString maxBrightnessValue = readSysfsTextFile(candidatePath + "/max_brightness");
        const QString brightnessValue = readSysfsTextFile(candidatePath + "/brightness");

        if (maxBrightnessValue.isEmpty() || brightnessValue.isEmpty()) continue;

        bool ok = false;
        const double maxBrightness = maxBrightnessValue.toDouble(&ok);
        if (!ok || maxBrightness <= 0) continue;

        if (maxBrightness > bestMaxBrightness) {
            bestMaxBrightness = maxBrightness;
            m_backlightPath = candidatePath;
        }
    }
}

void SysBackend::updateBrightness() {
    if (m_backlightPath.isEmpty()) return;

    QFile bFile(m_backlightPath + "/brightness");
    if (bFile.open(QIODevice::ReadOnly)) {
        double current = QString::fromUtf8(bFile.readAll()).trimmed().toDouble();
        bFile.close();
        if (m_maxBrightness > 0) emit brightnessChanged(current / m_maxBrightness);
        
    }
}

void SysBackend::checkDefaultAudioDevice() {
    startTimedProcess(
        m_defaultSinkQueryProcess,
        m_defaultSinkQueryTimeoutTimer,
        QStringLiteral("pactl"),
        QStringList() << QStringLiteral("get-default-sink")
    );
}

void SysBackend::handleDefaultSinkQueryFinished(int exitCode, QProcess::ExitStatus exitStatus) {
    if (m_defaultSinkQueryTimeoutTimer) m_defaultSinkQueryTimeoutTimer->stop();
    if (!m_defaultSinkQueryProcess || exitStatus != QProcess::NormalExit || exitCode != 0) return;

    const QString sinkName = QString::fromUtf8(m_defaultSinkQueryProcess->readAllStandardOutput()).trimmed();
    const bool isBtNow = sinkName.contains("bluez");

    if (isBtNow != m_isBluetoothAudio) {
        m_isBluetoothAudio = isBtNow;
        emit bluetoothChanged(m_isBluetoothAudio);
    }
}

void SysBackend::startTimedProcess(QProcess *process, QTimer *timeoutTimer, const QString &program, const QStringList &arguments) {
    if (!process || process->state() != QProcess::NotRunning) return;

    if (timeoutTimer) timeoutTimer->stop();
    process->setProgram(program);
    process->setArguments(arguments);
    process->start();
    if (timeoutTimer) timeoutTimer->start();
}

void SysBackend::setupLyrics() {
    m_lyricsProcess = new QProcess(this);
    m_lyricsRestartTimer = new QTimer(this);
    m_lyricsRestartTimer->setSingleShot(true);
    m_lyricsRestartTimer->setInterval(3000);

    connect(m_lyricsRestartTimer, &QTimer::timeout, this, &SysBackend::startLyricsBackend);
    connect(m_lyricsProcess, &QProcess::readyReadStandardOutput, this, &SysBackend::handleLyricsReadyRead);
    connect(m_lyricsProcess, &QProcess::readyReadStandardError, this, &SysBackend::handleLyricsStderr);
    connect(m_lyricsProcess, &QProcess::stateChanged, this, &SysBackend::handleLyricsProcessStateChanged);
    connect(m_lyricsProcess, &QProcess::errorOccurred, this, &SysBackend::handleLyricsProcessError);
    connect(m_lyricsProcess, &QProcess::finished, this, &SysBackend::handleLyricsProcessFinished);

}

void SysBackend::setLyricsClientActive(const QString &clientId, bool active) {
    const QString normalizedId = clientId.trimmed();
    if (normalizedId.isEmpty()) return;

    if (active)
        m_lyricsClients.insert(normalizedId);
    else
        m_lyricsClients.remove(normalizedId);

    if (m_lyricsClients.isEmpty()) {
        stopLyricsBackend();
    } else if (m_lyricsProcess && m_lyricsProcess->state() == QProcess::NotRunning
               && !m_lyricsRestartTimer->isActive()) {
        startLyricsBackend();
    }
}

QString SysBackend::findLyricsBackendExecutable() const {
    const QString homeDir = QDir::homePath();
    const QString quickshellConfigDir = homeDir + "/.config/quickshell";
    const QString envPath = qEnvironmentVariable("QUICKSHELL_LYRICS_BACKEND");
    const QString pathExecutable = QStandardPaths::findExecutable("lyricsmpris");
    QStringList candidates = {
        envPath,
        QStringLiteral("/usr/share/tide-island/bin/lyricsmpris"),
        quickshellConfigDir + "/bin/lyricsmpris",
        homeDir + "/.local/bin/lyricsmpris",
        pathExecutable
    };

    QDirIterator configIterator(
        quickshellConfigDir,
        QDir::Dirs | QDir::NoDotAndDotDot,
        QDirIterator::NoIteratorFlags
    );
    while (configIterator.hasNext()) {
        const QString configDirPath = configIterator.next();
        candidates.insert(1, configDirPath + "/bin/lyricsmpris");
    }

    for (const QString &candidate : candidates) {
        if (candidate.isEmpty()) continue;
        const QFileInfo fileInfo(candidate);
        if (fileInfo.exists() && fileInfo.isFile() && fileInfo.isExecutable()) return fileInfo.absoluteFilePath();
    }

    return QString();
}

void SysBackend::setLyricsCurrentLyric(const QString &lyric) {
    if (m_lyricsCurrentLyric == lyric) return;
    m_lyricsCurrentLyric = lyric;
    emit lyricsCurrentLyricChanged();
}

void SysBackend::setLyricsIsSynced(bool synced) {
    if (m_lyricsIsSynced == synced) return;
    m_lyricsIsSynced = synced;
    emit lyricsIsSyncedChanged();
}

void SysBackend::setLyricsBackendStatus(const QString &status) {
    if (m_lyricsBackendStatus == status) return;
    m_lyricsBackendStatus = status;
    emit lyricsBackendStatusChanged();
}

void SysBackend::startLyricsBackend() {
    if (!m_lyricsProcess) return;
    if (m_lyricsClients.isEmpty()) return;
    if (m_lyricsProcess->state() != QProcess::NotRunning) return;

    m_lyricsExecutablePath = findLyricsBackendExecutable();
    if (m_lyricsExecutablePath.isEmpty()) {
        qWarning() << "[Lyrics] lyricsmpris executable not found";
        setLyricsCurrentLyric("");
        setLyricsIsSynced(false);
        setLyricsBackendStatus("missing");
        return;
    }

    m_lyricsStdoutBuffer.clear();
    setLyricsCurrentLyric("");
    setLyricsIsSynced(false);
    setLyricsBackendStatus("starting");

    m_lyricsProcess->setProgram(m_lyricsExecutablePath);
    m_lyricsProcess->setArguments({ "--pipe" });
    m_lyricsProcess->start();
}

void SysBackend::stopLyricsBackend() {
    if (m_lyricsRestartTimer)
        m_lyricsRestartTimer->stop();
    if (m_lyricsProcess && m_lyricsProcess->state() != QProcess::NotRunning) {
        m_lyricsProcess->terminate();
        if (!m_lyricsProcess->waitForFinished(150)) {
            m_lyricsProcess->kill();
            m_lyricsProcess->waitForFinished(300);
        }
    }

    m_lyricsStdoutBuffer.clear();
    setLyricsCurrentLyric("");
    setLyricsIsSynced(false);
    setLyricsBackendStatus("idle");
}

void SysBackend::handleLyricsReadyRead() {
    if (!m_lyricsProcess) return;

    m_lyricsStdoutBuffer.append(m_lyricsProcess->readAllStandardOutput());

    while (m_lyricsStdoutBuffer.contains('\n')) {
        const int newlineIndex = m_lyricsStdoutBuffer.indexOf('\n');
        const QByteArray rawLine = m_lyricsStdoutBuffer.left(newlineIndex);
        m_lyricsStdoutBuffer.remove(0, newlineIndex + 1);

        const QString lyricLine = QString::fromUtf8(rawLine).trimmed();
        if (lyricLine.isEmpty()) {
            setLyricsCurrentLyric("");
            setLyricsIsSynced(false);
            if (m_lyricsProcess->state() == QProcess::Running) setLyricsBackendStatus("running");
            continue;
        }

        QJsonParseError parseError;
        const QJsonDocument document = QJsonDocument::fromJson(rawLine, &parseError);
        if (parseError.error == QJsonParseError::NoError && document.isObject()) {
            const QJsonObject object = document.object();
            const QString type = object.value(QStringLiteral("type")).toString();

            if (type == QLatin1String("status")) {
                const QString status = object.value(QStringLiteral("status")).toString();
                if (!status.isEmpty()) setLyricsBackendStatus(status);
                continue;
            }

            if (type == QLatin1String("line")) {
                const QString text = object.value(QStringLiteral("text")).toString();
                const bool synced = object.value(QStringLiteral("synced")).toBool(false);
                setLyricsCurrentLyric(text);
                setLyricsIsSynced(synced && !text.isEmpty());
                if (!text.isEmpty()) setLyricsBackendStatus(synced ? QStringLiteral("synced") : QStringLiteral("plain"));
                else if (m_lyricsProcess->state() == QProcess::Running) setLyricsBackendStatus("running");
                continue;
            }
        }

        setLyricsCurrentLyric(lyricLine);
        setLyricsIsSynced(true);
        setLyricsBackendStatus("synced");
    }
}

void SysBackend::handleLyricsProcessStateChanged(QProcess::ProcessState state) {
    if (state == QProcess::Running && !m_lyricsIsSynced) {
        setLyricsBackendStatus("running");
    }
}

void SysBackend::handleLyricsProcessFinished(int exitCode, QProcess::ExitStatus exitStatus) {
    Q_UNUSED(exitCode)
    Q_UNUSED(exitStatus)

    setLyricsCurrentLyric("");
    setLyricsIsSynced(false);

    if (!m_lyricsClients.isEmpty() && !m_lyricsExecutablePath.isEmpty()) {
        setLyricsBackendStatus("error");
        m_lyricsRestartTimer->start();
    }
}

void SysBackend::handleLyricsProcessError(QProcess::ProcessError error) {
    setLyricsCurrentLyric("");
    setLyricsIsSynced(false);

    if (error == QProcess::FailedToStart) {
        setLyricsBackendStatus("missing");
        return;
    }

    setLyricsBackendStatus("error");
    if (!m_lyricsClients.isEmpty() && m_lyricsRestartTimer && !m_lyricsRestartTimer->isActive())
        m_lyricsRestartTimer->start();
}

void SysBackend::handleLyricsStderr() {
    if (!m_lyricsProcess) return;

    const QString stderrText = QString::fromUtf8(m_lyricsProcess->readAllStandardError()).trimmed();
    if (stderrText.isEmpty()) return;

    qWarning().noquote() << "[Lyrics]" << stderrText;
}
