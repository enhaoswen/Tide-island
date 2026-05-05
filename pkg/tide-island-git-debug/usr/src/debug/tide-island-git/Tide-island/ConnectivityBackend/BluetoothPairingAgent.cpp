#include "BluetoothPairingAgent.h"

#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDBusVariant>

namespace {

constexpr auto kDbusService = "org.freedesktop.DBus";
constexpr auto kDbusPath = "/org/freedesktop/DBus";
constexpr auto kDbusInterface = "org.freedesktop.DBus";
constexpr auto kDbusPropertiesInterface = "org.freedesktop.DBus.Properties";
constexpr auto kBluezService = "org.bluez";
constexpr auto kBluezAgentManagerPath = "/org/bluez";
constexpr auto kBluezAgentManagerInterface = "org.bluez.AgentManager1";
constexpr auto kBluezDeviceInterface = "org.bluez.Device1";
constexpr auto kAgentObjectPath = "/com/quickshell/ConnectivityBackend/BluetoothAgent";
constexpr auto kCapability = "KeyboardDisplay";

constexpr auto kRejectedError = "org.bluez.Error.Rejected";
constexpr auto kCanceledError = "org.bluez.Error.Canceled";

QVariant getBluezProperty(const QString &path, const QString &propertyName) {
    QDBusInterface interface(
        kBluezService,
        path,
        kDbusPropertiesInterface,
        QDBusConnection::systemBus()
    );

    if (!interface.isValid())
        return {};

    QDBusReply<QVariant> reply = interface.call(
        "Get",
        QString::fromLatin1(kBluezDeviceInterface),
        propertyName
    );

    if (!reply.isValid())
        return {};

    const QVariant value = reply.value();
    if (value.metaType().id() == qMetaTypeId<QDBusVariant>())
        return qvariant_cast<QDBusVariant>(value).variant();
    return value;
}

} // namespace

BluetoothPairingAgent::BluetoothPairingAgent(QObject *parent)
    : QObject(parent) {
    QDBusConnection::systemBus().connect(
        kDbusService,
        kDbusPath,
        kDbusInterface,
        "NameOwnerChanged",
        this,
        SLOT(handleBluezNameOwnerChanged(QString,QString,QString))
    );

    ensureAgentRegistered();
}

BluetoothPairingAgent::~BluetoothPairingAgent() {
    unregisterAgent();
}

bool BluetoothPairingAgent::registered() const {
    return m_registered;
}

QString BluetoothPairingAgent::registrationError() const {
    return m_registrationError;
}

bool BluetoothPairingAgent::requestActive() const {
    return m_request.kind != PromptKind::None;
}

QString BluetoothPairingAgent::requestKind() const {
    return promptKindToString(m_request.kind);
}

bool BluetoothPairingAgent::requestRequiresInput() const {
    return m_request.kind == PromptKind::RequestPinCode
        || m_request.kind == PromptKind::RequestPasskey;
}

bool BluetoothPairingAgent::requestNumericInput() const {
    return m_request.kind == PromptKind::RequestPasskey;
}

bool BluetoothPairingAgent::requestRequiresConfirmation() const {
    return m_request.kind == PromptKind::RequestConfirmation
        || m_request.kind == PromptKind::RequestAuthorization
        || m_request.kind == PromptKind::AuthorizeService;
}

QString BluetoothPairingAgent::devicePath() const {
    return m_request.devicePath;
}

QString BluetoothPairingAgent::deviceName() const {
    return m_request.deviceName;
}

QString BluetoothPairingAgent::promptTitle() const {
    const QString name = m_request.deviceName.isEmpty()
        ? QStringLiteral("Bluetooth device")
        : m_request.deviceName;

    switch (m_request.kind) {
    case PromptKind::RequestPinCode:
        return QStringLiteral("Enter PIN for %1").arg(name);
    case PromptKind::DisplayPinCode:
        return QStringLiteral("PIN for %1").arg(name);
    case PromptKind::RequestPasskey:
        return QStringLiteral("Enter passkey for %1").arg(name);
    case PromptKind::DisplayPasskey:
        return QStringLiteral("Passkey for %1").arg(name);
    case PromptKind::RequestConfirmation:
        return QStringLiteral("Confirm passkey for %1").arg(name);
    case PromptKind::RequestAuthorization:
        return QStringLiteral("Allow pairing with %1").arg(name);
    case PromptKind::AuthorizeService:
        return QStringLiteral("Authorize %1").arg(name);
    case PromptKind::None:
    default:
        return {};
    }
}

QString BluetoothPairingAgent::promptMessage() const {
    switch (m_request.kind) {
    case PromptKind::RequestPinCode:
        return QStringLiteral("Enter the PIN shown by the device.");
    case PromptKind::DisplayPinCode:
        return QStringLiteral("Type this PIN on the device: %1").arg(m_request.displayedCode);
    case PromptKind::RequestPasskey:
        return QStringLiteral("Enter the 6-digit passkey shown by the device.");
    case PromptKind::DisplayPasskey:
        if (m_request.displayedEnteredCount > 0) {
            return QStringLiteral("Type this passkey on the device: %1 (%2 entered)")
                .arg(m_request.displayedCode)
                .arg(m_request.displayedEnteredCount);
        }
        return QStringLiteral("Type this passkey on the device: %1").arg(m_request.displayedCode);
    case PromptKind::RequestConfirmation:
        return QStringLiteral("Does the device show this passkey: %1?")
            .arg(m_request.displayedCode);
    case PromptKind::RequestAuthorization:
        return QStringLiteral("Allow this device to start pairing?");
    case PromptKind::AuthorizeService:
        if (m_request.serviceUuid.isEmpty())
            return QStringLiteral("Allow this Bluetooth service?");
        return QStringLiteral("Allow Bluetooth service %1?").arg(m_request.serviceUuid);
    case PromptKind::None:
    default:
        return {};
    }
}

QString BluetoothPairingAgent::displayedCode() const {
    return m_request.displayedCode;
}

int BluetoothPairingAgent::displayedEnteredCount() const {
    return static_cast<int>(m_request.displayedEnteredCount);
}

void BluetoothPairingAgent::submitSecret(const QString &secret) {
    if (m_request.replyType != ReplyType::String && m_request.replyType != ReplyType::UInt32)
        return;

    const QString trimmed = secret.trimmed();
    if (trimmed.isEmpty())
        return;

    if (m_request.replyType == ReplyType::String) {
        finishWithStringReply(trimmed);
        return;
    }

    bool ok = false;
    const uint passkey = trimmed.toUInt(&ok);
    if (!ok || passkey > 999999U)
        return;

    finishWithUInt32Reply(passkey);
}

void BluetoothPairingAgent::confirmRequest() {
    if (m_request.replyType != ReplyType::Void)
        return;

    finishWithVoidReply();
}

void BluetoothPairingAgent::rejectRequest() {
    if (!requestActive())
        return;

    finishWithErrorReply(
        QString::fromLatin1(kRejectedError),
        QStringLiteral("The pairing request was rejected.")
    );
}

void BluetoothPairingAgent::cancelRequest() {
    if (!requestActive())
        return;

    finishWithErrorReply(
        QString::fromLatin1(kCanceledError),
        QStringLiteral("The pairing request was canceled.")
    );
}

void BluetoothPairingAgent::Release() {
    setRegisteredState(false);
    clearRequest();
}

QString BluetoothPairingAgent::RequestPinCode(const QDBusObjectPath &device) {
    setDelayedReply(true);

    PendingRequest request;
    request.kind = PromptKind::RequestPinCode;
    request.replyType = ReplyType::String;
    request.devicePath = device.path();
    request.deviceName = lookupDeviceName(request.devicePath);
    request.delayedReply = true;
    request.message = message();
    replaceRequest(request);

    return {};
}

void BluetoothPairingAgent::DisplayPinCode(const QDBusObjectPath &device, const QString &pincode) {
    PendingRequest request;
    request.kind = PromptKind::DisplayPinCode;
    request.replyType = ReplyType::None;
    request.devicePath = device.path();
    request.deviceName = lookupDeviceName(request.devicePath);
    request.displayedCode = pincode;
    replaceRequest(request);
}

uint BluetoothPairingAgent::RequestPasskey(const QDBusObjectPath &device) {
    setDelayedReply(true);

    PendingRequest request;
    request.kind = PromptKind::RequestPasskey;
    request.replyType = ReplyType::UInt32;
    request.devicePath = device.path();
    request.deviceName = lookupDeviceName(request.devicePath);
    request.delayedReply = true;
    request.message = message();
    replaceRequest(request);

    return 0;
}

void BluetoothPairingAgent::DisplayPasskey(const QDBusObjectPath &device, uint passkey, ushort entered) {
    const QString path = device.path();
    if (m_request.kind == PromptKind::DisplayPasskey && m_request.devicePath == path) {
        m_request.displayedCode = formatPasskey(passkey);
        m_request.displayedEnteredCount = entered;
        emit requestChanged();
        return;
    }

    PendingRequest request;
    request.kind = PromptKind::DisplayPasskey;
    request.replyType = ReplyType::None;
    request.devicePath = path;
    request.deviceName = lookupDeviceName(path);
    request.displayedCode = formatPasskey(passkey);
    request.displayedEnteredCount = entered;
    replaceRequest(request);
}

void BluetoothPairingAgent::RequestConfirmation(const QDBusObjectPath &device, uint passkey) {
    setDelayedReply(true);

    PendingRequest request;
    request.kind = PromptKind::RequestConfirmation;
    request.replyType = ReplyType::Void;
    request.devicePath = device.path();
    request.deviceName = lookupDeviceName(request.devicePath);
    request.displayedCode = formatPasskey(passkey);
    request.delayedReply = true;
    request.message = message();
    replaceRequest(request);
}

void BluetoothPairingAgent::RequestAuthorization(const QDBusObjectPath &device) {
    setDelayedReply(true);

    PendingRequest request;
    request.kind = PromptKind::RequestAuthorization;
    request.replyType = ReplyType::Void;
    request.devicePath = device.path();
    request.deviceName = lookupDeviceName(request.devicePath);
    request.delayedReply = true;
    request.message = message();
    replaceRequest(request);
}

void BluetoothPairingAgent::AuthorizeService(const QDBusObjectPath &device, const QString &uuid) {
    setDelayedReply(true);

    PendingRequest request;
    request.kind = PromptKind::AuthorizeService;
    request.replyType = ReplyType::Void;
    request.devicePath = device.path();
    request.deviceName = lookupDeviceName(request.devicePath);
    request.serviceUuid = uuid;
    request.delayedReply = true;
    request.message = message();
    replaceRequest(request);
}

void BluetoothPairingAgent::Cancel() {
    clearRequest();
}

void BluetoothPairingAgent::handleBluezNameOwnerChanged(
    const QString &name,
    const QString &,
    const QString &newOwner
) {
    if (name != QLatin1String(kBluezService))
        return;

    if (newOwner.isEmpty()) {
        setRegisteredState(false);
        clearRequest();
        return;
    }

    ensureAgentRegistered();
}

void BluetoothPairingAgent::ensureAgentRegistered() {
    QDBusConnection bus = QDBusConnection::systemBus();
    if (!bus.isConnected()) {
        setRegisteredState(false);
        setRegistrationError(QStringLiteral("The system D-Bus is unavailable."));
        return;
    }

    if (!m_objectExported) {
        m_objectExported = bus.registerObject(
            QString::fromLatin1(kAgentObjectPath),
            this,
            QDBusConnection::ExportAllSlots
        );

        if (!m_objectExported) {
            setRegisteredState(false);
            setRegistrationError(QStringLiteral("Failed to export the Bluetooth pairing agent."));
            return;
        }
    }

    QDBusConnectionInterface *connectionInterface = bus.interface();
    if (!connectionInterface || !connectionInterface->isServiceRegistered(QString::fromLatin1(kBluezService))) {
        setRegisteredState(false);
        setRegistrationError({});
        return;
    }

    QDBusInterface manager(
        QString::fromLatin1(kBluezService),
        QString::fromLatin1(kBluezAgentManagerPath),
        QString::fromLatin1(kBluezAgentManagerInterface),
        bus
    );

    if (!manager.isValid()) {
        setRegisteredState(false);
        setRegistrationError(QStringLiteral("BlueZ is unavailable."));
        return;
    }

    manager.call(
        QStringLiteral("UnregisterAgent"),
        QVariant::fromValue(QDBusObjectPath(QString::fromLatin1(kAgentObjectPath)))
    );

    QDBusReply<void> reply = manager.call(
        QStringLiteral("RegisterAgent"),
        QVariant::fromValue(QDBusObjectPath(QString::fromLatin1(kAgentObjectPath))),
        QString::fromLatin1(kCapability)
    );

    if (!reply.isValid()) {
        setRegisteredState(false);
        setRegistrationError(reply.error().message());
        return;
    }

    setRegistrationError({});
    setRegisteredState(true);
}

void BluetoothPairingAgent::unregisterAgent() {
    if (!m_registered)
        return;

    QDBusInterface manager(
        QString::fromLatin1(kBluezService),
        QString::fromLatin1(kBluezAgentManagerPath),
        QString::fromLatin1(kBluezAgentManagerInterface),
        QDBusConnection::systemBus()
    );

    if (manager.isValid()) {
        manager.call(
            QStringLiteral("UnregisterAgent"),
            QVariant::fromValue(QDBusObjectPath(QString::fromLatin1(kAgentObjectPath)))
        );
    }

    m_registered = false;
}

void BluetoothPairingAgent::setRegisteredState(bool registered) {
    if (m_registered == registered)
        return;

    m_registered = registered;
    emit registeredChanged();
}

void BluetoothPairingAgent::setRegistrationError(const QString &error) {
    if (m_registrationError == error)
        return;

    m_registrationError = error;
    emit registrationErrorChanged();
}

void BluetoothPairingAgent::replaceRequest(PendingRequest request) {
    if (m_request.delayedReply) {
        finishWithErrorReply(
            QString::fromLatin1(kCanceledError),
            QStringLiteral("The pairing request was replaced.")
        );
    }

    m_request = std::move(request);
    emit requestChanged();
}

void BluetoothPairingAgent::clearRequest() {
    if (m_request.kind == PromptKind::None)
        return;

    m_request = PendingRequest {};
    emit requestChanged();
}

void BluetoothPairingAgent::finishWithVoidReply() {
    if (m_request.replyType != ReplyType::Void || !m_request.delayedReply)
        return;

    QDBusConnection::systemBus().send(m_request.message.createReply());
    clearRequest();
}

void BluetoothPairingAgent::finishWithStringReply(const QString &value) {
    if (m_request.replyType != ReplyType::String || !m_request.delayedReply)
        return;

    const QVariantList arguments { value };
    QDBusConnection::systemBus().send(m_request.message.createReply(arguments));
    clearRequest();
}

void BluetoothPairingAgent::finishWithUInt32Reply(quint32 value) {
    if (m_request.replyType != ReplyType::UInt32 || !m_request.delayedReply)
        return;

    const QVariantList arguments { QVariant::fromValue(value) };
    QDBusConnection::systemBus().send(m_request.message.createReply(arguments));
    clearRequest();
}

void BluetoothPairingAgent::finishWithErrorReply(const QString &errorName, const QString &errorText) {
    if (!m_request.delayedReply) {
        clearRequest();
        return;
    }

    QDBusConnection::systemBus().send(m_request.message.createErrorReply(errorName, errorText));
    clearRequest();
}

QString BluetoothPairingAgent::lookupDeviceName(const QString &devicePath) const {
    const QString alias = getBluezProperty(devicePath, QStringLiteral("Alias")).toString().trimmed();
    if (!alias.isEmpty())
        return alias;

    const QString name = getBluezProperty(devicePath, QStringLiteral("Name")).toString().trimmed();
    if (!name.isEmpty())
        return name;

    const QString address = getBluezProperty(devicePath, QStringLiteral("Address")).toString().trimmed();
    if (!address.isEmpty())
        return address;

    return fallbackDeviceName(devicePath);
}

QString BluetoothPairingAgent::promptKindToString(PromptKind kind) const {
    switch (kind) {
    case PromptKind::RequestPinCode:
        return QStringLiteral("requestPinCode");
    case PromptKind::DisplayPinCode:
        return QStringLiteral("displayPinCode");
    case PromptKind::RequestPasskey:
        return QStringLiteral("requestPasskey");
    case PromptKind::DisplayPasskey:
        return QStringLiteral("displayPasskey");
    case PromptKind::RequestConfirmation:
        return QStringLiteral("requestConfirmation");
    case PromptKind::RequestAuthorization:
        return QStringLiteral("requestAuthorization");
    case PromptKind::AuthorizeService:
        return QStringLiteral("authorizeService");
    case PromptKind::None:
    default:
        return {};
    }
}

QString BluetoothPairingAgent::formatPasskey(quint32 passkey) {
    return QStringLiteral("%1").arg(passkey, 6, 10, QLatin1Char('0'));
}

QString BluetoothPairingAgent::fallbackDeviceName(const QString &devicePath) {
    const int lastSlash = devicePath.lastIndexOf(QLatin1Char('/'));
    if (lastSlash < 0 || lastSlash + 1 >= devicePath.size())
        return QStringLiteral("Bluetooth device");

    const QString tail = devicePath.mid(lastSlash + 1);
    if (tail.startsWith(QLatin1String("dev_"))) {
        QString address = tail.mid(4);
        address.replace(QLatin1Char('_'), QLatin1Char(':'));
        return address;
    }

    return QStringLiteral("Bluetooth device");
}
