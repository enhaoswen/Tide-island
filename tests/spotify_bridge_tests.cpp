#include "SpotifyBridge.h"

#include <QFile>
#include <QJSEngine>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QSignalSpy>
#include <QTcpServer>
#include <QTemporaryDir>
#include <QTest>
#include <QWebSocket>
#include <memory>

namespace {
const QString trackA = QStringLiteral("spotify:track:0123456789ABCDEFGHIJKL");
const QString trackB = QStringLiteral("spotify:track:abcdefghijklmnopqrstuv");
}

class SpotifyBridgeTests : public QObject {
    Q_OBJECT
private slots:
    void init();
    void cleanup();
    void rejectsUnauthenticatedClients();
    void rejectsBrowserOrigins();
    void favoriteWaitsForConfirmation();
    void failedFavoriteDoesNotChangeState();
    void lateResultDoesNotChangeNewTrack();
    void disconnectClearsStateAndPendingRequest();
    void oversizedMessageDisconnects();
    void configurationRemovalStopsBridge();
    void invalidConfigurationReportsSetupError();
    void timeoutRequiresFreshState();
    void parsesOnlySpotifyTracks();
#ifdef SPOTIFY_NODE_EXECUTABLE
    void extensionRoundTrip();
#endif

private:
    void authenticate();
    void send(const QJsonObject &message);
    void state(const QString &uri, bool liked);
    QTemporaryDir m_directory;
    QString m_path;
    quint16 m_port = 0;
    std::unique_ptr<SpotifyBridge> m_bridge;
    std::unique_ptr<QWebSocket> m_client;
    QList<QJsonObject> m_messages;
};

void SpotifyBridgeTests::init()
{
    QVERIFY(m_directory.isValid());
    m_path = m_directory.filePath(QStringLiteral("spotify-bridge.json"));
    QTcpServer portProbe;
    QVERIFY(portProbe.listen(QHostAddress::LocalHost, 0));
    m_port = portProbe.serverPort();
    portProbe.close();
    QFile config(m_path);
    QVERIFY(config.open(QIODevice::WriteOnly));
    config.write(QJsonDocument(QJsonObject{{"version", 1}, {"port", m_port}, {"token", QString(64, 'a')}}).toJson());
    config.close();
    m_messages.clear();
    m_bridge = std::make_unique<SpotifyBridge>(m_path);
    m_client = std::make_unique<QWebSocket>(QStringLiteral("https://xpui.app.spotify.com"));
    connect(m_client.get(), &QWebSocket::textMessageReceived, this, [this](const QString &text) {
        m_messages.append(QJsonDocument::fromJson(text.toUtf8()).object());
    });
}

void SpotifyBridgeTests::cleanup()
{
    m_client.reset();
    m_bridge.reset();
    QFile::remove(m_path);
}

void SpotifyBridgeTests::send(const QJsonObject &message)
{
    m_client->sendTextMessage(QString::fromUtf8(QJsonDocument(message).toJson(QJsonDocument::Compact)));
}

void SpotifyBridgeTests::authenticate()
{
    m_messages.clear();
    m_client->open(QUrl(QStringLiteral("ws://127.0.0.1:%1").arg(m_port)));
    QTRY_COMPARE(m_client->state(), QAbstractSocket::ConnectedState);
    send({{"type", "hello"}, {"version", 1}, {"token", QString(64, 'a')}});
    QTRY_VERIFY(m_bridge->connected());
    QTRY_COMPARE(m_messages.size(), 1);
    QCOMPARE(m_messages.first().value("type").toString(), QStringLiteral("welcome"));
}

void SpotifyBridgeTests::state(const QString &uri, bool liked)
{
    send({{"type", "state"}, {"uri", uri}, {"liked", liked}});
    QTRY_COMPARE(m_bridge->trackUri(), uri);
    QTRY_VERIFY(m_bridge->stateKnown());
    QTRY_COMPARE(m_bridge->liked(), liked);
}

void SpotifyBridgeTests::rejectsUnauthenticatedClients()
{
    QVERIFY(m_bridge->configured());
    m_client->open(QUrl(QStringLiteral("ws://127.0.0.1:%1").arg(m_port)));
    QTRY_COMPARE(m_client->state(), QAbstractSocket::ConnectedState);
    send({{"type", "hello"}, {"version", 1}, {"token", "wrong"}});
    QTRY_COMPARE(m_client->state(), QAbstractSocket::UnconnectedState);
    QVERIFY(!m_bridge->connected());
    QVERIFY(!m_bridge->setFavorite(trackA, true));
}

void SpotifyBridgeTests::rejectsBrowserOrigins()
{
    m_client = std::make_unique<QWebSocket>(QStringLiteral("https://example.com"));
    QSignalSpy disconnected(m_client.get(), &QWebSocket::disconnected);
    m_client->open(QUrl(QStringLiteral("ws://127.0.0.1:%1").arg(m_port)));
    QTRY_VERIFY(!disconnected.isEmpty());
    QVERIFY(!m_bridge->connected());
}

void SpotifyBridgeTests::favoriteWaitsForConfirmation()
{
    authenticate();
    state(trackA, false);
    QVERIFY(!m_bridge->setFavorite(trackB, true));
    QVERIFY(m_bridge->setFavorite(trackA, true));
    QVERIFY(m_bridge->busy());
    QVERIFY(!m_bridge->liked());
    QVERIFY(!m_bridge->setFavorite(trackA, true));
    QTRY_COMPARE(m_messages.size(), 2);
    const QJsonObject command = m_messages.last();
    QCOMPARE(command.value("uri").toString(), trackA);
    send({{"type", "result"}, {"id", "stale"}, {"uri", trackA}, {"ok", true}, {"liked", true}});
    QTest::qWait(25);
    QVERIFY(m_bridge->busy());
    QVERIFY(!m_bridge->liked());
    send({{"type", "result"}, {"id", command.value("id")}, {"uri", trackA}, {"ok", true}, {"liked", true}});
    QTRY_VERIFY(!m_bridge->busy());
    QVERIFY(m_bridge->liked());
    QVERIFY(m_bridge->error().isEmpty());
}

void SpotifyBridgeTests::failedFavoriteDoesNotChangeState()
{
    authenticate();
    state(trackA, false);
    QVERIFY(m_bridge->setFavorite(trackA, true));
    QTRY_COMPARE(m_messages.size(), 2);
    send({{"type", "result"}, {"id", m_messages.last().value("id")}, {"uri", trackA},
          {"ok", false}, {"error", "Could not update Spotify favorites."}});
    QTRY_VERIFY(!m_bridge->busy());
    QVERIFY(!m_bridge->liked());
    QVERIFY(!m_bridge->error().isEmpty());
    state(trackA, false);
    QVERIFY(!m_bridge->error().isEmpty());
}

void SpotifyBridgeTests::lateResultDoesNotChangeNewTrack()
{
    authenticate();
    state(trackA, false);
    QVERIFY(m_bridge->setFavorite(trackA, true));
    QTRY_COMPARE(m_messages.size(), 2);
    const QJsonValue id = m_messages.last().value("id");
    state(trackB, false);
    send({{"type", "result"}, {"id", id}, {"uri", trackA}, {"ok", true}, {"liked", true}});
    QTRY_VERIFY(!m_bridge->busy());
    QCOMPARE(m_bridge->trackUri(), trackB);
    QVERIFY(!m_bridge->liked());
}

void SpotifyBridgeTests::disconnectClearsStateAndPendingRequest()
{
    authenticate();
    state(trackA, true);
    QVERIFY(m_bridge->setFavorite(trackA, false));
    m_client->close();
    QTRY_VERIFY(!m_bridge->connected());
    QVERIFY(!m_bridge->busy());
    QVERIFY(!m_bridge->stateKnown());
    QVERIFY(m_bridge->trackUri().isEmpty());
    authenticate();
    state(trackB, false);
}

void SpotifyBridgeTests::oversizedMessageDisconnects()
{
    authenticate();
    m_client->sendTextMessage(QString(17000, 'x'));
    QTRY_VERIFY(!m_bridge->connected());
}

void SpotifyBridgeTests::configurationRemovalStopsBridge()
{
    authenticate();
    state(trackA, true);
    QVERIFY(QFile::remove(m_path));
    QTRY_VERIFY_WITH_TIMEOUT(!m_bridge->configured(), 5000);
    QVERIFY(!m_bridge->connected());
    QVERIFY(!m_bridge->stateKnown());
}

void SpotifyBridgeTests::timeoutRequiresFreshState()
{
    authenticate();
    state(trackA, false);
    QVERIFY(m_bridge->setFavorite(trackA, true));
    QTRY_VERIFY_WITH_TIMEOUT(!m_bridge->busy(), 11000);
    QVERIFY(!m_bridge->stateKnown());
    QVERIFY(!m_bridge->liked());
    QVERIFY(!m_bridge->setFavorite(trackA, true));
    state(trackA, false);
    QVERIFY(m_bridge->setFavorite(trackA, true));
}

void SpotifyBridgeTests::invalidConfigurationReportsSetupError()
{
    m_bridge.reset();
    QFile config(m_path);
    QVERIFY(config.open(QIODevice::WriteOnly | QIODevice::Truncate));
    config.write("{}");
    config.close();
    m_bridge = std::make_unique<SpotifyBridge>(m_path);
    QVERIFY(!m_bridge->configured());
    QVERIFY(!m_bridge->connected());
    QVERIFY(!m_bridge->error().isEmpty());
}

void SpotifyBridgeTests::parsesOnlySpotifyTracks()
{
    QFile source(QStringLiteral(SPOTIFY_TRACK_SOURCE));
    QVERIFY(source.open(QIODevice::ReadOnly));
    QString script = QString::fromUtf8(source.readAll());
    script.remove(QStringLiteral(".pragma library"));
    QJSEngine engine;
    QVERIFY(!engine.evaluate(script).isError());
    const QJSValue normalize = engine.globalObject().property("normalizeUri");
    QCOMPARE(normalize.call({trackA}).toString(), trackA);
    QCOMPARE(normalize.call({"https://open.spotify.com/intl-zh-CN/track/0123456789ABCDEFGHIJKL?si=example"}).toString(), trackA);
    QCOMPARE(normalize.call({"/com/spotify/track/0123456789ABCDEFGHIJKL"}).toString(), trackA);
    QVERIFY(normalize.call({"spotify:episode:0123456789ABCDEFGHIJKL"}).toString().isEmpty());
    QVERIFY(normalize.call({"https://open.spotify.com.evil.example/track/0123456789ABCDEFGHIJKL"}).toString().isEmpty());
    const QJSValue current = engine.globalObject().property("currentUri");
    QCOMPARE(current.call({engine.evaluate("({dbusName:'org.mpris.MediaPlayer2.spotify',metadata:{'xesam:url':'" + trackA + "'}})")}).toString(), trackA);
    QVERIFY(current.call({engine.evaluate("({dbusName:'org.mpris.MediaPlayer2.vlc',metadata:{'xesam:url':'" + trackA + "'}})")}).toString().isEmpty());
}

#ifdef SPOTIFY_NODE_EXECUTABLE
void SpotifyBridgeTests::extensionRoundTrip()
{
    QProcess extension;
    extension.start(QStringLiteral(SPOTIFY_NODE_EXECUTABLE),
                    {QStringLiteral(SPOTIFY_INTEGRATION_DRIVER), QString::number(m_port), QString(64, 'a')});
    QVERIFY(extension.waitForStarted());
    QTRY_VERIFY_WITH_TIMEOUT(m_bridge->connected(), 5000);
    QTRY_VERIFY(m_bridge->stateKnown());
    QCOMPARE(m_bridge->trackUri(), trackA);
    QVERIFY(!m_bridge->liked());
    QVERIFY(m_bridge->setFavorite(trackA, true));
    QTRY_VERIFY(!m_bridge->busy());
    QVERIFY(m_bridge->liked());
    QVERIFY(m_bridge->error().isEmpty());
    QVERIFY(m_bridge->setFavorite(trackA, false));
    QTRY_VERIFY(!m_bridge->busy());
    QVERIFY(!m_bridge->liked());
    extension.terminate();
    QTRY_COMPARE(extension.state(), QProcess::NotRunning);
    QTRY_VERIFY(!m_bridge->connected());
}
#endif

QTEST_GUILESS_MAIN(SpotifyBridgeTests)
#include "spotify_bridge_tests.moc"
