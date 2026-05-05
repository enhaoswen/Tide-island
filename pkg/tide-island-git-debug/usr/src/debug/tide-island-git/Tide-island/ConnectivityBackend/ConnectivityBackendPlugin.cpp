#include "BluetoothPairingAgent.h"
#include "ConnectivityBackendPlugin.h"
#include "WifiController.h"

#include <qqml.h>

void ConnectivityBackendPlugin::registerTypes(const char *uri) {
    qmlRegisterSingletonType<BluetoothPairingAgent>(
        uri,
        1,
        0,
        "BluetoothPairingAgent",
        [](QQmlEngine *, QJSEngine *) -> QObject * {
            return new BluetoothPairingAgent;
        }
    );

    qmlRegisterSingletonType<WifiController>(
        uri,
        1,
        0,
        "WifiController",
        [](QQmlEngine *, QJSEngine *) -> QObject * {
            return new WifiController;
        }
    );

    qmlProtectModule(uri, 1);
}
