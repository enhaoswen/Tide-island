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
    void clampsAutoHideDelay();
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
        "wallpaperLibraryPath": "/tmp/wallpapers",
        "wallpaperPywalEnabled": true,
        "wallpaperTransitionType": "wave",
        "wallpaperTransitionStep": 12,
        "wallpaperTransitionDuration": 4.5,
        "wallpaperTransitionFps": 75,
        "wallpaperTransitionAngle": 30,
        "wallpaperTransitionPosition": "top-right",
        "wallpaperTransitionBezier": "0.1,0.2,0.3,0.4",
        "wallpaperTransitionWave": "14,28",
        "wallpaperTransitionInvertY": true,
        "textFontFamily": "Test Text",
        "tlpPermissionMode": "skip",
        "dynamicIslandLeftSwipeItems": ["time", "ram"],
        "islandAutoHideEnabled": false,
        "islandAutoHideDelayMs": 2500
    })json");
    QVERIFY(!configPath.isEmpty());

    UserConfigBackend config;
    QCOMPARE(config.userConfigPath(), configPath);
    QCOMPARE(config.configError(), QString());
    QCOMPARE(config.wallpaperPath(), QStringLiteral("/tmp/test-wallpaper.jpg"));
    QCOMPARE(config.wallpaperLibraryPath(), QStringLiteral("/tmp/wallpapers"));
    QCOMPARE(config.wallpaperPywalEnabled(), true);
    QCOMPARE(config.wallpaperTransitionType(), QStringLiteral("wave"));
    QCOMPARE(config.wallpaperTransitionStep(), 12);
    QCOMPARE(config.wallpaperTransitionDuration(), 4.5);
    QCOMPARE(config.wallpaperTransitionFps(), 75);
    QCOMPARE(config.wallpaperTransitionAngle(), 30);
    QCOMPARE(config.wallpaperTransitionPosition(), QStringLiteral("top-right"));
    QCOMPARE(config.wallpaperTransitionBezier(), QStringLiteral("0.1,0.2,0.3,0.4"));
    QCOMPARE(config.wallpaperTransitionWave(), QStringLiteral("14,28"));
    QCOMPARE(config.wallpaperTransitionInvertY(), true);
    QCOMPARE(config.textFontFamily(), QStringLiteral("Test Text"));
    QCOMPARE(config.tlpPermissionMode(), QStringLiteral("skip"));
    QCOMPARE(config.dynamicIslandLeftSwipeItems(), QVariantList({QStringLiteral("time"), QStringLiteral("ram")}));
    QCOMPARE(config.islandAutoHideEnabled(), false);
    QCOMPARE(config.islandAutoHideDelayMs(), 2500);
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
    QCOMPARE(config.tlpPermissionMode(), QStringLiteral("skip"));
    QCOMPARE(config.wallpaperPywalEnabled(), false);
    QCOMPARE(config.wallpaperTransitionType(), QStringLiteral("center"));
    QCOMPARE(config.wallpaperTransitionStep(), 5);
    QCOMPARE(config.wallpaperTransitionDuration(), 3.0);
    QCOMPARE(config.wallpaperTransitionFps(), 60);
    QCOMPARE(config.wallpaperTransitionAngle(), 45);
    QCOMPARE(config.wallpaperTransitionPosition(), QStringLiteral("center"));
    QCOMPARE(config.wallpaperTransitionBezier(), QStringLiteral(".54,0,.34,.99"));
    QCOMPARE(config.wallpaperTransitionWave(), QStringLiteral("20,20"));
    QCOMPARE(config.wallpaperTransitionInvertY(), false);
    QCOMPARE(config.dynamicIslandLeftSwipeItems(), QVariantList({QStringLiteral("cava"), QStringLiteral("battery")}));
    QCOMPARE(config.islandAutoHideEnabled(), true);
    QCOMPARE(config.islandAutoHideDelayMs(), 1000);
}

void UserConfigBackendTests::clampsAutoHideDelay()
{
    {
        QTemporaryDir configHome;
        QVERIFY(configHome.isValid());
        qputenv("XDG_CONFIG_HOME", configHome.path().toLocal8Bit());

        QVERIFY(!writeConfig(configHome, R"json({
            "islandAutoHideDelayMs": 20
        })json").isEmpty());

        UserConfigBackend config;
        QCOMPARE(config.islandAutoHideDelayMs(), 100);
    }

    {
        QTemporaryDir configHome;
        QVERIFY(configHome.isValid());
        qputenv("XDG_CONFIG_HOME", configHome.path().toLocal8Bit());

        QVERIFY(!writeConfig(configHome, R"json({
            "islandAutoHideDelayMs": 20000
        })json").isEmpty());

        UserConfigBackend config;
        QCOMPARE(config.islandAutoHideDelayMs(), 10000);
    }
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
