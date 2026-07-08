#pragma once

#include <QFileSystemWatcher>
#include <QObject>
#include <QTimer>
#include <QVariantList>
#include <QtQml/qqml.h>

class UserConfigBackend final : public QObject {
    Q_OBJECT
    QML_NAMED_ELEMENT(UserConfig)
    QML_SINGLETON

    Q_PROPERTY(QString userConfigPath READ userConfigPath CONSTANT FINAL)
    Q_PROPERTY(QString configError READ configError NOTIFY configErrorChanged FINAL)
    Q_PROPERTY(QString defaultWallpaperPath READ defaultWallpaperPath WRITE setDefaultWallpaperPath NOTIFY defaultWallpaperPathChanged FINAL)
    Q_PROPERTY(QString defaultTlpSudoPassword READ defaultTlpSudoPassword WRITE setDefaultTlpSudoPassword NOTIFY defaultTlpSudoPasswordChanged FINAL)

    Q_PROPERTY(QString wallpaperPath READ wallpaperPath NOTIFY wallpaperPathChanged FINAL)
    Q_PROPERTY(QString wallpaperLibraryPath READ wallpaperLibraryPath NOTIFY wallpaperLibraryPathChanged FINAL)
    Q_PROPERTY(bool wallpaperPywalEnabled READ wallpaperPywalEnabled NOTIFY wallpaperPywalEnabledChanged FINAL)
    Q_PROPERTY(QString wallpaperTransitionType READ wallpaperTransitionType NOTIFY wallpaperTransitionTypeChanged FINAL)
    Q_PROPERTY(int wallpaperTransitionStep READ wallpaperTransitionStep NOTIFY wallpaperTransitionStepChanged FINAL)
    Q_PROPERTY(double wallpaperTransitionDuration READ wallpaperTransitionDuration NOTIFY wallpaperTransitionDurationChanged FINAL)
    Q_PROPERTY(int wallpaperTransitionFps READ wallpaperTransitionFps NOTIFY wallpaperTransitionFpsChanged FINAL)
    Q_PROPERTY(int wallpaperTransitionAngle READ wallpaperTransitionAngle NOTIFY wallpaperTransitionAngleChanged FINAL)
    Q_PROPERTY(QString wallpaperTransitionPosition READ wallpaperTransitionPosition NOTIFY wallpaperTransitionPositionChanged FINAL)
    Q_PROPERTY(QString wallpaperTransitionBezier READ wallpaperTransitionBezier NOTIFY wallpaperTransitionBezierChanged FINAL)
    Q_PROPERTY(QString wallpaperTransitionWave READ wallpaperTransitionWave NOTIFY wallpaperTransitionWaveChanged FINAL)
    Q_PROPERTY(bool wallpaperTransitionInvertY READ wallpaperTransitionInvertY NOTIFY wallpaperTransitionInvertYChanged FINAL)
    Q_PROPERTY(QString iconFontFamily READ iconFontFamily NOTIFY iconFontFamilyChanged FINAL)
    Q_PROPERTY(QString textFontFamily READ textFontFamily NOTIFY textFontFamilyChanged FINAL)
    Q_PROPERTY(QString heroFontFamily READ heroFontFamily NOTIFY heroFontFamilyChanged FINAL)
    Q_PROPERTY(QString timeFontFamily READ timeFontFamily NOTIFY timeFontFamilyChanged FINAL)
    Q_PROPERTY(QString tlpSudoPassword READ tlpSudoPassword NOTIFY tlpSudoPasswordChanged FINAL)
    Q_PROPERTY(QString tlpPermissionMode READ tlpPermissionMode NOTIFY tlpPermissionModeChanged FINAL)

    Q_PROPERTY(int workspaceOverviewWindowDragButton READ workspaceOverviewWindowDragButton NOTIFY workspaceOverviewWindowDragButtonChanged FINAL)

    Q_PROPERTY(int dynamicIslandPrimaryButton READ dynamicIslandPrimaryButton NOTIFY dynamicIslandPrimaryButtonChanged FINAL)
    Q_PROPERTY(QString dynamicIslandPrimaryAction READ dynamicIslandPrimaryAction NOTIFY dynamicIslandPrimaryActionChanged FINAL)
    Q_PROPERTY(int dynamicIslandSecondaryButton READ dynamicIslandSecondaryButton NOTIFY dynamicIslandSecondaryButtonChanged FINAL)
    Q_PROPERTY(QString dynamicIslandSecondaryAction READ dynamicIslandSecondaryAction NOTIFY dynamicIslandSecondaryActionChanged FINAL)
    Q_PROPERTY(QVariantList dynamicIslandLeftSwipeItems READ dynamicIslandLeftSwipeItems NOTIFY dynamicIslandLeftSwipeItemsChanged FINAL)
    Q_PROPERTY(bool disableAutoExpandOnTrackChange READ disableAutoExpandOnTrackChange NOTIFY disableAutoExpandOnTrackChangeChanged FINAL)
    Q_PROPERTY(int hoverExpandAction READ hoverExpandAction NOTIFY hoverExpandActionChanged FINAL)
    Q_PROPERTY(bool islandAutoHideEnabled READ islandAutoHideEnabled NOTIFY islandAutoHideEnabledChanged FINAL)
    Q_PROPERTY(int islandAutoHideDelayMs READ islandAutoHideDelayMs NOTIFY islandAutoHideDelayMsChanged FINAL)

    Q_PROPERTY(int islandWidth READ islandWidth NOTIFY islandWidthChanged FINAL)
    Q_PROPERTY(int islandHeight READ islandHeight NOTIFY islandHeightChanged FINAL)
    Q_PROPERTY(int islandPositionX READ islandPositionX NOTIFY islandPositionXChanged FINAL)
    Q_PROPERTY(int bodyFontSize READ bodyFontSize NOTIFY bodyFontSizeChanged FINAL)
    Q_PROPERTY(int titleFontSize READ titleFontSize NOTIFY titleFontSizeChanged FINAL)
    Q_PROPERTY(int iconFontSize READ iconFontSize NOTIFY iconFontSizeChanged FINAL)

public:
    explicit UserConfigBackend(QObject *parent = nullptr);

    QString userConfigPath() const;
    QString configError() const;
    QString defaultWallpaperPath() const;
    QString defaultTlpSudoPassword() const;
    QString wallpaperPath() const;
    QString wallpaperLibraryPath() const;
    bool wallpaperPywalEnabled() const;
    QString wallpaperTransitionType() const;
    int wallpaperTransitionStep() const;
    double wallpaperTransitionDuration() const;
    int wallpaperTransitionFps() const;
    int wallpaperTransitionAngle() const;
    QString wallpaperTransitionPosition() const;
    QString wallpaperTransitionBezier() const;
    QString wallpaperTransitionWave() const;
    bool wallpaperTransitionInvertY() const;
    QString iconFontFamily() const;
    QString textFontFamily() const;
    QString heroFontFamily() const;
    QString timeFontFamily() const;
    QString tlpSudoPassword() const;
    QString tlpPermissionMode() const;
    int workspaceOverviewWindowDragButton() const;
    int dynamicIslandPrimaryButton() const;
    QString dynamicIslandPrimaryAction() const;
    int dynamicIslandSecondaryButton() const;
    QString dynamicIslandSecondaryAction() const;
    const QVariantList &dynamicIslandLeftSwipeItems() const;
    bool disableAutoExpandOnTrackChange() const;
    int hoverExpandAction() const;
    bool islandAutoHideEnabled() const;
    int islandAutoHideDelayMs() const;
    int islandWidth() const;
    int islandHeight() const;
    int islandPositionX() const;
    int bodyFontSize() const;
    int titleFontSize() const;
    int iconFontSize() const;
    void setDefaultWallpaperPath(const QString &path);
    void setDefaultTlpSudoPassword(const QString &password);

    Q_INVOKABLE int mouseButton(const QVariant &button) const;
    Q_INVOKABLE int mouseButtonsMask(const QVariant &buttons) const;
    Q_INVOKABLE void reload();

signals:
    void configErrorChanged();
    void defaultWallpaperPathChanged();
    void defaultTlpSudoPasswordChanged();
    void wallpaperPathChanged();
    void wallpaperLibraryPathChanged();
    void wallpaperPywalEnabledChanged();
    void wallpaperTransitionTypeChanged();
    void wallpaperTransitionStepChanged();
    void wallpaperTransitionDurationChanged();
    void wallpaperTransitionFpsChanged();
    void wallpaperTransitionAngleChanged();
    void wallpaperTransitionPositionChanged();
    void wallpaperTransitionBezierChanged();
    void wallpaperTransitionWaveChanged();
    void wallpaperTransitionInvertYChanged();
    void iconFontFamilyChanged();
    void textFontFamilyChanged();
    void heroFontFamilyChanged();
    void timeFontFamilyChanged();
    void tlpSudoPasswordChanged();
    void tlpPermissionModeChanged();
    void workspaceOverviewWindowDragButtonChanged();
    void dynamicIslandPrimaryButtonChanged();
    void dynamicIslandPrimaryActionChanged();
    void dynamicIslandSecondaryButtonChanged();
    void dynamicIslandSecondaryActionChanged();
    void dynamicIslandLeftSwipeItemsChanged();
    void disableAutoExpandOnTrackChangeChanged();
    void hoverExpandActionChanged();
    void islandAutoHideEnabledChanged();
    void islandAutoHideDelayMsChanged();
    void islandWidthChanged();
    void islandHeightChanged();
    void islandPositionXChanged();
    void bodyFontSizeChanged();
    void titleFontSizeChanged();
    void iconFontSizeChanged();

private:
    void scheduleReload();
    void loadConfig();
    void updateWatchedPaths();
    QString configHome() const;

    QString m_userConfigPath;
    QString m_configError;
    QString m_defaultWallpaperPath;
    QString m_defaultTlpSudoPassword;
    QString m_wallpaperPath;
    QString m_wallpaperLibraryPath;
    bool m_wallpaperPywalEnabled = false;
    QString m_wallpaperTransitionType = QStringLiteral("center");
    int m_wallpaperTransitionStep = 5;
    double m_wallpaperTransitionDuration = 3.0;
    int m_wallpaperTransitionFps = 60;
    int m_wallpaperTransitionAngle = 45;
    QString m_wallpaperTransitionPosition = QStringLiteral("center");
    QString m_wallpaperTransitionBezier = QStringLiteral(".54,0,.34,.99");
    QString m_wallpaperTransitionWave = QStringLiteral("20,20");
    bool m_wallpaperTransitionInvertY = false;
    QString m_iconFontFamily = QStringLiteral("JetBrainsMono Nerd Font");
    QString m_textFontFamily = QStringLiteral("Inter Display");
    QString m_heroFontFamily = QStringLiteral("Inter Display");
    QString m_timeFontFamily = QStringLiteral("Inter Display");
    QString m_tlpSudoPassword;
    QString m_tlpPermissionMode = QStringLiteral("skip");
    int m_workspaceOverviewWindowDragButton = 1;
    int m_dynamicIslandPrimaryButton = 1;
    QString m_dynamicIslandPrimaryAction = QStringLiteral("toggleExpandedPlayer");
    int m_dynamicIslandSecondaryButton = 3;
    QString m_dynamicIslandSecondaryAction = QStringLiteral("toggleControlCenter");
    QVariantList m_dynamicIslandLeftSwipeItems;
    bool m_disableAutoExpandOnTrackChange = false;
    int m_hoverExpandAction = 1;
    bool m_islandAutoHideEnabled = true;
    int m_islandAutoHideDelayMs = 1000;
    int m_islandWidth = 140;
    int m_islandHeight = 38;
    int m_islandPositionX = 50;
    int m_bodyFontSize = 16;
    int m_titleFontSize = 20;
    int m_iconFontSize = 18;

    QFileSystemWatcher m_watcher;
    QTimer m_reloadTimer;
};
