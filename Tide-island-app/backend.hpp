#pragma once

#include <QObject>
#include <QString>
#include <QVariantMap>
#include <QVariantList>

#include <unordered_map>

struct QStringHash {
    std::size_t operator()(const QString &key) const noexcept;
};

using UserConfigMap = std::unordered_map<QString, QVariant, QStringHash>;

class Backend final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString userConfigPath READ userConfigPath CONSTANT)
    Q_PROPERTY(QString errorString READ errorString NOTIFY errorStringChanged)
    Q_PROPERTY(QVariantMap userConfig READ userConfig CONSTANT)

public:
    explicit Backend(QObject *parent = nullptr);

    QString userConfigPath() const;
    QString errorString() const;
    QVariantMap userConfig() const;

    Q_INVOKABLE bool save(const QVariantMap &userConfig);
    Q_INVOKABLE bool copyToClipboard(const QString &text);
    Q_INVOKABLE QVariantList shortcutBindings() const;
    Q_INVOKABLE QString currentCompositor() const;
    Q_INVOKABLE QString compositorDisplayName() const;
    Q_INVOKABLE bool supportsTideWorkspaceOverview() const;
    Q_INVOKABLE bool supportsHyprlandShortcutSnippets() const;
    Q_INVOKABLE bool supportsNiriShortcutSnippets() const;
    Q_INVOKABLE QString nightLightBackendName() const;
    Q_INVOKABLE QString niriConfigCommands() const;
    Q_INVOKABLE bool niriShortcutBindingsNeedApply() const;
    Q_INVOKABLE bool ensureNiriShortcutBindings();
    Q_INVOKABLE bool applyShortcutBindings(const QVariantList &shortcutBindings);
    Q_INVOKABLE QString applicationLauncherFavoritesPath() const;
    Q_INVOKABLE QVariantList applicationLauncherFavoriteEntries() const;
    Q_INVOKABLE bool saveApplicationLauncherFavorites(const QVariantList &favoriteIds);
    Q_INVOKABLE bool toggleApplicationLauncher();

signals:
    void errorStringChanged();

private:
    QString hyprlandConfigPath() const;
    QString hyprlandLuaConfigPath() const;
    QString niriConfigPath() const;
    QString managedShortcutConfigPath() const;
    QString managedNiriShortcutConfigPath() const;
    bool writeManagedShortcutConfig(const QVariantList &shortcutBindings);
    bool writeManagedShortcutLuaConfig(const QVariantList &shortcutBindings);
    bool hyprlandUsesLuaConfig() const;
    bool installManagedNiriShortcutConfig(const QVariantList &shortcutBindings);
    bool ensureManagedShortcutSource();
    bool reloadHyprland();
    bool validateNiriConfig(const QString &configText);
    void load();
    void setErrorString(const QString &errorString);
    QVariantMap toVariantMap() const;
    void setUserConfig(const QVariantMap &userConfig);

    QString m_userConfigPath;
    QString m_errorString;
    UserConfigMap m_userConfig;
};
