#define POLKIT_AGENT_I_KNOW_API_IS_SUBJECT_TO_CHANGE

#ifdef signals
#  undef signals
#  define TIDE_QT_SIGNALS_SAVE
#endif

#include <polkit/polkit.h>
#include <polkitagent/polkitagent.h>
#include <gio/gio.h>

#ifdef TIDE_QT_SIGNALS_SAVE
#  define signals Q_SIGNALS
#  undef TIDE_QT_SIGNALS_SAVE
#endif

#include "PolkitAgent.h"
#include <QDebug>

struct TideListener {
    PolkitAgentListener parent;
    PolkitAgent        *qtAgent;
};

struct TideListenerClass {
    PolkitAgentListenerClass parent_class;
};

G_DEFINE_TYPE(TideListener, tide_listener, POLKIT_AGENT_TYPE_LISTENER)

static void tide_listener_initiate_authentication(
    PolkitAgentListener  *listener,
    const gchar          *action_id,
    const gchar          *message,
    const gchar          *icon_name,
    PolkitDetails        *details,
    const gchar          *cookie,
    GList                *identities,
    GCancellable         *cancellable,
    GAsyncReadyCallback   callback,
    gpointer              user_data)
{
    TideListener *self = reinterpret_cast<TideListener *>(listener);

    GTask *task = g_task_new(listener, cancellable, callback, user_data);
    g_object_set_data_full(G_OBJECT(listener), "current_task",
                           task, (GDestroyNotify)g_object_unref);

    self->qtAgent->beginAuthentication(
        QString::fromUtf8(action_id),
        QString::fromUtf8(message),
        QString::fromUtf8(icon_name),
        details,
        QString::fromUtf8(cookie),
        identities,
        cancellable
    );
}

static gboolean tide_listener_initiate_authentication_finish(
    PolkitAgentListener  *listener,
    GAsyncResult         *res,
    GError              **error)
{
    return g_task_propagate_boolean(G_TASK(res), error);
}

static void tide_listener_init(TideListener *) {}

static void tide_listener_class_init(TideListenerClass *klass) {
    PolkitAgentListenerClass *listener_class = POLKIT_AGENT_LISTENER_CLASS(klass);
    listener_class->initiate_authentication        = tide_listener_initiate_authentication;
    listener_class->initiate_authentication_finish = tide_listener_initiate_authentication_finish;
}

static void on_session_completed(PolkitAgentSession *session,
                                 gboolean            gained_authorization,
                                 gpointer            user_data)
{
    Q_UNUSED(session)
    PolkitAgent *agent = static_cast<PolkitAgent *>(user_data);
    agent->sessionCompleted(gained_authorization);
}

static void on_session_show_error(PolkitAgentSession *session,
                                  const gchar        *text,
                                  gpointer            user_data)
{
    Q_UNUSED(session)
    PolkitAgent *agent = static_cast<PolkitAgent *>(user_data);
    agent->sessionShowError(QString::fromUtf8(text));
}

static void on_session_request(PolkitAgentSession *session,
                               const gchar        *,
                               gboolean            ,
                               gpointer            user_data)
{
    PolkitAgent *agent = static_cast<PolkitAgent *>(user_data);
    polkit_agent_session_response(session, agent->m_pendingPassword.toUtf8().constData());
}

static void on_session_show_info(PolkitAgentSession *, const gchar *, gpointer) {}

PolkitAgent::PolkitAgent(QObject *parent)
    : QObject(parent)
{
    registerAgent();
}

PolkitAgent::~PolkitAgent() {
    cleanup();
    if (m_registeredHandle) {
        polkit_agent_listener_unregister(m_registeredHandle);
        m_registeredHandle = nullptr;
    }
    if (m_listener) {
        g_object_unref(m_listener);
        m_listener = nullptr;
    }
}

void PolkitAgent::registerAgent() {
    GError *error = nullptr;

    m_listener = POLKIT_AGENT_LISTENER(g_object_new(tide_listener_get_type(), nullptr));
    reinterpret_cast<TideListener *>(m_listener)->qtAgent = this;

    PolkitSubject *subject = polkit_unix_session_new_for_process_sync(
        getpid(), nullptr, &error);

    if (!subject) {
        qWarning() << "[PolkitAgent] Failed to create subject:"
                   << (error ? error->message : "unknown");
        if (error) g_error_free(error);
        return;
    }

    m_registeredHandle = polkit_agent_listener_register(
        m_listener,
        POLKIT_AGENT_REGISTER_FLAGS_NONE,
        subject,
        nullptr,
        nullptr,
        &error
    );

    g_object_unref(subject);

    if (!m_registeredHandle) {
        qWarning() << "[PolkitAgent] Failed to register agent:"
                   << (error ? error->message : "unknown");
        if (error) g_error_free(error);
        return;
    }

    qDebug() << "[PolkitAgent] Registered successfully";
}

void PolkitAgent::beginAuthentication(const QString    &actionId,
                                      const QString    &message,
                                      const QString    &,
                                      PolkitDetails    *,
                                      const QString    &cookie,
                                      GList            *identities,
                                      GCancellable     *cancellable)
{
    cleanup();

    m_actionId = actionId;
    m_message  = message;
    m_cookie   = cookie;
    m_cancellable = cancellable
        ? static_cast<GCancellable *>(g_object_ref(cancellable))
        : nullptr;

    if (identities && identities->data) {
        m_identity = POLKIT_IDENTITY(g_object_ref(G_OBJECT(identities->data)));
    } else {
        m_identity = nullptr;
        qWarning() << "[PolkitAgent] No identities provided";
    }

    const QString lower = actionId.toLower();
    if (lower.contains("network"))         m_appName = "Network Manager";
    else if (lower.contains("packagekit")) m_appName = "Package Manager";
    else if (lower.contains("tlp"))        m_appName = "TLP";
    else if (lower.contains("udisks"))     m_appName = "Disk Manager";
    else if (lower.contains("systemd"))    m_appName = "System";
    else                                   m_appName = "System";

    m_active         = true;
    m_lastAuthFailed = false;
    emit activeChanged();
    emit authRequested();
}

void PolkitAgent::authenticate(const QString &password) {
    if (!m_active || m_authenticating) return;

    if (!m_identity) {
        qWarning() << "[PolkitAgent] No identity available";
        return;
    }

    m_pendingPassword = password;

    m_session = polkit_agent_session_new(m_identity, m_cookie.toUtf8().constData());

    g_signal_connect(m_session, "completed",  G_CALLBACK(on_session_completed),  this);
    g_signal_connect(m_session, "show-error", G_CALLBACK(on_session_show_error), this);
    g_signal_connect(m_session, "request",    G_CALLBACK(on_session_request),    this);
    g_signal_connect(m_session, "show-info",  G_CALLBACK(on_session_show_info),  this);

    polkit_agent_session_initiate(m_session);

    m_authenticating = true;
    emit authenticatingChanged();
}

void PolkitAgent::cancel() {
    if (m_session)
        polkit_agent_session_cancel(m_session);

    if (m_listener) {
        GTask *task = static_cast<GTask *>(
            g_object_get_data(G_OBJECT(m_listener), "current_task"));
        if (task) {
            g_task_return_boolean(task, FALSE);
            g_object_set_data(G_OBJECT(m_listener), "current_task", nullptr);
        }
    }

    cleanup();
    m_active = false;
    emit activeChanged();
    emit authCompleted(false);
}

void PolkitAgent::sessionCompleted(bool gainedAuthorization) {
    m_authenticating = false;
    m_pendingPassword.clear();
    emit authenticatingChanged();

    if (gainedAuthorization) {
        if (m_listener) {
            GTask *task = static_cast<GTask *>(
                g_object_get_data(G_OBJECT(m_listener), "current_task"));
            if (task) {
                g_task_return_boolean(task, TRUE);
                g_object_set_data(G_OBJECT(m_listener), "current_task", nullptr);
            }
        }
        cleanup();
        m_active         = false;
        m_lastAuthFailed = false;
        emit lastAuthFailedChanged();
        emit activeChanged();
        emit authCompleted(true);
    } else {
        if (m_session) {
            g_object_unref(m_session);
            m_session = nullptr;
        }
        m_lastAuthFailed = true;
        emit lastAuthFailedChanged();
    }
}

void PolkitAgent::sessionShowError(const QString &text) {
    qWarning() << "[PolkitAgent] Session error:" << text;
}

void PolkitAgent::endAuthentication() {
    cleanup();
}

void PolkitAgent::cleanup() {
    if (m_session) {
        g_object_unref(m_session);
        m_session = nullptr;
    }
    if (m_cancellable) {
        g_object_unref(m_cancellable);
        m_cancellable = nullptr;
    }
    if (m_identity) {
        g_object_unref(m_identity);
        m_identity = nullptr;
    }
    m_authenticating  = false;
    m_pendingPassword.clear();
}
