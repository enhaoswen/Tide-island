#pragma once

#include <QObject>
#include <QtQml/qqml.h>
#include <QProcess>
#include <QSet>
#include <QFileSystemWatcher>
#include <QSocketNotifier>
#include <QString>
#include <QByteArray>
#include <QTimer>
#include <QVariantMap>
#include <QStringList>

struct udev;
struct udev_monitor;

class SysBackend : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(int batteryCapacity READ batteryCapacity NOTIFY batteryCapacityChanged FINAL)
    Q_PROPERTY(QString batteryStatus READ batteryStatus NOTIFY batteryStatusChanged FINAL)
    Q_PROPERTY(QString lyricsCurrentLyric READ lyricsCurrentLyric NOTIFY lyricsCurrentLyricChanged FINAL)
    Q_PROPERTY(bool lyricsIsSynced READ lyricsIsSynced NOTIFY lyricsIsSyncedChanged FINAL)
    Q_PROPERTY(QString lyricsBackendStatus READ lyricsBackendStatus NOTIFY lyricsBackendStatusChanged FINAL)

public:
    explicit SysBackend(QObject *parent = nullptr);
    ~SysBackend() override;

    int batteryCapacity() const;
    QString batteryStatus() const;
    QString lyricsCurrentLyric() const;
    bool lyricsIsSynced() const;
    QString lyricsBackendStatus() const;
    Q_INVOKABLE void setLyricsClientActive(const QString &clientId, bool active);

signals:
    void brightnessChanged(double val);
    void volumeChanged(int volPercentage, bool isMuted);
    void batteryCapacityChanged(int capacity);
    void batteryStatusChanged(const QString &statusString);
    void batteryChanged(int capacity, const QString &statusString);
    void bluetoothChanged(bool isConnected);
    void lyricsCurrentLyricChanged();
    void lyricsIsSyncedChanged();
    void lyricsBackendStatusChanged();

private slots:
    void handleVolumeEvent();
    void fetchCurrentVolume();
    void handleVolumeQueryFinished(int exitCode, QProcess::ExitStatus exitStatus);
    void handleDefaultSinkQueryFinished(int exitCode, QProcess::ExitStatus exitStatus);
    void handleBatteryMonitorEvent();
    void handleBatteryPropertiesChanged(const QString &interfaceName, const QVariantMap &changedProperties, const QStringList &invalidatedProperties);
    void handleUpowerBatteryChanged();
    void updateBrightness();
    void updateBatterySysfs();
    void updateBatteryUpower();
    void startLyricsBackend();
    void handleLyricsReadyRead();
    void handleLyricsProcessStateChanged(QProcess::ProcessState state);
    void handleLyricsProcessFinished(int exitCode, QProcess::ExitStatus exitStatus);
    void handleLyricsProcessError(QProcess::ProcessError error);
    void handleLyricsStderr();

private:
    void setupBattery();
    void setupBatteryUpower();
    void setupAudio();
    void setupBrightness();
    void setupLyrics();
    void stopLyricsBackend();
    void checkDefaultAudioDevice();
    void startTimedProcess(QProcess *process, QTimer *timeoutTimer, const QString &program, const QStringList &arguments);
    void detectPowerSupplyPaths();
    void detectBacklightPath();
    QString readSysfsTextFile(const QString &path) const;
    void updateBatteryState(int capacity, const QString &statusString);
    QString upowerStateToBatteryStatus(uint state) const;
    QString findLyricsBackendExecutable() const;
    void setLyricsCurrentLyric(const QString &lyric);
    void setLyricsIsSynced(bool synced);
    void setLyricsBackendStatus(const QString &status);

    bool m_isBluetoothAudio = false;
    QProcess *m_paSubscriber;
    QProcess *m_volumeQueryProcess;
    QProcess *m_defaultSinkQueryProcess;
    QFileSystemWatcher *m_brightnessWatcher;
    QSocketNotifier *m_batteryNotifier;
    QTimer *m_audioDebounceTimer;
    QTimer *m_volumeQueryTimeoutTimer;
    QTimer *m_defaultSinkQueryTimeoutTimer;
    QProcess *m_lyricsProcess;
    QTimer *m_lyricsRestartTimer;
    double m_maxBrightness;
    QByteArray m_lyricsStdoutBuffer;
    QString m_lyricsExecutablePath;
    QString m_lyricsCurrentLyric;
    QString m_lyricsBackendStatus;
    bool m_lyricsIsSynced;
    QSet<QString> m_lyricsClients;

    QString m_batteryPath;
    QString m_acPath;
    QString m_backlightPath;
    int m_batteryCap;
    QString m_batteryStatus;
    QString m_upowerBatteryPath;
    bool m_hasBatteryState;

    struct udev *m_udev;
    struct udev_monitor *m_batteryMonitor;
};
