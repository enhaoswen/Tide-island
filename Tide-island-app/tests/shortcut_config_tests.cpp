#include "backend.hpp"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QTemporaryDir>
#include <QTest>

namespace {
bool writeTextFile(const QString &path, const QByteArray &contents, QFileDevice::Permissions permissions = {})
{
    QFileInfo info(path);
    if (!QDir().mkpath(info.absolutePath()))
        return false;

    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text))
        return false;
    file.write(contents);
    file.close();

    if (permissions != QFileDevice::Permissions{})
        return file.setPermissions(permissions);
    return true;
}

QString readTextFile(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return QString();
    return QString::fromUtf8(file.readAll());
}
}

class ShortcutConfigTests : public QObject {
    Q_OBJECT

private slots:
    void hyprlandDefaultsIncludeWorkspaceOverview();
    void defaultsIncludeNotificationHistory();
    void defaultsIncludeApplicationLauncher();
    void applicationLauncherFavoritesPersistAndResolveNames();
    void disabledShortcutPersistsAndIsNotGenerated();
    void disabledShortcutUpdatesActiveHyprlandLuaBlock();
    void hyprlandDesktopWinsOverInheritedNiriSocket();
    void niriDefaultsExcludeWorkspaceOverview();
    void niriConfigUsesNiriKeyNames();
    void niriShortcutBindingsCanBeInstalled();
    void hyprlandSessionPreconfiguresNiriShortcuts();
    void niriConfigEnvironmentOverrideIsUsed();
    void niriValidationFailurePreservesManagedConfig();
    void niriValidationFailureDoesNotIncludeManagedFile();
};

void ShortcutConfigTests::hyprlandDefaultsIncludeWorkspaceOverview()
{
    QTemporaryDir configHome;
    QVERIFY(configHome.isValid());
    qputenv("XDG_CONFIG_HOME", configHome.path().toLocal8Bit());
    qputenv("TIDE_ISLAND_COMPOSITOR", "hyprland");

    Backend backend;
    QVERIFY(backend.supportsTideWorkspaceOverview());
    QCOMPARE(backend.compositorDisplayName(), QStringLiteral("Hyprland"));

    bool foundOverview = false;
    for (const QVariant &value : backend.shortcutBindings()) {
        const QVariantMap binding = value.toMap();
        foundOverview = foundOverview
            || (binding.value(QStringLiteral("target")).toString() == QStringLiteral("overview")
                && binding.value(QStringLiteral("method")).toString() == QStringLiteral("toggle"));
    }
    QVERIFY(foundOverview);
}

void ShortcutConfigTests::defaultsIncludeNotificationHistory()
{
    QTemporaryDir configHome;
    QVERIFY(configHome.isValid());
    qputenv("XDG_CONFIG_HOME", configHome.path().toLocal8Bit());
    qputenv("TIDE_ISLAND_COMPOSITOR", "hyprland");

    Backend backend;
    bool foundNotificationHistory = false;
    for (const QVariant &value : backend.shortcutBindings()) {
        const QVariantMap binding = value.toMap();
        foundNotificationHistory = foundNotificationHistory
            || (binding.value(QStringLiteral("mods")).toString() == QStringLiteral("SUPER")
                && binding.value(QStringLiteral("key")).toString() == QStringLiteral("N")
                && binding.value(QStringLiteral("target")).toString() == QStringLiteral("tide")
                && binding.value(QStringLiteral("method")).toString() == QStringLiteral("toggleNotificationCenter"));
    }
    QVERIFY(foundNotificationHistory);
}

void ShortcutConfigTests::defaultsIncludeApplicationLauncher()
{
    QTemporaryDir configHome;
    QVERIFY(configHome.isValid());
    qputenv("XDG_CONFIG_HOME", configHome.path().toLocal8Bit());
    qputenv("TIDE_ISLAND_COMPOSITOR", "hyprland");

    Backend backend;
    bool foundApplicationLauncher = false;
    for (const QVariant &value : backend.shortcutBindings()) {
        const QVariantMap binding = value.toMap();
        foundApplicationLauncher = foundApplicationLauncher
            || (binding.value(QStringLiteral("mods")).toString() == QStringLiteral("SUPER")
                && binding.value(QStringLiteral("key")).toString() == QStringLiteral("slash")
                && binding.value(QStringLiteral("target")).toString() == QStringLiteral("tide")
                && binding.value(QStringLiteral("method")).toString() == QStringLiteral("toggleApplicationLauncher"));
    }
    QVERIFY(foundApplicationLauncher);
}

void ShortcutConfigTests::applicationLauncherFavoritesPersistAndResolveNames()
{
    QTemporaryDir configHome;
    QTemporaryDir dataHome;
    QVERIFY(configHome.isValid());
    QVERIFY(dataHome.isValid());
    qputenv("XDG_CONFIG_HOME", configHome.path().toLocal8Bit());
    qputenv("XDG_DATA_HOME", dataHome.path().toLocal8Bit());

    QVERIFY(writeTextFile(
        dataHome.path() + QStringLiteral("/applications/org.example.Editor.desktop"),
        "[Desktop Entry]\nName=Example Editor\nType=Application\n"));

    Backend backend;
    QVERIFY(backend.saveApplicationLauncherFavorites({
        QStringLiteral("org.example.Editor"),
        QString(),
        QStringLiteral("org.example.Editor"),
    }));

    QCOMPARE(
        backend.applicationLauncherFavoritesPath(),
        configHome.path() + QStringLiteral("/tide-island/application-launcher.json"));
    QVERIFY(readTextFile(backend.applicationLauncherFavoritesPath())
        .contains(QStringLiteral("\"favoriteIds\"")));

    const QVariantList entries = backend.applicationLauncherFavoriteEntries();
    QCOMPARE(entries.size(), 1);
    QCOMPARE(entries.first().toMap().value(QStringLiteral("id")).toString(),
        QStringLiteral("org.example.Editor"));
    QCOMPARE(entries.first().toMap().value(QStringLiteral("name")).toString(),
        QStringLiteral("Example Editor"));
}

void ShortcutConfigTests::disabledShortcutPersistsAndIsNotGenerated()
{
    QTemporaryDir configHome;
    QVERIFY(configHome.isValid());
    qputenv("XDG_CONFIG_HOME", configHome.path().toLocal8Bit());
    qputenv("TIDE_ISLAND_COMPOSITOR", "niri");

    Backend backend;
    QVariantList bindings = backend.shortcutBindings();
    bool disabledPlayer = false;
    for (QVariant &value : bindings) {
        QVariantMap binding = value.toMap();
        if (binding.value(QStringLiteral("target")).toString() == QStringLiteral("tide")
            && binding.value(QStringLiteral("method")).toString() == QStringLiteral("togglePlayer")) {
            binding.insert(QStringLiteral("mods"), QString());
            binding.insert(QStringLiteral("key"), QString());
            value = binding;
            disabledPlayer = true;
        }
    }
    QVERIFY(disabledPlayer);

    QVariantMap config;
    config.insert(QStringLiteral("shortcutBindings"), bindings);
    QVERIFY(backend.save(config));

    Backend reloaded;
    bool foundDisabledPlayer = false;
    for (const QVariant &value : reloaded.shortcutBindings()) {
        const QVariantMap binding = value.toMap();
        if (binding.value(QStringLiteral("target")).toString() == QStringLiteral("tide")
            && binding.value(QStringLiteral("method")).toString() == QStringLiteral("togglePlayer")) {
            QVERIFY(binding.value(QStringLiteral("mods")).toString().isEmpty());
            QVERIFY(binding.value(QStringLiteral("key")).toString().isEmpty());
            foundDisabledPlayer = true;
        }
    }
    QVERIFY(foundDisabledPlayer);
    QVERIFY(!reloaded.niriConfigCommands().contains(QStringLiteral("togglePlayer")));
}

void ShortcutConfigTests::disabledShortcutUpdatesActiveHyprlandLuaBlock()
{
    QTemporaryDir configHome;
    QTemporaryDir fakeBin;
    QVERIFY(configHome.isValid());
    QVERIFY(fakeBin.isValid());
    qputenv("XDG_CONFIG_HOME", configHome.path().toLocal8Bit());
    qputenv("TIDE_ISLAND_COMPOSITOR", "hyprland");

    const QByteArray originalPath = qgetenv("PATH");
    qputenv("PATH", fakeBin.path().toLocal8Bit() + ':' + originalPath);
    QVERIFY(writeTextFile(fakeBin.path() + QStringLiteral("/hyprctl"),
        "#!/bin/sh\n"
        "if test \"$1\" = binds; then echo 'dispatcher: __lua'; fi\n"
        "exit 0\n",
        QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ExeOwner));

    const QString luaConfig = configHome.path() + QStringLiteral("/hypr/hyprland.lua");
    QVERIFY(writeTextFile(luaConfig,
        "local preserved = true\n\n"
        "-- Tide Island shortcuts.\n"
        "-- legacy generated block\n"
        "hl.bind(\"SUPER + M\", hl.dsp.exec_cmd(\"old player\"))\n\n"
        "for i = 1, 10 do\n"
        "    local key = i % 10\n"
        "end\n"));

    Backend backend;
    QVariantList bindings = backend.shortcutBindings();
    for (QVariant &value : bindings) {
        QVariantMap binding = value.toMap();
        if (binding.value(QStringLiteral("method")).toString() == QStringLiteral("togglePlayer")) {
            binding.insert(QStringLiteral("mods"), QString());
            binding.insert(QStringLiteral("key"), QString());
            value = binding;
        }
    }
    QVERIFY(backend.applyShortcutBindings(bindings));

    const QString updatedLua = readTextFile(luaConfig);
    QVERIFY(updatedLua.contains(QStringLiteral("local preserved = true")));
    QVERIFY(updatedLua.contains(QStringLiteral("Tide Island shortcuts: begin")));
    QVERIFY(updatedLua.contains(QStringLiteral("for i = 1, 10 do")));
    QVERIFY(updatedLua.contains(QStringLiteral("toggleControlCenter")));
    QVERIFY(!updatedLua.contains(QStringLiteral("togglePlayer")));

    qputenv("PATH", originalPath);
}

void ShortcutConfigTests::hyprlandDesktopWinsOverInheritedNiriSocket()
{
    QTemporaryDir configHome;
    QVERIFY(configHome.isValid());
    qputenv("XDG_CONFIG_HOME", configHome.path().toLocal8Bit());
    qunsetenv("TIDE_ISLAND_COMPOSITOR");
    qputenv("XDG_CURRENT_DESKTOP", "Hyprland");
    qputenv("NIRI_SOCKET", "/tmp/inherited-niri.sock");

    Backend backend;
    QCOMPARE(backend.currentCompositor(), QStringLiteral("hyprland"));
    QVERIFY(backend.supportsTideWorkspaceOverview());
}

void ShortcutConfigTests::niriDefaultsExcludeWorkspaceOverview()
{
    QTemporaryDir configHome;
    QVERIFY(configHome.isValid());
    qputenv("XDG_CONFIG_HOME", configHome.path().toLocal8Bit());
    qputenv("TIDE_ISLAND_COMPOSITOR", "niri");

    Backend backend;
    QVERIFY(!backend.supportsTideWorkspaceOverview());
    QVERIFY(backend.supportsNiriShortcutSnippets());
    QCOMPARE(backend.shortcutBindings().size(), 9);

    for (const QVariant &value : backend.shortcutBindings()) {
        const QVariantMap binding = value.toMap();
        QVERIFY(binding.value(QStringLiteral("target")).toString() != QStringLiteral("overview"));
    }
}

void ShortcutConfigTests::niriConfigUsesNiriKeyNames()
{
    QTemporaryDir configHome;
    QVERIFY(configHome.isValid());
    qputenv("XDG_CONFIG_HOME", configHome.path().toLocal8Bit());
    qputenv("TIDE_ISLAND_COMPOSITOR", "niri");

    Backend backend;
    const QString config = backend.niriConfigCommands();
    QVERIFY(config.contains(QStringLiteral("binds {")));
    QVERIFY(config.contains(QStringLiteral("\"--any-display\"")));
    QVERIFY(config.contains(QStringLiteral("Super+Right")));
    QVERIFY(config.contains(QStringLiteral("\"tide\" \"swipeRight\"")));
    QVERIFY(!config.contains(QStringLiteral("\"tide\" \"showLyrics\"")));
    QVERIFY(config.contains(QStringLiteral("Super+W")));
    QVERIFY(config.contains(QStringLiteral("\"tide\" \"toggleWallpaperPicker\"")));
    QVERIFY(config.contains(QStringLiteral("Super+slash")));
    QVERIFY(config.contains(QStringLiteral("\"tide\" \"toggleApplicationLauncher\"")));
    QVERIFY(config.contains(QStringLiteral("Super+N")));
    QVERIFY(config.contains(QStringLiteral("\"tide\" \"toggleNotificationCenter\"")));
    QVERIFY(!config.contains(QStringLiteral("overview")));
    QVERIFY(!config.contains(QStringLiteral("Super+Tab")));
    QVERIFY(!config.contains(QStringLiteral("SUPER+TAB")));
}

void ShortcutConfigTests::niriShortcutBindingsCanBeInstalled()
{
    QTemporaryDir configHome;
    QVERIFY(configHome.isValid());
    QTemporaryDir fakeBin;
    QVERIFY(fakeBin.isValid());

    qputenv("XDG_CONFIG_HOME", configHome.path().toLocal8Bit());
    qputenv("TIDE_ISLAND_COMPOSITOR", "niri");

    const QByteArray originalPath = qgetenv("PATH");
    qputenv("PATH", (fakeBin.path().toLocal8Bit() + ':' + originalPath));

    const QString fakeNiri = fakeBin.path() + QStringLiteral("/niri");
    QVERIFY(writeTextFile(fakeNiri,
        "#!/bin/sh\n"
        "case \"$1\" in\n"
        "    validate|msg) exit 0 ;;\n"
        "    *) exit 1 ;;\n"
        "esac\n",
        QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ExeOwner));

    const QString niriConfig = configHome.path() + QStringLiteral("/niri/config.kdl");
    QVERIFY(writeTextFile(niriConfig, "// original niri config\n"));

    Backend backend;
    QVERIFY(backend.niriShortcutBindingsNeedApply());
    QVERIFY(backend.applyShortcutBindings(backend.shortcutBindings()));

    const QString managedConfig = readTextFile(configHome.path() + QStringLiteral("/tide-island/niri-shortcuts.kdl"));
    QVERIFY(managedConfig.contains(QStringLiteral("Super+W")));
    QVERIFY(managedConfig.contains(QStringLiteral("\"tide\" \"toggleWallpaperPicker\"")));
    QVERIFY(managedConfig.contains(QStringLiteral("Super+N")));
    QVERIFY(managedConfig.contains(QStringLiteral("\"tide\" \"toggleNotificationCenter\"")));
    QVERIFY(!managedConfig.contains(QStringLiteral("overview")));

    const QString installedConfig = readTextFile(niriConfig);
    QVERIFY(installedConfig.contains(QStringLiteral("include \"")
        + configHome.path()
        + QStringLiteral("/tide-island/niri-shortcuts.kdl\"")));
    QVERIFY(!backend.niriShortcutBindingsNeedApply());

    qputenv("TIDE_ISLAND_COMPOSITOR", "hyprland");
    Backend hyprlandBackend;
    bool foundOverview = false;
    for (const QVariant &value : hyprlandBackend.shortcutBindings()) {
        foundOverview = foundOverview
            || value.toMap().value(QStringLiteral("target")).toString() == QStringLiteral("overview");
    }
    QVERIFY(foundOverview);

    qputenv("PATH", originalPath);
}

void ShortcutConfigTests::hyprlandSessionPreconfiguresNiriShortcuts()
{
    QTemporaryDir configHome;
    QVERIFY(configHome.isValid());
    QTemporaryDir fakeBin;
    QVERIFY(fakeBin.isValid());

    qputenv("XDG_CONFIG_HOME", configHome.path().toLocal8Bit());
    qputenv("TIDE_ISLAND_COMPOSITOR", "hyprland");

    const QByteArray originalPath = qgetenv("PATH");
    qputenv("PATH", (fakeBin.path().toLocal8Bit() + ':' + originalPath));

    const QString fakeNiri = fakeBin.path() + QStringLiteral("/niri");
    QVERIFY(writeTextFile(fakeNiri,
        "#!/bin/sh\n"
        "test \"$1\" = validate\n",
        QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ExeOwner));

    const QString niriConfig = configHome.path() + QStringLiteral("/niri/config.kdl");
    QVERIFY(writeTextFile(niriConfig, "// niri config prepared while Hyprland is active\n"));

    Backend backend;
    QVERIFY(backend.supportsTideWorkspaceOverview());
    QVERIFY(backend.niriShortcutBindingsNeedApply());
    QVERIFY(backend.ensureNiriShortcutBindings());

    const QString managedConfig = readTextFile(configHome.path() + QStringLiteral("/tide-island/niri-shortcuts.kdl"));
    QVERIFY(managedConfig.contains(QStringLiteral("Super+W")));
    QVERIFY(managedConfig.contains(QStringLiteral("\"tide\" \"toggleWallpaperPicker\"")));
    QVERIFY(!managedConfig.contains(QStringLiteral("overview")));
    QVERIFY(readTextFile(niriConfig).contains(QStringLiteral("niri-shortcuts.kdl")));
    QVERIFY(!backend.niriShortcutBindingsNeedApply());

    qputenv("PATH", originalPath);
}

void ShortcutConfigTests::niriConfigEnvironmentOverrideIsUsed()
{
    QTemporaryDir configHome;
    QVERIFY(configHome.isValid());
    QTemporaryDir fakeBin;
    QVERIFY(fakeBin.isValid());

    qputenv("XDG_CONFIG_HOME", configHome.path().toLocal8Bit());
    qputenv("TIDE_ISLAND_COMPOSITOR", "hyprland");
    const QString customConfig = configHome.path() + QStringLiteral("/custom/niri.kdl");
    qputenv("NIRI_CONFIG", customConfig.toLocal8Bit());

    const QByteArray originalPath = qgetenv("PATH");
    qputenv("PATH", (fakeBin.path().toLocal8Bit() + ':' + originalPath));
    QVERIFY(writeTextFile(fakeBin.path() + QStringLiteral("/niri"),
        "#!/bin/sh\n"
        "test \"$1\" = validate\n",
        QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ExeOwner));
    QVERIFY(writeTextFile(customConfig, "// custom niri config\n"));

    Backend backend;
    QVERIFY(backend.niriShortcutBindingsNeedApply());
    QVERIFY(backend.ensureNiriShortcutBindings());
    QVERIFY(readTextFile(customConfig).contains(QStringLiteral("niri-shortcuts.kdl")));
    QVERIFY(!QFileInfo::exists(configHome.path() + QStringLiteral("/niri/config.kdl")));

    qunsetenv("NIRI_CONFIG");
    qputenv("PATH", originalPath);
}

void ShortcutConfigTests::niriValidationFailurePreservesManagedConfig()
{
    QTemporaryDir configHome;
    QVERIFY(configHome.isValid());
    QTemporaryDir fakeBin;
    QVERIFY(fakeBin.isValid());

    qputenv("XDG_CONFIG_HOME", configHome.path().toLocal8Bit());
    qputenv("TIDE_ISLAND_COMPOSITOR", "niri");
    qunsetenv("NIRI_CONFIG");

    const QByteArray originalPath = qgetenv("PATH");
    qputenv("PATH", (fakeBin.path().toLocal8Bit() + ':' + originalPath));
    QVERIFY(writeTextFile(fakeBin.path() + QStringLiteral("/niri"),
        "#!/bin/sh\n"
        "echo invalid candidate >&2\n"
        "exit 1\n",
        QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ExeOwner));

    const QString managedConfig = configHome.path() + QStringLiteral("/tide-island/niri-shortcuts.kdl");
    const QByteArray originalManaged = "// keep this working config\nbinds {}\n";
    QVERIFY(writeTextFile(managedConfig, originalManaged));
    const QString niriConfig = configHome.path() + QStringLiteral("/niri/config.kdl");
    const QByteArray originalMain = QStringLiteral("include \"%1\"\n").arg(managedConfig).toUtf8();
    QVERIFY(writeTextFile(niriConfig, originalMain));

    Backend backend;
    QVERIFY(backend.niriShortcutBindingsNeedApply());
    QVERIFY(!backend.ensureNiriShortcutBindings());
    QCOMPARE(readTextFile(managedConfig), QString::fromUtf8(originalManaged));
    QCOMPARE(readTextFile(niriConfig), QString::fromUtf8(originalMain));
    QVERIFY(backend.errorString().contains(QStringLiteral("invalid candidate")));

    qputenv("PATH", originalPath);
}

void ShortcutConfigTests::niriValidationFailureDoesNotIncludeManagedFile()
{
    QTemporaryDir configHome;
    QVERIFY(configHome.isValid());
    QTemporaryDir fakeBin;
    QVERIFY(fakeBin.isValid());

    qputenv("XDG_CONFIG_HOME", configHome.path().toLocal8Bit());
    qputenv("TIDE_ISLAND_COMPOSITOR", "niri");

    const QByteArray originalPath = qgetenv("PATH");
    qputenv("PATH", (fakeBin.path().toLocal8Bit() + ':' + originalPath));

    const QString fakeNiri = fakeBin.path() + QStringLiteral("/niri");
    QVERIFY(writeTextFile(fakeNiri,
        "#!/bin/sh\n"
        "echo validation failed >&2\n"
        "exit 1\n",
        QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ExeOwner));

    const QString niriConfig = configHome.path() + QStringLiteral("/niri/config.kdl");
    const QByteArray originalConfig = "// original niri config\n";
    QVERIFY(writeTextFile(niriConfig, originalConfig));

    Backend backend;
    QVERIFY(!backend.applyShortcutBindings(backend.shortcutBindings()));
    QCOMPARE(readTextFile(niriConfig), QString::fromUtf8(originalConfig));
    QVERIFY(!readTextFile(niriConfig).contains(QStringLiteral("niri-shortcuts.kdl")));
    QVERIFY(backend.errorString().contains(QStringLiteral("validation failed")));
}

QTEST_GUILESS_MAIN(ShortcutConfigTests)

#include "shortcut_config_tests.moc"
