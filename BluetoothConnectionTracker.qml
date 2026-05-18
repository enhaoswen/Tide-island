import QtQuick
import Quickshell.Bluetooth

Item {
    id: root

    visible: false
    width: 0
    height: 0

    signal newConnection(var device)

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var devices: adapter ? adapter.devices.values : []

    property string connectedSignature: ""
    property bool baselineReady: false

    function deviceText(value) {
        return String(value === undefined || value === null ? "" : value).trim();
    }

    function deviceName(device) {
        if (!device) return "Bluetooth device";

        const preferred = deviceText(device.deviceName);
        if (preferred.length > 0) return preferred;

        const alias = deviceText(device.name);
        if (alias.length > 0) return alias;

        const address = deviceText(device.address);
        return address.length > 0 ? address : "Bluetooth device";
    }

    function deviceKey(device) {
        if (!device) return "";

        const path = deviceText(device.dbusPath);
        if (path.length > 0) return path;

        const address = deviceText(device.address);
        if (address.length > 0) return address;

        return deviceName(device);
    }

    function connectedDevices() {
        const source = devices || [];
        const connected = [];

        for (let index = 0; index < source.length; index++) {
            const device = source[index];
            if (device && device.connected)
                connected.push(device);
        }

        return connected;
    }

    function connectedDevicesSignature(sourceDevices) {
        const keys = [];

        for (let index = 0; index < sourceDevices.length; index++) {
            const key = deviceKey(sourceDevices[index]);
            if (key.length > 0)
                keys.push(key);
        }

        keys.sort();
        return keys.join("\u001f");
    }

    function previousKeyMap() {
        const previousKeys = {};
        if (connectedSignature.length === 0)
            return previousKeys;

        const keys = connectedSignature.split("\u001f");
        for (let index = 0; index < keys.length; index++) {
            if (keys[index].length > 0)
                previousKeys[keys[index]] = true;
        }

        return previousKeys;
    }

    function findNewDevice(sourceDevices) {
        const previousKeys = previousKeyMap();

        for (let index = 0; index < sourceDevices.length; index++) {
            const key = deviceKey(sourceDevices[index]);
            if (key.length > 0 && !previousKeys[key])
                return sourceDevices[index];
        }

        return sourceDevices.length > 0 ? sourceDevices[0] : null;
    }

    function sync(showNewConnection) {
        const connected = connectedDevices();
        const nextSignature = connectedDevicesSignature(connected);

        if (!baselineReady || baselineTimer.running) {
            connectedSignature = nextSignature;
            return;
        }

        if (nextSignature === connectedSignature)
            return;

        const newDevice = findNewDevice(connected);
        connectedSignature = nextSignature;

        if (showNewConnection && newDevice && nextSignature.length > 0)
            root.newConnection(newDevice);
    }

    onAdapterChanged: {
        connectedSignature = "";
        baselineReady = false;
        baselineTimer.restart();
        sync(false);
    }

    onDevicesChanged: sync(true)

    Timer {
        id: baselineTimer

        interval: 1000
        repeat: false
        running: true

        onTriggered: {
            root.baselineReady = true;
            root.sync(false);
        }
    }

    Repeater {
        model: root.devices

        delegate: Item {
            width: 0
            height: 0
            visible: false

            property var bluetoothDevice: modelData

            Component.onCompleted: root.sync(true)
            Component.onDestruction: Qt.callLater(function() {
                root.sync(true);
            })

            Connections {
                target: bluetoothDevice
                ignoreUnknownSignals: true

                function onConnectedChanged() {
                    root.sync(true);
                }
            }
        }
    }
}
