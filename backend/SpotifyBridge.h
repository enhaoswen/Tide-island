#pragma once

#include <QObject>
#include <QPointer>
#include <QTimer>
#include <QWebSocketServer>
#include <QtQml/qqml.h>

class QWebSocket;
class QJsonObject;

class SpotifyBridge : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(bool configured READ configured NOTIFY stateChanged FINAL)
    Q_PROPERTY(bool connected READ connected NOTIFY stateChanged FINAL)
    Q_PROPERTY(QString trackUri READ trackUri NOTIFY stateChanged FINAL)
    Q_PROPERTY(bool liked READ liked NOTIFY stateChanged FINAL)
    Q_PROPERTY(bool stateKnown READ stateKnown NOTIFY stateChanged FINAL)
    Q_PROPERTY(bool busy READ busy NOTIFY stateChanged FINAL)
    Q_PROPERTY(QString error READ error NOTIFY stateChanged FINAL)

public:
    explicit SpotifyBridge(QObject *parent = nullptr);
    explicit SpotifyBridge(const QString &configurationPath, QObject *parent = nullptr);
    ~SpotifyBridge() override;

    bool configured() const { return !m_token.isEmpty(); }
    bool connected() const { return !m_client.isNull(); }
    QString trackUri() const { return m_trackUri; }
    bool liked() const { return m_liked; }
    bool stateKnown() const { return m_stateKnown; }
    bool busy() const { return !m_requestId.isEmpty(); }
    QString error() const { return m_error; }

    Q_INVOKABLE bool setFavorite(const QString &uri, bool liked);

signals:
    void stateChanged();

private:
    void reloadConfiguration();
    void acceptConnection();
    void handleMessage(QWebSocket *socket, const QString &message);
    void resetState();
    void clearRequest();
    void applyState(const QJsonObject &message);

    QString m_configurationPath;
    QWebSocketServer m_server;
    QTimer m_configurationTimer;
    QTimer m_requestTimer;
    QTimer m_heartbeatTimer;
    QPointer<QWebSocket> m_client;
    QString m_token;
    quint16 m_port = 0;
    QString m_trackUri;
    bool m_liked = false;
    bool m_stateKnown = false;
    QString m_error;
    QString m_requestId;
    QString m_requestUri;
    bool m_requestLiked = false;
};
