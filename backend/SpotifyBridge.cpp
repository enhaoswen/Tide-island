#include "SpotifyBridge.h"

#include <QFile>
#include <QHostAddress>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QUuid>
#include <QWebSocket>

namespace {
bool isTrackUri(const QString &uri)
{
    static const QRegularExpression pattern(QStringLiteral("^spotify:track:[A-Za-z0-9]{22}$"));
    return pattern.match(uri).hasMatch();
}

void sendMessage(QWebSocket *socket, const QJsonObject &message)
{
    socket->sendTextMessage(QString::fromUtf8(QJsonDocument(message).toJson(QJsonDocument::Compact)));
}
}

SpotifyBridge::SpotifyBridge(QObject *parent)
    : SpotifyBridge(QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)
                    + QStringLiteral("/tide-island/spotify-bridge.json"), parent)
{
}

SpotifyBridge::SpotifyBridge(const QString &configurationPath, QObject *parent)
    : QObject(parent), m_configurationPath(configurationPath),
      m_server(QStringLiteral("Tide Island Spotify"), QWebSocketServer::NonSecureMode, this)
{
    m_server.setMaxPendingConnections(4);
    connect(&m_server, &QWebSocketServer::newConnection, this, &SpotifyBridge::acceptConnection);
    m_configurationTimer.setInterval(3000);
    connect(&m_configurationTimer, &QTimer::timeout, this, &SpotifyBridge::reloadConfiguration);
    m_configurationTimer.start();

    m_requestTimer.setSingleShot(true);
    m_requestTimer.setInterval(10000);
    connect(&m_requestTimer, &QTimer::timeout, this, [this] {
        clearRequest();
        m_stateKnown = false;
        m_error = QStringLiteral("Spotify did not confirm the favorite. Try again.");
        emit stateChanged();
    });
    m_heartbeatTimer.setSingleShot(true);
    m_heartbeatTimer.setInterval(15000);
    connect(&m_heartbeatTimer, &QTimer::timeout, this, [this] {
        if (m_client)
            m_client->close(QWebSocketProtocol::CloseCodeGoingAway, QStringLiteral("State update timed out"));
    });
    reloadConfiguration();
}

SpotifyBridge::~SpotifyBridge()
{
    // Disconnect callbacks before the WebSocket server/member objects are destroyed.
    for (QWebSocket *socket : findChildren<QWebSocket *>()) {
        socket->disconnect(this);
        socket->abort();
    }
}

void SpotifyBridge::reloadConfiguration()
{
    QFile file(m_configurationPath);
    QJsonObject config;
    if (file.open(QIODevice::ReadOnly) && file.size() <= 4096)
        config = QJsonDocument::fromJson(file.readAll()).object();

    const QString token = config.value(QStringLiteral("token")).toString();
    const int port = config.value(QStringLiteral("port")).toInt();
    static const QRegularExpression tokenPattern(QStringLiteral("^[a-f0-9]{64}$"));
    const bool valid = config.value(QStringLiteral("version")).toInt() == 1
        && tokenPattern.match(token).hasMatch() && port >= 1024 && port <= 65535;
    const QString nextToken = valid ? token : QString();
    const quint16 nextPort = valid ? quint16(port) : 0;
    const QString configurationError = !valid && file.exists()
        ? QStringLiteral("Spotify favorites setup is invalid. Run tide-island-spotify-setup again.") : QString();
    if (nextToken == m_token && nextPort == m_port
            && ((valid && m_server.isListening()) || (!valid && m_error == configurationError)))
        return;

    m_server.close();
    if (m_client) {
        QWebSocket *previous = m_client;
        m_client.clear();
        previous->close(QWebSocketProtocol::CloseCodeGoingAway, QStringLiteral("Configuration changed"));
    }
    resetState();
    m_token = nextToken;
    m_port = nextPort;
    m_error.clear();
    if (valid && !m_server.listen(QHostAddress::LocalHost, m_port))
        m_error = QStringLiteral("Spotify favorites could not start. The local port may be in use.");
    else if (!valid)
        m_error = configurationError;
    emit stateChanged();
}

void SpotifyBridge::acceptConnection()
{
    while (m_server.hasPendingConnections()) {
        QWebSocket *socket = m_server.nextPendingConnection();
        socket->setParent(this);
        socket->setMaxAllowedIncomingFrameSize(16384);
        socket->setMaxAllowedIncomingMessageSize(16384);
        if (findChildren<QWebSocket *>().size() > 8 || !socket->peerAddress().isLoopback()
                || (!socket->origin().isEmpty() && socket->origin() != QStringLiteral("https://xpui.app.spotify.com"))) {
            socket->close(QWebSocketProtocol::CloseCodePolicyViolated);
            socket->deleteLater();
            continue;
        }
        auto *authenticationTimer = new QTimer(socket);
        authenticationTimer->setSingleShot(true);
        authenticationTimer->start(3000);
        connect(authenticationTimer, &QTimer::timeout, socket, [socket] {
            if (!socket->property("authenticated").toBool())
                socket->close(QWebSocketProtocol::CloseCodePolicyViolated);
        });
        connect(socket, &QWebSocket::textMessageReceived, this, [this, socket](const QString &message) {
            handleMessage(socket, message);
        });
        connect(socket, &QWebSocket::disconnected, this, [this, socket] {
            if (m_client == socket) {
                m_client.clear();
                resetState();
                m_error.clear();
                emit stateChanged();
            }
            socket->deleteLater();
        });
    }
}

void SpotifyBridge::handleMessage(QWebSocket *socket, const QString &text)
{
    const QJsonObject message = QJsonDocument::fromJson(text.toUtf8()).object();
    const QString type = message.value(QStringLiteral("type")).toString();
    if (!socket->property("authenticated").toBool()) {
        if (type != QStringLiteral("hello") || message.value(QStringLiteral("version")).toInt() != 1
                || m_token.isEmpty() || message.value(QStringLiteral("token")).toString() != m_token || m_client) {
            socket->close(QWebSocketProtocol::CloseCodePolicyViolated);
            return;
        }
        socket->setProperty("authenticated", true);
        m_client = socket;
        m_error.clear();
        m_heartbeatTimer.start();
        sendMessage(socket, {{QStringLiteral("type"), QStringLiteral("welcome")}, {QStringLiteral("version"), 1}});
        emit stateChanged();
        return;
    }
    if (socket != m_client)
        return;

    if (type == QStringLiteral("state")) {
        m_heartbeatTimer.start();
        applyState(message);
    } else if (type == QStringLiteral("result") && busy()
            && message.value(QStringLiteral("id")).toString() == m_requestId
            && message.value(QStringLiteral("uri")).toString() == m_requestUri) {
        const bool success = message.value(QStringLiteral("ok")).isBool()
            && message.value(QStringLiteral("ok")).toBool()
            && message.value(QStringLiteral("liked")).isBool()
            && message.value(QStringLiteral("liked")).toBool() == m_requestLiked;
        if (success) {
            if (m_trackUri == m_requestUri) {
                m_liked = m_requestLiked;
                m_stateKnown = true;
            }
            m_error.clear();
        } else {
            m_error = message.value(QStringLiteral("error")).toString().left(240);
            if (m_error.isEmpty())
                m_error = QStringLiteral("Could not update Spotify favorites. Try again.");
        }
        clearRequest();
        emit stateChanged();
    }
}

void SpotifyBridge::applyState(const QJsonObject &message)
{
    const QString uri = message.value(QStringLiteral("uri")).toString();
    const QString nextUri = isTrackUri(uri) ? uri : QString();
    const bool known = !nextUri.isEmpty() && message.value(QStringLiteral("liked")).isBool();
    const bool liked = known && message.value(QStringLiteral("liked")).toBool();
    const QString error = message.value(QStringLiteral("error")).toString().left(240);
    if (m_trackUri == nextUri && m_stateKnown == known && m_liked == liked
            && (error.isEmpty() || error == m_error))
        return;
    const bool trackChanged = m_trackUri != nextUri;
    m_trackUri = nextUri;
    m_stateKnown = known;
    m_liked = liked;
    // Keep a failed operation visible until the user retries or changes tracks.
    if (trackChanged || !error.isEmpty() || m_error.isEmpty() || !known)
        m_error = error;
    emit stateChanged();
}

bool SpotifyBridge::setFavorite(const QString &uri, bool liked)
{
    if (!connected() || busy() || !m_stateKnown || uri != m_trackUri || !isTrackUri(uri))
        return false;
    m_requestId = QUuid::createUuid().toString(QUuid::WithoutBraces);
    m_requestUri = uri;
    m_requestLiked = liked;
    m_error.clear();
    sendMessage(m_client, {{QStringLiteral("type"), QStringLiteral("setFavorite")},
                          {QStringLiteral("id"), m_requestId}, {QStringLiteral("uri"), uri},
                          {QStringLiteral("liked"), liked}});
    m_requestTimer.start();
    emit stateChanged();
    return true;
}

void SpotifyBridge::clearRequest()
{
    m_requestTimer.stop();
    m_requestId.clear();
    m_requestUri.clear();
}

void SpotifyBridge::resetState()
{
    clearRequest();
    m_heartbeatTimer.stop();
    m_trackUri.clear();
    m_liked = false;
    m_stateKnown = false;
}
