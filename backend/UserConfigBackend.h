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
    Q_PROPERTY(QString iconFontFamily READ iconFontFamily NOTIFY iconFontFamilyChanged FINAL)
    Q_PROPERTY(QString textFontFamily READ textFontFamily NOTIFY textFontFamilyChanged FINAL)
    Q_PROPERTY(QString heroFontFamily READ heroFontFamily NOTIFY heroFontFamilyChanged FINAL)
    Q_PROPERTY(QString timeFontFamily READ timeFontFamily NOTIFY timeFontFamilyChanged FINAL)
    Q_PROPERTY(QString tlpSudoPassword READ tlpSudoPassword NOTIFY tlpSudoPasswordChanged FINAL)
    Q_PROPERTY(QString tlpPermissionMode READ tlpPermissionMode NOTIFY tlpPermissionModeChanged FINAL)

    Q_PROPERTY(QString overviewGlobalShortcutAppid READ overviewGlobalShortcutAppid NOTIFY overviewGlobalShortcutAppidChanged FINAL)
    Q_PROPERTY(QString overviewGlobalShortcutName READ overviewGlobalShortcutName NOTIFY overviewGlobalShortcutNameChanged FINAL)

    Q_PROPERTY(int workspaceOverviewWindowDragButton READ workspaceOverviewWindowDragButton NOTIFY workspaceOverviewWindowDragButtonChanged FINAL)

    Q_PROPERTY(int dynamicIslandPrimaryButton READ dynamicIslandPrimaryButton NOTIFY dynamicIslandPrimaryButtonChanged FINAL)
    Q_PROPERTY(QString dynamicIslandPrimaryAction READ dynamicIslandPrimaryAction NOTIFY dynamicIslandPrimaryActionChanged FINAL)
    Q_PROPERTY(int dynamicIslandSecondaryButton READ dynamicIslandSecondaryButton NOTIFY dynamicIslandSecondaryButtonChanged FINAL)
    Q_PROPERTY(QString dynamicIslandSecondaryAction READ dynamicIslandSecondaryAction NOTIFY dynamicIslandSecondaryActionChanged FINAL)
    Q_PROPERTY(QVariantList dynamicIslandLeftSwipeItems READ dynamicIslandLeftSwipeItems NOTIFY dynamicIslandLeftSwipeItemsChanged FINAL)

public:
    explicit UserConfigBackend(QObject *parent = nullptr);

    QString userConfigPath() const;
    QString configError() const;
    QString defaultWallpaperPath() const;
    QString defaultTlpSudoPassword() const;
    QString wallpaperPath() const;
    QString iconFontFamily() const;
    QString textFontFamily() const;
    QString heroFontFamily() const;
    QString timeFontFamily() const;
    QString tlpSudoPassword() const;
    QString tlpPermissionMode() const;
    QString overviewGlobalShortcutAppid() const;
    QString overviewGlobalShortcutName() const;
    int workspaceOverviewWindowDragButton() const;
    int dynamicIslandPrimaryButton() const;
    QString dynamicIslandPrimaryAction() const;
    int dynamicIslandSecondaryButton() const;
    QString dynamicIslandSecondaryAction() const;
    const QVariantList &dynamicIslandLeftSwipeItems() const;
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
    void iconFontFamilyChanged();
    void textFontFamilyChanged();
    void heroFontFamilyChanged();
    void timeFontFamilyChanged();
    void tlpSudoPasswordChanged();
    void tlpPermissionModeChanged();
    void overviewGlobalShortcutAppidChanged();
    void overviewGlobalShortcutNameChanged();
    void workspaceOverviewWindowDragButtonChanged();
    void dynamicIslandPrimaryButtonChanged();
    void dynamicIslandPrimaryActionChanged();
    void dynamicIslandSecondaryButtonChanged();
    void dynamicIslandSecondaryActionChanged();
    void dynamicIslandLeftSwipeItemsChanged();

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
    QString m_iconFontFamily = QStringLiteral("JetBrainsMono Nerd Font");
    QString m_textFontFamily = QStringLiteral("Inter Display");
    QString m_heroFontFamily = QStringLiteral("Inter Display");
    QString m_timeFontFamily = QStringLiteral("Inter Display");
    QString m_tlpSudoPassword;
    QString m_tlpPermissionMode = QStringLiteral("ask");
    QString m_overviewGlobalShortcutAppid = QStringLiteral("quickshell");
    QString m_overviewGlobalShortcutName = QStringLiteral("dynamic-island-overview");
    int m_workspaceOverviewWindowDragButton = 1;
    int m_dynamicIslandPrimaryButton = 1;
    QString m_dynamicIslandPrimaryAction = QStringLiteral("toggleExpandedPlayer");
    int m_dynamicIslandSecondaryButton = 3;
    QString m_dynamicIslandSecondaryAction = QStringLiteral("toggleControlCenter");
    QVariantList m_dynamicIslandLeftSwipeItems;

    QFileSystemWatcher m_watcher;
    QTimer m_reloadTimer;
};
