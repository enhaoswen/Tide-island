#include "UserConfigBackend.h"

#include <QDir>
#include <QFile>
#include <QTemporaryDir>
#include <QTest>

class UserConfigBackendTests final : public QObject {
    Q_OBJECT

private slots:
    void loadsTypedValuesFromJson();
    void exposesParseErrorsAndFallsBackToDefaults();
    void mapsConfiguredMouseButtons();
};

namespace {
QString writeConfig(QTemporaryDir &configHome, const QByteArray &json)
{
    const QString configDir = configHome.path() + QStringLiteral("/tide-island");
    QDir().mkpath(configDir);

    const QString configPath = configDir + QStringLiteral("/userconfig.json");
    QFile file(configPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return QString();

    file.write(json);
    return configPath;
}
}

void UserConfigBackendTests::loadsTypedValuesFromJson()
{
    QTemporaryDir configHome;
    QVERIFY(configHome.isValid());
    qputenv("XDG_CONFIG_HOME", configHome.path().toLocal8Bit());

    const QString configPath = writeConfig(configHome, R"json({
        "wallpaperPath": "/tmp/test-wallpaper.jpg",
        "textFontFamily": "Test Text",
        "tlpPermissionMode": "skip",
        "dynamicIslandLeftSwipeItems": ["time", "ram"]
    })json");
    QVERIFY(!configPath.isEmpty());

    UserConfigBackend config;
    QCOMPARE(config.userConfigPath(), configPath);
    QCOMPARE(config.configError(), QString());
    QCOMPARE(config.wallpaperPath(), QStringLiteral("/tmp/test-wallpaper.jpg"));
    QCOMPARE(config.textFontFamily(), QStringLiteral("Test Text"));
    QCOMPARE(config.tlpPermissionMode(), QStringLiteral("skip"));
    QCOMPARE(config.dynamicIslandLeftSwipeItems(), QVariantList({QStringLiteral("time"), QStringLiteral("ram")}));
}

void UserConfigBackendTests::exposesParseErrorsAndFallsBackToDefaults()
{
    QTemporaryDir configHome;
    QVERIFY(configHome.isValid());
    qputenv("XDG_CONFIG_HOME", configHome.path().toLocal8Bit());

    QVERIFY(!writeConfig(configHome, "{").isEmpty());

    UserConfigBackend config;
    QVERIFY(!config.configError().isEmpty());
    QCOMPARE(config.textFontFamily(), QStringLiteral("Inter Display"));
    QCOMPARE(config.dynamicIslandLeftSwipeItems(), QVariantList({QStringLiteral("cava"), QStringLiteral("battery")}));
}

void UserConfigBackendTests::mapsConfiguredMouseButtons()
{
    QTemporaryDir configHome;
    QVERIFY(configHome.isValid());
    qputenv("XDG_CONFIG_HOME", configHome.path().toLocal8Bit());

    UserConfigBackend config;
    QCOMPARE(config.mouseButton(1), int(Qt::LeftButton));
    QCOMPARE(config.mouseButton(2), int(Qt::MiddleButton));
    QCOMPARE(config.mouseButton(3), int(Qt::RightButton));
    QCOMPARE(config.mouseButton(8), 8);
    QCOMPARE(config.mouseButton(QVariant()), int(Qt::NoButton));
    QCOMPARE(config.mouseButtonsMask(QVariantList({1, 3})), int(Qt::LeftButton | Qt::RightButton));
}

QTEST_MAIN(UserConfigBackendTests)

#include "user_config_backend_tests.moc"
