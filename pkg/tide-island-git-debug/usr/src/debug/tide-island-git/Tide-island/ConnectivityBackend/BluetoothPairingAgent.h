#pragma once

#include <QDBusContext>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QObject>

class BluetoothPairingAgent final : public QObject, protected QDBusContext {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.bluez.Agent1")

    Q_PROPERTY(bool registered READ registered NOTIFY registeredChanged)
    Q_PROPERTY(QString registrationError READ registrationError NOTIFY registrationErrorChanged)
    Q_PROPERTY(bool requestActive READ requestActive NOTIFY requestChanged)
    Q_PROPERTY(QString requestKind READ requestKind NOTIFY requestChanged)
    Q_PROPERTY(bool requestRequiresInput READ requestRequiresInput NOTIFY requestChanged)
    Q_PROPERTY(bool requestNumericInput READ requestNumericInput NOTIFY requestChanged)
    Q_PROPERTY(bool requestRequiresConfirmation READ requestRequiresConfirmation NOTIFY requestChanged)
    Q_PROPERTY(QString devicePath READ devicePath NOTIFY requestChanged)
    Q_PROPERTY(QString deviceName READ deviceName NOTIFY requestChanged)
    Q_PROPERTY(QString promptTitle READ promptTitle NOTIFY requestChanged)
    Q_PROPERTY(QString promptMessage READ promptMessage NOTIFY requestChanged)
    Q_PROPERTY(QString displayedCode READ displayedCode NOTIFY requestChanged)
    Q_PROPERTY(int displayedEnteredCount READ displayedEnteredCount NOTIFY requestChanged)

public:
    explicit BluetoothPairingAgent(QObject *parent = nullptr);
    ~BluetoothPairingAgent() override;

    bool registered() const;
    QString registrationError() const;
    bool requestActive() const;
    QString requestKind() const;
    bool requestRequiresInput() const;
    bool requestNumericInput() const;
    bool requestRequiresConfirmation() const;
    QString devicePath() const;
    QString deviceName() const;
    QString promptTitle() const;
    QString promptMessage() const;
    QString displayedCode() const;
    int displayedEnteredCount() const;

    Q_INVOKABLE void submitSecret(const QString &secret);
    Q_INVOKABLE void confirmRequest();
    Q_INVOKABLE void rejectRequest();
    Q_INVOKABLE void cancelRequest();

signals:
    void registeredChanged();
    void registrationErrorChanged();
    void requestChanged();

public slots:
    void Release();
    QString RequestPinCode(const QDBusObjectPath &device);
    void DisplayPinCode(const QDBusObjectPath &device, const QString &pincode);
    uint RequestPasskey(const QDBusObjectPath &device);
    void DisplayPasskey(const QDBusObjectPath &device, uint passkey, ushort entered);
    void RequestConfirmation(const QDBusObjectPath &device, uint passkey);
    void RequestAuthorization(const QDBusObjectPath &device);
    void AuthorizeService(const QDBusObjectPath &device, const QString &uuid);
    void Cancel();

private slots:
    void handleBluezNameOwnerChanged(const QString &name, const QString &oldOwner, const QString &newOwner);

private:
    enum class PromptKind {
        None,
        RequestPinCode,
        DisplayPinCode,
        RequestPasskey,
        DisplayPasskey,
        RequestConfirmation,
        RequestAuthorization,
        AuthorizeService,
    };

    enum class ReplyType {
        None,
        Void,
        String,
        UInt32,
    };

    struct PendingRequest {
        PromptKind kind = PromptKind::None;
        ReplyType replyType = ReplyType::None;
        QString devicePath;
        QString deviceName;
        QString serviceUuid;
        QString displayedCode;
        quint16 displayedEnteredCount = 0;
        bool delayedReply = false;
        QDBusMessage message;
    };

    void ensureAgentRegistered();
    void unregisterAgent();
    void setRegisteredState(bool registered);
    void setRegistrationError(const QString &error);
    void replaceRequest(PendingRequest request);
    void clearRequest();
    void finishWithVoidReply();
    void finishWithStringReply(const QString &value);
    void finishWithUInt32Reply(quint32 value);
    void finishWithErrorReply(const QString &errorName, const QString &errorText);
    QString lookupDeviceName(const QString &devicePath) const;
    QString promptKindToString(PromptKind kind) const;
    static QString formatPasskey(quint32 passkey);
    static QString fallbackDeviceName(const QString &devicePath);

    bool m_registered = false;
    bool m_objectExported = false;
    QString m_registrationError;
    PendingRequest m_request;
};
