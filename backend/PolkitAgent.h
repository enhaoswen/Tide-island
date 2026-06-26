#pragma once

#include <QObject>
#include <QString>
#include <QtQml/qqml.h>

typedef struct _PolkitAgentListener PolkitAgentListener;
typedef struct _PolkitAgentSession  PolkitAgentSession;
typedef struct _GError              GError;
typedef struct _GCancellable        GCancellable;
typedef struct _PolkitDetails       PolkitDetails;
typedef struct _PolkitIdentity      PolkitIdentity;
typedef struct _GList               GList;

class PolkitAgent : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool active READ active NOTIFY activeChanged FINAL)
    Q_PROPERTY(QString actionId READ actionId NOTIFY authRequested FINAL)
    Q_PROPERTY(QString message READ message NOTIFY authRequested FINAL)
    Q_PROPERTY(QString appName READ appName NOTIFY authRequested FINAL)
    Q_PROPERTY(bool authenticating READ authenticating NOTIFY authenticatingChanged FINAL)
    Q_PROPERTY(bool lastAuthFailed READ lastAuthFailed NOTIFY lastAuthFailedChanged FINAL)

public:
    explicit PolkitAgent(QObject *parent = nullptr);
    ~PolkitAgent() override;

    bool active() const { return m_active; }
    QString actionId() const { return m_actionId; }
    QString message() const { return m_message; }
    QString appName() const { return m_appName; }
    bool authenticating() const { return m_authenticating; }
    bool lastAuthFailed() const { return m_lastAuthFailed; }

    Q_INVOKABLE void authenticate(const QString &password);
    Q_INVOKABLE void cancel();

    void beginAuthentication(const QString &actionId,
                             const QString &message,
                             const QString &iconName,
                             PolkitDetails *details,
                             const QString &cookie,
                             GList *identities,
                             GCancellable *cancellable);
    void endAuthentication();
    void sessionCompleted(bool gainedAuthorization);
    void sessionShowError(const QString &text);

    QString m_pendingPassword;

signals:
    void authRequested();
    void authCompleted(bool success);
    void activeChanged();
    void authenticatingChanged();
    void lastAuthFailedChanged();

private:
    void cleanup();
    void registerAgent();

    bool m_active = false;
    bool m_authenticating = false;
    bool m_lastAuthFailed = false;

    QString m_actionId;
    QString m_message;
    QString m_appName;
    QString m_cookie;

    PolkitAgentListener *m_listener   = nullptr;
    PolkitAgentSession  *m_session    = nullptr;
    GCancellable        *m_cancellable = nullptr;

    PolkitIdentity      *m_identity   = nullptr;

    void *m_registeredHandle = nullptr;
};
