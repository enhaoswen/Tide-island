#include "SystemServices.h"
#include "UserConfigBackend.h"

#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QFutureWatcher>
#include <QImage>
#include <QImageReader>
#include <QImageWriter>
#include <QJsonDocument>
#include <QRegularExpression>
#include <QSaveFile>
#include <QStandardPaths>
#include <QTextStream>
#include <QtConcurrent/QtConcurrent>

#ifdef Q_OS_UNIX
#include <unistd.h>
#endif

#include <algorithm>
#include <cmath>
#include <memory>

namespace {

constexpr qsizetype kMaximumStreamBufferBytes = 64 * 1024;

struct ThumbnailResult {
    QString sourcePath;
    QString cachePath;
    bool cacheAvailable = false;
    bool updated = false;
    QString errorString;
};

QString thumbnailMetadataPath(const QString &cachePath) {
    return cachePath + QStringLiteral(".meta.json");
}

QJsonObject thumbnailMetadata(const QFileInfo &sourceInfo,
                              int targetWidth,
                              int targetHeight,
                              int quality) {
    return {
        {QStringLiteral("sourcePath"), sourceInfo.absoluteFilePath()},
        {QStringLiteral("sourceModifiedMs"), sourceInfo.lastModified().toMSecsSinceEpoch()},
        {QStringLiteral("sourceSize"), sourceInfo.size()},
        {QStringLiteral("targetWidth"), targetWidth},
        {QStringLiteral("targetHeight"), targetHeight},
        {QStringLiteral("quality"), quality}
    };
}

bool thumbnailMetadataMatches(const QString &cachePath, const QJsonObject &expected) {
    if (!QFileInfo::exists(cachePath)) return false;

    QFile metadataFile(thumbnailMetadataPath(cachePath));
    if (!metadataFile.open(QIODevice::ReadOnly)) return false;

    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(metadataFile.readAll(), &parseError);
    return parseError.error == QJsonParseError::NoError
        && document.isObject()
        && document.object() == expected;
}

bool writeThumbnailMetadata(const QString &cachePath, const QJsonObject &metadata, QString *errorString) {
    QSaveFile metadataFile(thumbnailMetadataPath(cachePath));
    if (!metadataFile.open(QIODevice::WriteOnly)) {
        if (errorString) *errorString = metadataFile.errorString();
        return false;
    }

    if (metadataFile.write(QJsonDocument(metadata).toJson(QJsonDocument::Compact)) < 0
        || !metadataFile.commit()) {
        if (errorString) *errorString = metadataFile.errorString();
        return false;
    }

    return true;
}

ThumbnailResult createWallpaperThumbnail(const QString &sourcePath,
                                         const QString &cachePath,
                                         const QString &cacheDir,
                                         int targetWidth,
                                         int targetHeight,
                                         int quality) {
    ThumbnailResult result;
    result.sourcePath = sourcePath;
    result.cachePath = cachePath;

    if (sourcePath.isEmpty() || cachePath.isEmpty() || cacheDir.isEmpty()) {
        result.errorString = QStringLiteral("Missing wallpaper thumbnail path.");
        return result;
    }

    if (targetWidth <= 0 || targetHeight <= 0) {
        result.errorString = QStringLiteral("Invalid wallpaper thumbnail size.");
        return result;
    }

    const QFileInfo sourceInfo(sourcePath);
    if (!sourceInfo.exists() || !sourceInfo.isFile()) {
        result.errorString = QStringLiteral("Wallpaper source file does not exist.");
        return result;
    }

    if (!QDir().mkpath(cacheDir)) {
        result.errorString = QStringLiteral("Could not create wallpaper cache directory.");
        return result;
    }

    const int boundedQuality = std::clamp(quality, 1, 100);
    const QJsonObject expectedMetadata = thumbnailMetadata(
        sourceInfo,
        targetWidth,
        targetHeight,
        boundedQuality
    );
    if (thumbnailMetadataMatches(cachePath, expectedMetadata)) {
        result.cacheAvailable = true;
        return result;
    }

    QImageReader reader(sourcePath);
    reader.setAutoTransform(true);
    const QSize sourceSize = reader.size();
    const QSize requestedSize(targetWidth, targetHeight);
    if (sourceSize.isValid()) {
        const QSize decodeSize = sourceSize.scaled(requestedSize, Qt::KeepAspectRatioByExpanding);
        if (qint64(decodeSize.width()) * decodeSize.height()
                < qint64(sourceSize.width()) * sourceSize.height()) {
            reader.setScaledSize(decodeSize);
        }
    }
    const QImage sourceImage = reader.read();
    if (sourceImage.isNull()) {
        result.errorString = reader.errorString().isEmpty()
            ? QStringLiteral("Could not read wallpaper source image.")
            : reader.errorString();
        return result;
    }

    const QSize targetSize(targetWidth, targetHeight);
    const QImage scaled = sourceImage.scaled(targetSize, Qt::KeepAspectRatioByExpanding, Qt::SmoothTransformation);
    const int cropX = std::max(0, (scaled.width() - targetWidth) / 2);
    const int cropY = std::max(0, (scaled.height() - targetHeight) / 2);
    const QImage cropped = scaled.copy(cropX, cropY, targetWidth, targetHeight);

    QSaveFile output(cachePath);
    if (!output.open(QIODevice::WriteOnly)) {
        result.errorString = output.errorString();
        return result;
    }

    QImageWriter writer(&output, "jpg");
    writer.setQuality(boundedQuality);
    if (!writer.write(cropped)) {
        result.errorString = writer.errorString().isEmpty()
            ? QStringLiteral("Could not write wallpaper thumbnail.")
            : writer.errorString();
        output.cancelWriting();
        return result;
    }

    if (!output.commit()) {
        result.errorString = output.errorString();
        return result;
    }

    result.cacheAvailable = QFileInfo::exists(cachePath);
    result.updated = result.cacheAvailable;
    if (result.cacheAvailable)
        writeThumbnailMetadata(cachePath, expectedMetadata, &result.errorString);
    return result;
}

QString trimCommandOutput(const QByteArray &stdoutData, const QByteArray &stderrData) {
    QString output = QString::fromUtf8(stdoutData).trimmed();
    const QString stderrOutput = QString::fromUtf8(stderrData).trimmed();
    if (!stderrOutput.isEmpty()) {
        if (!output.isEmpty()) output += QLatin1Char('\n');
        output += stderrOutput;
    }
    return output;
}

} // namespace

SystemServices::SystemServices(QObject *parent)
    : QObject(parent) {
    m_cavaLevels = QVariantList{0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0};

    m_notificationRestartTimer.setSingleShot(true);
    m_notificationRestartTimer.setInterval(1200);
    connect(&m_notificationRestartTimer, &QTimer::timeout, this, &SystemServices::startNotificationMonitor);

    m_pipeWireRestartTimer.setSingleShot(true);
    m_pipeWireRestartTimer.setInterval(1200);
    connect(&m_pipeWireRestartTimer, &QTimer::timeout, this, &SystemServices::startPipeWireMonitor);

    m_recordingPortalRestartTimer.setSingleShot(true);
    m_recordingPortalRestartTimer.setInterval(1200);
    connect(&m_recordingPortalRestartTimer, &QTimer::timeout, this, &SystemServices::startRecordingPortalMonitor);

    m_recordingSnapshotDebounceTimer.setSingleShot(true);
    m_recordingSnapshotDebounceTimer.setInterval(250);
    connect(&m_recordingSnapshotDebounceTimer, &QTimer::timeout, this, &SystemServices::requestScreenRecordingSnapshot);

    m_cavaRestartTimer.setSingleShot(true);
    m_cavaRestartTimer.setInterval(1200);
    connect(&m_cavaRestartTimer, &QTimer::timeout, this, &SystemServices::startCava);

    startNotificationMonitor();
    startPipeWireMonitor();
    startRecordingPortalMonitor();
    requestScreenRecordingSnapshot();
}

SystemServices::~SystemServices() {
    m_shuttingDown = true;
    m_notificationRestartTimer.stop();
    m_pipeWireRestartTimer.stop();
    m_recordingPortalRestartTimer.stop();
    m_recordingSnapshotDebounceTimer.stop();
    m_cavaRestartTimer.stop();

    stopProcess(m_notificationMonitor);
    stopProcess(m_pipeWireMonitor);
    stopProcess(m_recordingPortalMonitor);
    stopProcess(m_recordingSnapshot);
    stopProcess(m_tlpSetter);
    stopCava();
}

bool SystemServices::screenRecordingActive() const {
    return m_screenRecordingActive;
}

QVariantList SystemServices::cavaLevels() const {
    return m_cavaLevels;
}

QString SystemServices::findExecutable(const QString &program) const {
    if (program.contains(QLatin1Char('/'))) {
        const QFileInfo fileInfo(program);
        return fileInfo.exists() && fileInfo.isExecutable() ? fileInfo.absoluteFilePath() : QString();
    }

    return QStandardPaths::findExecutable(program);
}

QProcess *SystemServices::startCommand(const QString &program,
                                       const QStringList &arguments,
                                       int timeoutMs,
                                       CommandCallback callback,
                                       const QByteArray &stdinData) {
    const QString executable = findExecutable(program);
    if (executable.isEmpty()) {
        CommandResult result;
        result.errorString = QStringLiteral("%1 is not installed.").arg(program);
        QTimer::singleShot(0, this, [callback, result]() {
            callback(result);
        });
        return nullptr;
    }

    auto *process = new QProcess(this);
    process->setProgram(executable);
    process->setArguments(arguments);
    process->setProcessChannelMode(QProcess::SeparateChannels);

    auto completed = std::make_shared<bool>(false);
    auto timedOut = std::make_shared<bool>(false);
    auto finish = [process, callback, completed, timedOut](const QString &errorString = QString()) {
        if (*completed) return;
        *completed = true;

        CommandResult result;
        result.exitCode = process->exitCode();
        result.exitStatus = process->exitStatus();
        result.stdoutData = process->readAllStandardOutput();
        result.stderrData = process->readAllStandardError();
        result.errorString = errorString;
        result.timedOut = *timedOut;
        if (result.errorString.isEmpty() && result.timedOut)
            result.errorString = QStringLiteral("Command timed out.");
        if (result.errorString.isEmpty() && process->error() != QProcess::UnknownError)
            result.errorString = process->errorString();

        callback(result);
        process->deleteLater();
    };

    auto *timeout = new QTimer(process);
    timeout->setSingleShot(true);
    connect(timeout, &QTimer::timeout, process, [process, timedOut]() {
        *timedOut = true;
        process->kill();
    });

    connect(process, &QProcess::started, process, [process, timeoutMs, timeout, stdinData]() {
        if (timeoutMs > 0)
            timeout->start(timeoutMs);
        if (!stdinData.isEmpty()) {
            process->write(stdinData);
            process->closeWriteChannel();
        }
    });

    connect(process, &QProcess::errorOccurred, process, [finish](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart)
            finish(QStringLiteral("Command failed to start."));
    });

    connect(process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            process, [timeout, finish](int, QProcess::ExitStatus) {
        timeout->stop();
        finish();
    });

    process->start();
    return process;
}

QString SystemServices::commandErrorText(const QString &program, const CommandResult &result) const {
    if (!result.errorString.isEmpty())
        return result.errorString;
    if (result.exitStatus == QProcess::CrashExit)
        return QStringLiteral("%1 crashed.").arg(program);
    if (result.exitCode != 0) {
        const QString output = trimCommandOutput(result.stdoutData, result.stderrData);
        return output.isEmpty()
            ? QStringLiteral("%1 exited with code %2.").arg(program).arg(result.exitCode)
            : output;
    }
    return QString();
}

void SystemServices::stopProcess(QProcess *&process) {
    if (!process) return;

    auto *current = process;
    process = nullptr;
    current->disconnect();
    if (current->state() != QProcess::NotRunning) {
        current->terminate();
        if (!current->waitForFinished(150)) {
            current->kill();
            current->waitForFinished(300);
        }
    }
    current->deleteLater();
}

void SystemServices::startNotificationMonitor() {
    if (m_shuttingDown || m_notificationMonitor) return;
    const QString executable = findExecutable(QStringLiteral("dbus-monitor"));
    if (executable.isEmpty()) {
        qWarning() << "[SystemServices] dbus-monitor is not available; notification mirroring is disabled";
        return;
    }

    m_notificationMonitor = new QProcess(this);
    m_notificationMonitor->setProcessChannelMode(QProcess::MergedChannels);
    m_notificationMonitor->setProgram(executable);
    m_notificationMonitor->setArguments({
        QStringLiteral("--session"),
        QStringLiteral("type='method_call',interface='org.freedesktop.Notifications',member='Notify'")
    });
    connect(m_notificationMonitor, &QProcess::readyReadStandardOutput, this, &SystemServices::handleNotificationOutput);
    connect(m_notificationMonitor, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, [this](int, QProcess::ExitStatus) {
        m_notificationMonitor->deleteLater();
        m_notificationMonitor = nullptr;
        m_notificationBuffer.clear();
        m_notificationCaptureActive = false;
        if (!m_shuttingDown)
            m_notificationRestartTimer.start();
    });
    m_notificationMonitor->start();
}

void SystemServices::startPipeWireMonitor() {
    if (m_shuttingDown || m_pipeWireMonitor) return;
    const QString executable = findExecutable(QStringLiteral("pw-mon"));
    if (executable.isEmpty()) {
        qWarning() << "[SystemServices] pw-mon is not available; PipeWire recording monitoring is disabled";
        return;
    }

    m_pipeWireMonitor = new QProcess(this);
    m_pipeWireMonitor->setProcessChannelMode(QProcess::MergedChannels);
    m_pipeWireMonitor->setProgram(executable);
    m_pipeWireMonitor->setArguments({QStringLiteral("-p"), QStringLiteral("-a")});
    connect(m_pipeWireMonitor, &QProcess::readyReadStandardOutput, this, &SystemServices::handlePipeWireOutput);
    connect(m_pipeWireMonitor, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, [this](int, QProcess::ExitStatus) {
        m_pipeWireMonitor->deleteLater();
        m_pipeWireMonitor = nullptr;
        m_pipeWireBuffer.clear();
        if (!m_shuttingDown)
            m_pipeWireRestartTimer.start();
    });
    m_pipeWireMonitor->start();
}

void SystemServices::startRecordingPortalMonitor() {
    if (m_shuttingDown || m_recordingPortalMonitor) return;
    const QString executable = findExecutable(QStringLiteral("dbus-monitor"));
    if (executable.isEmpty()) {
        qWarning() << "[SystemServices] dbus-monitor is not available; portal recording monitoring is disabled";
        return;
    }

    m_recordingPortalMonitor = new QProcess(this);
    m_recordingPortalMonitor->setProcessChannelMode(QProcess::MergedChannels);
    m_recordingPortalMonitor->setProgram(executable);
    m_recordingPortalMonitor->setArguments({
        QStringLiteral("--session"),
        QStringLiteral("type='method_call',interface='org.freedesktop.portal.ScreenCast'"),
        QStringLiteral("type='signal',sender='org.freedesktop.portal.Desktop',interface='org.freedesktop.portal.Session',member='Closed'")
    });
    connect(m_recordingPortalMonitor, &QProcess::readyReadStandardOutput, this, &SystemServices::handleRecordingPortalOutput);
    connect(m_recordingPortalMonitor, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, [this](int, QProcess::ExitStatus) {
        m_recordingPortalMonitor->deleteLater();
        m_recordingPortalMonitor = nullptr;
        m_recordingPortalBuffer.clear();
        m_pendingScreenCastMember.clear();
        m_pendingSessionCandidate.clear();
        if (!m_shuttingDown)
            m_recordingPortalRestartTimer.start();
    });
    m_recordingPortalMonitor->start();
}

void SystemServices::processLines(QByteArray &buffer,
                                  const QByteArray &chunk,
                                  const std::function<void(const QString &)> &handler) {
    buffer.append(chunk);
    while (buffer.contains('\n')) {
        const int newlineIndex = buffer.indexOf('\n');
        const QByteArray rawLine = buffer.left(newlineIndex);
        buffer.remove(0, newlineIndex + 1);
        handler(QString::fromUtf8(rawLine).trimmed());
    }

    if (buffer.size() > kMaximumStreamBufferBytes) {
        qWarning() << "[SystemServices] Dropping an oversized unterminated monitor line";
        buffer.clear();
    }
}

void SystemServices::handleNotificationOutput() {
    if (!m_notificationMonitor) return;
    processLines(m_notificationBuffer, m_notificationMonitor->readAllStandardOutput(), [this](const QString &line) {
        handleNotificationLine(line);
    });
}

void SystemServices::handlePipeWireOutput() {
    if (!m_pipeWireMonitor) return;
    processLines(m_pipeWireBuffer, m_pipeWireMonitor->readAllStandardOutput(), [this](const QString &line) {
        handlePipeWireLine(line);
    });
}

void SystemServices::handleRecordingPortalOutput() {
    if (!m_recordingPortalMonitor) return;
    processLines(m_recordingPortalBuffer, m_recordingPortalMonitor->readAllStandardOutput(), [this](const QString &line) {
        handleRecordingPortalLine(line);
    });
}

QString SystemServices::decodeDbusMonitorString(const QString &line) const {
    static const QRegularExpression stringPattern(QStringLiteral("^\\s*string \"(.*)\"\\s*$"));
    const QRegularExpressionMatch match = stringPattern.match(line);
    if (!match.hasMatch()) return QString();

    const QString escaped = match.captured(1);
    QString decoded;
    decoded.reserve(escaped.size());

    for (int i = 0; i < escaped.size(); ++i) {
        const QChar ch = escaped.at(i);
        if (ch != QLatin1Char('\\') || i + 1 >= escaped.size()) {
            decoded.append(ch);
            continue;
        }

        const QChar next = escaped.at(++i);
        if (next == QLatin1Char('n')) decoded.append(QLatin1Char('\n'));
        else if (next == QLatin1Char('r')) decoded.append(QLatin1Char('\r'));
        else if (next == QLatin1Char('t')) decoded.append(QLatin1Char('\t'));
        else decoded.append(next);
    }

    return decoded;
}

void SystemServices::handleNotificationLine(const QString &line) {
    if (line.isEmpty()) return;

    if (line.contains(QStringLiteral("member=Notify"))) {
        m_notificationCaptureActive = true;
        m_notificationCaptureStage = 0;
        m_pendingNotificationAppName.clear();
        m_pendingNotificationSummary.clear();
        m_pendingNotificationBody.clear();
        return;
    }

    if (!m_notificationCaptureActive) return;

    switch (m_notificationCaptureStage) {
    case 0:
        if (!line.startsWith(QStringLiteral("string "))) return;
        m_pendingNotificationAppName = decodeDbusMonitorString(line);
        m_notificationCaptureStage = 1;
        return;
    case 1:
        if (!line.startsWith(QStringLiteral("uint32 "))) return;
        m_notificationCaptureStage = 2;
        return;
    case 2:
        if (!line.startsWith(QStringLiteral("string "))) return;
        m_notificationCaptureStage = 3;
        return;
    case 3:
        if (!line.startsWith(QStringLiteral("string "))) return;
        m_pendingNotificationSummary = decodeDbusMonitorString(line);
        m_notificationCaptureStage = 4;
        return;
    case 4:
        if (!line.startsWith(QStringLiteral("string "))) return;
        m_pendingNotificationBody = decodeDbusMonitorString(line);
        emit notificationReceived(m_pendingNotificationAppName, m_pendingNotificationSummary, m_pendingNotificationBody);
        m_notificationCaptureActive = false;
        m_notificationCaptureStage = -1;
        return;
    default:
        m_notificationCaptureActive = false;
        m_notificationCaptureStage = -1;
        return;
    }
}

QString SystemServices::extractHeaderPath(const QString &line) const {
    static const QRegularExpression pathPattern(QStringLiteral("\\bpath=([^;]+);"));
    const QRegularExpressionMatch match = pathPattern.match(line);
    return match.hasMatch() ? match.captured(1) : QString();
}

QString SystemServices::extractObjectPath(const QString &line) const {
    static const QRegularExpression objectPathPattern(QStringLiteral("^object path \"?([^\"\\s]+)\"?"));
    const QRegularExpressionMatch match = objectPathPattern.match(line);
    return match.hasMatch() ? match.captured(1) : QString();
}

bool SystemServices::screenCastMemberHasSessionArgument(const QString &memberName) const {
    return memberName == QLatin1String("SelectSources")
        || memberName == QLatin1String("Start")
        || memberName == QLatin1String("OpenPipeWireRemote");
}

void SystemServices::handleRecordingPortalLine(const QString &line) {
    if (line.isEmpty()) return;

    static const QRegularExpression closedPattern(
        QStringLiteral("^signal\\b.*interface=org\\.freedesktop\\.portal\\.Session; member=Closed"));
    if (closedPattern.match(line).hasMatch()) {
        m_activeScreenCastSessions.remove(extractHeaderPath(line));
        m_pendingScreenCastMember.clear();
        m_pendingSessionCandidate.clear();
        m_recordingSnapshotDebounceTimer.start();
        updateScreenRecordingActive();
        return;
    }

    static const QRegularExpression methodPattern(
        QStringLiteral("^method_call\\b.*interface=org\\.freedesktop\\.portal\\.ScreenCast; member=([A-Za-z0-9_]+)"));
    const QRegularExpressionMatch methodMatch = methodPattern.match(line);
    if (methodMatch.hasMatch()) {
        m_pendingScreenCastMember = methodMatch.captured(1);
        m_pendingSessionCandidate.clear();
        return;
    }

    if (screenCastMemberHasSessionArgument(m_pendingScreenCastMember) && line.startsWith(QStringLiteral("object path "))) {
        const QString sessionPath = extractObjectPath(line);
        if (sessionPath.startsWith(QStringLiteral("/org/freedesktop/portal/desktop/session/"))) {
            m_activeScreenCastSessions.insert(sessionPath);
            m_pendingSessionCandidate = sessionPath;
            if (m_pendingScreenCastMember == QLatin1String("OpenPipeWireRemote")) {
                m_pendingScreenCastMember.clear();
                m_pendingSessionCandidate.clear();
            }
            m_recordingSnapshotDebounceTimer.start();
            updateScreenRecordingActive();
        }
        return;
    }

    if (m_pendingScreenCastMember == QLatin1String("Start") && line.startsWith(QStringLiteral("string "))) {
        m_pendingScreenCastMember.clear();
        m_pendingSessionCandidate.clear();
        return;
    }

    if (m_pendingScreenCastMember == QLatin1String("SelectSources") && line.contains(QStringLiteral("array ["))) {
        m_pendingScreenCastMember.clear();
        m_pendingSessionCandidate.clear();
    }
}

void SystemServices::handlePipeWireLine(const QString &line) {
    if (line.isEmpty()) return;

    const QString lowerLine = line.toLower();
    const bool relevantVideoLine = lowerLine.contains(QStringLiteral("media.class = \"video/source\""))
        || lowerLine.contains(QStringLiteral("media.class = \"stream/input/video\""))
        || lowerLine.contains(QStringLiteral("xdg-desktop-portal"))
        || lowerLine.contains(QStringLiteral("screencast"))
        || lowerLine.contains(QStringLiteral("screen-cast"))
        || lowerLine.contains(QStringLiteral("screen_cast"))
        || lowerLine.contains(QStringLiteral("xdpw"));
    const bool removalMayAffectActiveCapture = m_portalPipeWireActive
        && (lowerLine.contains(QStringLiteral("removed:")) || lowerLine.contains(QStringLiteral("destroyed:")));

    if (relevantVideoLine || removalMayAffectActiveCapture)
        m_recordingSnapshotDebounceTimer.start();
}

bool SystemServices::pipeWireBlockLooksLikeScreenCast(const QString &blockText) const {
    if (!blockText.contains(QStringLiteral("media.class = \"Video/Source\"")))
        return false;

    const QString lowerBlock = blockText.toLower();
    if (lowerBlock.contains(QStringLiteral("media.role = \"camera\"")))
        return false;
    if (lowerBlock.contains(QStringLiteral("v4l2")))
        return false;

    return lowerBlock.contains(QStringLiteral("xdg-desktop-portal"))
        || lowerBlock.contains(QStringLiteral("screencast"))
        || lowerBlock.contains(QStringLiteral("screen-cast"))
        || lowerBlock.contains(QStringLiteral("screen_cast"))
        || lowerBlock.contains(QStringLiteral("xdpw"));
}

void SystemServices::requestScreenRecordingSnapshot() {
    if (m_recordingSnapshot) return;

    m_recordingSnapshot = startCommand(QStringLiteral("pw-cli"), {QStringLiteral("ls"), QStringLiteral("Node")}, 1500,
        [this](const CommandResult &result) {
            m_recordingSnapshot = nullptr;
            if (result.exitCode == 0 && result.exitStatus == QProcess::NormalExit) {
                applyPipeWireSnapshot(QString::fromUtf8(result.stdoutData));
            } else {
                setPortalPipeWireActive(false);
            }
        });
}

void SystemServices::applyPipeWireSnapshot(const QString &text) {
    const QStringList blocks = text.split(QRegularExpression(QStringLiteral("\\n(?=\\s*id\\s+\\d+,)")));
    for (const QString &block : blocks) {
        if (pipeWireBlockLooksLikeScreenCast(block)) {
            setPortalPipeWireActive(true);
            return;
        }
    }

    setPortalPipeWireActive(false);
}

void SystemServices::setPortalPipeWireActive(bool active) {
    if (m_portalPipeWireActive == active) return;
    m_portalPipeWireActive = active;
    updateScreenRecordingActive();
}

void SystemServices::updateScreenRecordingActive() {
    const bool active = !m_activeScreenCastSessions.isEmpty() || m_portalPipeWireActive;
    if (m_screenRecordingActive == active) return;
    m_screenRecordingActive = active;
    emit screenRecordingActiveChanged();
}

void SystemServices::requestHyprlandSnapshot(const QString &requestId, const QString &subject) {
    static const QSet<QString> allowedSubjects = {
        QStringLiteral("clients"),
        QStringLiteral("monitors"),
        QStringLiteral("workspaces"),
        QStringLiteral("activeworkspace")
    };

    if (!allowedSubjects.contains(subject)) {
        emit hyprlandSnapshotReady(requestId, subject, QString(), QStringLiteral("Unsupported Hyprland snapshot type."));
        return;
    }

    startCommand(QStringLiteral("hyprctl"), {subject, QStringLiteral("-j")}, 1500,
        [this, requestId, subject](const CommandResult &result) {
            const QString errorText = commandErrorText(QStringLiteral("hyprctl"), result);
            if (!errorText.isEmpty()) {
                emit hyprlandSnapshotReady(requestId, subject, QString(), errorText);
                return;
            }

            QJsonParseError parseError;
            const QJsonDocument document = QJsonDocument::fromJson(result.stdoutData, &parseError);
            if (parseError.error != QJsonParseError::NoError) {
                emit hyprlandSnapshotReady(requestId, subject, QString(), parseError.errorString());
                return;
            }

            emit hyprlandSnapshotReady(requestId, subject, QString::fromUtf8(document.toJson(QJsonDocument::Compact)), QString());
        });
}

void SystemServices::ensureUserConfigAvailable() {
    if (m_configAppLaunchRequested)
        return;

    const UserConfigBackend config;
    const QFileInfo configInfo(config.userConfigPath());
    if (configInfo.exists() && config.configError().isEmpty())
        return;

    const QString configAppPath = findExecutable(QStringLiteral("tide-island-config-app"));
    if (configAppPath.isEmpty()) {
        qWarning() << "[SystemServices] Could not find tide-island-config-app for missing or invalid user config:"
                   << config.userConfigPath()
                   << config.configError();
        return;
    }

    m_configAppLaunchRequested = true;
    if (!QProcess::startDetached(configAppPath, {})) {
        m_configAppLaunchRequested = false;
        qWarning() << "[SystemServices] Failed to launch config app:" << configAppPath;
    }
}

void SystemServices::generateWallpaperThumbnail(const QString &sourcePath,
                                                const QString &cachePath,
                                                const QString &cacheDir,
                                                int targetWidth,
                                                int targetHeight,
                                                int quality) {
    const QString requestKey = QStringLiteral("%1\x1f%2\x1f%3x%4\x1f%5")
        .arg(sourcePath, cachePath)
        .arg(targetWidth)
        .arg(targetHeight)
        .arg(quality);
    if (m_wallpaperThumbnailRequests.contains(requestKey))
        return;

    m_wallpaperThumbnailRequests.insert(requestKey);
    auto *watcher = new QFutureWatcher<ThumbnailResult>(this);
    connect(watcher, &QFutureWatcher<ThumbnailResult>::finished, this, [this, watcher, requestKey]() {
        const ThumbnailResult result = watcher->result();
        m_wallpaperThumbnailRequests.remove(requestKey);
        emit wallpaperThumbnailFinished(
            result.sourcePath,
            result.cachePath,
            result.cacheAvailable,
            result.updated,
            result.errorString
        );
        watcher->deleteLater();
    });

    watcher->setFuture(QtConcurrent::run(
        createWallpaperThumbnail,
        sourcePath,
        cachePath,
        cacheDir,
        targetWidth,
        targetHeight,
        quality
    ));
}

double SystemServices::parseBrightnessOutput(const QString &text, bool *ok) const {
    if (ok) *ok = false;
    static const QRegularExpression brightnessPattern(QStringLiteral(",(\\d+)%"));
    const QRegularExpressionMatch match = brightnessPattern.match(text);
    if (!match.hasMatch()) return -1.0;

    bool converted = false;
    const double value = match.captured(1).toDouble(&converted) / 100.0;
    if (ok) *ok = converted;
    return std::clamp(value, 0.0, 1.0);
}

void SystemServices::parseVolumeOutput(const QString &text, double *value, bool *muted, bool *ok) const {
    if (value) *value = -1.0;
    if (muted) *muted = false;
    if (ok) *ok = false;

    static const QRegularExpression volumePattern(QStringLiteral("([0-9]*\\.?[0-9]+)"));
    const QRegularExpressionMatch match = volumePattern.match(text);
    if (!match.hasMatch()) return;

    bool converted = false;
    const double parsedValue = match.captured(1).toDouble(&converted);
    if (!converted) return;

    if (value) *value = std::clamp(parsedValue, 0.0, 1.0);
    if (muted) *muted = text.contains(QStringLiteral("MUTED"), Qt::CaseInsensitive);
    if (ok) *ok = true;
}

void SystemServices::requestBrightness() {
    startCommand(QStringLiteral("brightnessctl"), {QStringLiteral("-m")}, 1000,
        [this](const CommandResult &result) {
            const QString errorText = commandErrorText(QStringLiteral("brightnessctl"), result);
            if (!errorText.isEmpty()) {
                emit brightnessSnapshotReady(-1.0, errorText);
                return;
            }

            bool ok = false;
            const double value = parseBrightnessOutput(QString::fromUtf8(result.stdoutData), &ok);
            emit brightnessSnapshotReady(value, ok ? QString() : QStringLiteral("Could not parse brightness output."));
        });
}

void SystemServices::setBrightness(double value) {
    const double nextValue = std::clamp(value, 0.0, 1.0);
    startCommand(QStringLiteral("brightnessctl"),
                 {QStringLiteral("set"), QStringLiteral("%1%").arg(qRound(nextValue * 100.0))},
                 1000,
                 [this, nextValue](const CommandResult &result) {
        const QString errorText = commandErrorText(QStringLiteral("brightnessctl"), result);
        emit brightnessSetFinished(nextValue, errorText.isEmpty(), errorText);
        if (errorText.isEmpty())
            requestBrightness();
    });
}

void SystemServices::requestVolume() {
    startCommand(QStringLiteral("wpctl"),
                 {QStringLiteral("get-volume"), QStringLiteral("@DEFAULT_AUDIO_SINK@")},
                 1000,
                 [this](const CommandResult &result) {
        const QString errorText = commandErrorText(QStringLiteral("wpctl"), result);
        if (!errorText.isEmpty()) {
            emit volumeSnapshotReady(-1.0, false, errorText);
            return;
        }

        double value = -1.0;
        bool muted = false;
        bool ok = false;
        parseVolumeOutput(QString::fromUtf8(result.stdoutData), &value, &muted, &ok);
        emit volumeSnapshotReady(value, muted, ok ? QString() : QStringLiteral("Could not parse volume output."));
    });
}

void SystemServices::setVolume(double value) {
    const double nextValue = std::clamp(value, 0.0, 1.0);
    startCommand(QStringLiteral("wpctl"),
                 {QStringLiteral("set-volume"), QStringLiteral("@DEFAULT_AUDIO_SINK@"), QString::number(nextValue, 'f', 2)},
                 1000,
                 [this, nextValue](const CommandResult &result) {
        const QString errorText = commandErrorText(QStringLiteral("wpctl"), result);
        emit volumeSetFinished(nextValue, errorText.isEmpty(), errorText);
        if (errorText.isEmpty())
            requestVolume();
    });
}

void SystemServices::requestSystemStats() {
    QFile statFile(QStringLiteral("/proc/stat"));
    if (!statFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        emit systemStatsReady(-1.0, -1.0, statFile.errorString());
        return;
    }

    QTextStream statStream(&statFile);
    const QString cpuLine = statStream.readLine();
    statFile.close();

    const QStringList cpuParts = cpuLine.split(QRegularExpression(QStringLiteral("\\s+")), Qt::SkipEmptyParts);
    if (cpuParts.size() < 6 || cpuParts.first() != QLatin1String("cpu")) {
        emit systemStatsReady(-1.0, -1.0, QStringLiteral("Could not parse CPU stats."));
        return;
    }

    qint64 total = 0;
    for (int index = 1; index < cpuParts.size(); ++index)
        total += cpuParts.at(index).toLongLong();
    const qint64 idle = cpuParts.at(4).toLongLong() + cpuParts.at(5).toLongLong();

    double cpuUsage = 0.0;
    if (m_lastCpuTotal >= 0 && m_lastCpuIdle >= 0 && total > m_lastCpuTotal) {
        const qint64 totalDiff = total - m_lastCpuTotal;
        const qint64 idleDiff = idle - m_lastCpuIdle;
        cpuUsage = totalDiff > 0
            ? std::clamp(double(totalDiff - idleDiff) / double(totalDiff), 0.0, 1.0)
            : 0.0;
    }
    m_lastCpuTotal = total;
    m_lastCpuIdle = idle;

    QFile memFile(QStringLiteral("/proc/meminfo"));
    if (!memFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        emit systemStatsReady(cpuUsage, -1.0, memFile.errorString());
        return;
    }

    qint64 totalMem = 0;
    qint64 availableMem = 0;
    const QStringList memLines = QString::fromUtf8(memFile.readAll()).split(QLatin1Char('\n'), Qt::SkipEmptyParts);
    for (const QString &line : memLines) {
        if (line.startsWith(QStringLiteral("MemTotal:"))) {
            const QStringList parts = line.split(QRegularExpression(QStringLiteral("\\s+")), Qt::SkipEmptyParts);
            if (parts.size() >= 2) totalMem = parts.at(1).toLongLong();
        } else if (line.startsWith(QStringLiteral("MemAvailable:"))) {
            const QStringList parts = line.split(QRegularExpression(QStringLiteral("\\s+")), Qt::SkipEmptyParts);
            if (parts.size() >= 2) availableMem = parts.at(1).toLongLong();
        }
    }
    memFile.close();

    const double ramUsage = totalMem > 0
        ? std::clamp(double(totalMem - availableMem) / double(totalMem), 0.0, 1.0)
        : -1.0;
    emit systemStatsReady(cpuUsage, ramUsage, QString());
}

QString SystemServices::parseTlpProfile(const QString &text) const {
    static const QRegularExpression profilePattern(QStringLiteral("TLP profile\\s*=\\s*([a-z-]+)"),
                                                   QRegularExpression::CaseInsensitiveOption);
    const QRegularExpressionMatch match = profilePattern.match(text);
    return match.hasMatch() ? match.captured(1).toLower() : QString();
}

void SystemServices::requestTlpState() {
    if (findExecutable(QStringLiteral("tlp")).isEmpty()) {
        emit tlpStateReady(false, QString(), QString(), QStringLiteral("TLP is not installed."));
        return;
    }

    if (findExecutable(QStringLiteral("tlp-stat")).isEmpty()) {
        emit tlpStateReady(true, QString(), QString(), QString());
        return;
    }

    startCommand(QStringLiteral("tlp-stat"), {QStringLiteral("-s")}, 2000,
        [this](const CommandResult &result) {
            const QString output = trimCommandOutput(result.stdoutData, result.stderrData);
            const QString errorText = commandErrorText(QStringLiteral("tlp-stat"), result);
            emit tlpStateReady(errorText.isEmpty(), parseTlpProfile(output), output, errorText);
        });
}

void SystemServices::setTlpMode(const QString &mode, const QString &sudoPassword) {
    static const QSet<QString> allowedModes = {
        QStringLiteral("power-saver"),
        QStringLiteral("balanced"),
        QStringLiteral("performance")
    };

    const QString normalizedMode = mode.trimmed().toLower();
    if (!allowedModes.contains(normalizedMode)) {
        emit tlpSetFinished(false, 125, QString(), QStringLiteral("Unsupported TLP mode."));
        return;
    }

    if (findExecutable(QStringLiteral("tlp")).isEmpty()) {
        emit tlpSetFinished(false, 127, QString(), QStringLiteral("TLP is not installed."));
        return;
    }

    if (m_tlpSetter) {
        ++m_tlpCommandGeneration;
        m_tlpSetter->kill();
        m_tlpSetter = nullptr;
    }

    QString program;
    QStringList arguments;
    QByteArray stdinData;

#ifdef Q_OS_UNIX
    if (::getuid() == 0) {
        program = QStringLiteral("tlp");
        arguments = {normalizedMode};
    } else
#endif
    {
        const QString password = sudoPassword.trimmed();
        if (password.isEmpty() && !findExecutable(QStringLiteral("pkexec")).isEmpty()) {
            program = QStringLiteral("pkexec");
            arguments = {QStringLiteral("tlp"), normalizedMode};
        } else if (password.isEmpty()) {
            if (findExecutable(QStringLiteral("sudo")).isEmpty()) {
                emit tlpSetFinished(false, 126, QString(), QStringLiteral("pkexec or sudo is not installed."));
                return;
            }
            program = QStringLiteral("sudo");
            arguments = {QStringLiteral("-n"), QStringLiteral("tlp"), normalizedMode};
        } else {
            if (findExecutable(QStringLiteral("sudo")).isEmpty()) {
                emit tlpSetFinished(false, 126, QString(), QStringLiteral("sudo is not installed."));
                return;
            }
            program = QStringLiteral("sudo");
            arguments = {QStringLiteral("-S"), QStringLiteral("-p"), QString(), QStringLiteral("tlp"), normalizedMode};
            stdinData = (password + QLatin1Char('\n')).toUtf8();
        }
    }

    const int commandGeneration = ++m_tlpCommandGeneration;
    m_tlpSetter = startCommand(program, arguments, 10000,
        [this, program, commandGeneration](const CommandResult &result) {
            if (commandGeneration != m_tlpCommandGeneration)
                return;

            m_tlpSetter = nullptr;
            const QString output = trimCommandOutput(result.stdoutData, result.stderrData);
            const QString errorText = commandErrorText(program, result);
            emit tlpSetFinished(errorText.isEmpty(), result.exitCode, output, errorText);
            if (errorText.isEmpty())
                requestTlpState();
        },
        stdinData);
}

void SystemServices::cancelTlpApply() {
    if (!m_tlpSetter) return;
    ++m_tlpCommandGeneration;
    m_tlpSetter->kill();
    m_tlpSetter = nullptr;
}

void SystemServices::setCavaClientActive(const QString &clientId, bool active) {
    const QString normalizedId = clientId.trimmed();
    if (normalizedId.isEmpty()) return;

    if (active)
        m_cavaClients.insert(normalizedId);
    else
        m_cavaClients.remove(normalizedId);

    if (m_cavaClients.isEmpty()) {
        m_cavaRestartTimer.stop();
        stopCava();
        return;
    }

    if (!m_cavaProcess && !m_cavaRestartTimer.isActive())
        startCava();
}

void SystemServices::startCava() {
    if (m_shuttingDown || m_cavaClients.isEmpty() || m_cavaProcess) return;

    const QString executable = findExecutable(QStringLiteral("cava"));
    if (executable.isEmpty()) {
        if (!m_cavaMissingWarned) {
            qWarning() << "[SystemServices] cava is not available; audio visualizer is disabled";
            m_cavaMissingWarned = true;
        }
        return;
    }

    static const QByteArray config =
        "[general]\n"
        "framerate = 30\n"
        "bars = 8\n"
        "autosens = 1\n"
        "[output]\n"
        "method = raw\n"
        "raw_target = /dev/stdout\n"
        "data_format = ascii\n"
        "ascii_max_range = 7\n"
        "channels = mono\n";

    m_cavaProcess = new QProcess(this);
    m_cavaProcess->setProgram(executable);
    m_cavaProcess->setArguments({QStringLiteral("-p"), QStringLiteral("/dev/stdin")});
    m_cavaProcess->setProcessChannelMode(QProcess::MergedChannels);

    connect(m_cavaProcess, &QProcess::started, m_cavaProcess, [this]() {
        if (!m_cavaProcess) return;
        m_cavaProcess->write(config);
        m_cavaProcess->closeWriteChannel();
    });
    connect(m_cavaProcess, &QProcess::readyReadStandardOutput, this, &SystemServices::handleCavaOutput);
    connect(m_cavaProcess, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, [this](int, QProcess::ExitStatus) {
        m_cavaProcess->deleteLater();
        m_cavaProcess = nullptr;
        m_cavaBuffer.clear();
        if (!m_shuttingDown && !m_cavaClients.isEmpty())
            m_cavaRestartTimer.start();
    });

    m_cavaProcess->start();
}

void SystemServices::stopCava() {
    stopProcess(m_cavaProcess);
    m_cavaBuffer.clear();
}

void SystemServices::handleCavaOutput() {
    if (!m_cavaProcess) return;
    processLines(m_cavaBuffer, m_cavaProcess->readAllStandardOutput(), [this](const QString &line) {
        handleCavaLine(line);
    });
}

void SystemServices::handleCavaLine(const QString &line) {
    const QStringList parts = line.split(QLatin1Char(';'));
    if (parts.size() < 8) return;

    QVariantList nextLevels;
    nextLevels.reserve(8);
    bool changed = m_cavaLevels.size() != 8;

    for (int index = 0; index < 8; ++index) {
        bool ok = false;
        const double value = std::clamp(parts.at(index).toDouble(&ok) / 7.0, 0.0, 1.0);
        const double nextValue = ok ? value : 0.0;
        if (!changed && std::abs(m_cavaLevels.at(index).toDouble() - nextValue) >= 0.03)
            changed = true;
        nextLevels.append(nextValue);
    }

    if (!changed) return;
    m_cavaLevels = nextLevels;
    emit cavaLevelsChanged();
}
