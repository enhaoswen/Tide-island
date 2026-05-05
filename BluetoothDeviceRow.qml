import QtQuick

Rectangle {
    id: root

    property var provider: null
    property var device: null
    property string section: "available"
    property string iconFontFamily: ""
    property string textFontFamily: ""

    readonly property bool hasProvider: provider !== null && provider !== undefined
    readonly property bool hasDevice: device !== null && device !== undefined
    readonly property bool canInteract: hasProvider && hasDevice && provider.bluetoothEnabled
    readonly property bool paired: hasDevice && (device.paired || device.bonded)
    readonly property bool connected: hasDevice && device.connected
    readonly property bool pairing: hasDevice && device.pairing
    readonly property string actionText: {
        if (section === "connected") return "✓";
        if (section === "paired") return "Connect";
        return pairing ? "Pairing" : "Pair";
    }
    readonly property string subtitleText: section === "connected"
        ? "Connected"
        : (hasProvider && provider.bluetoothDeviceSubtitle
            ? provider.bluetoothDeviceSubtitle(device)
            : "")
    readonly property color iconColor: section === "available" ? "#7f828a" : "#0a84ff"

    width: parent ? parent.width : 0
    height: 52
    radius: 14
    color: "transparent"
    clip: true

    MouseArea {
        anchors.fill: parent
        enabled: root.canInteract

        onClicked: {
            if (root.provider && root.provider.handleBluetoothDevicePressed)
                root.provider.handleBluetoothDevicePressed(root.device);
        }
    }

    Item {
        anchors.fill: parent
        anchors.margins: 12

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.hasProvider ? root.provider.bluetoothGlyph : ""
            color: root.iconColor
            font.pixelSize: 14
            font.family: root.iconFontFamily
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 26
            anchors.top: parent.top
            anchors.right: actionLabel.left
            anchors.rightMargin: 8
            text: root.hasProvider && root.provider.bluetoothDeviceName
                ? root.provider.bluetoothDeviceName(root.device)
                : ""
            color: "#f5f5f7"
            font.pixelSize: 12
            font.family: root.textFontFamily
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 26
            anchors.bottom: parent.bottom
            anchors.right: actionLabel.left
            anchors.rightMargin: 8
            text: root.subtitleText
            color: "#9b9da4"
            font.pixelSize: 10
            font.family: root.textFontFamily
            elide: Text.ElideRight
        }

        Text {
            id: actionLabel

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.actionText
            color: root.section === "connected" ? "#34c759" : "#f5f5f7"
            font.pixelSize: root.section === "connected" ? 18 : 11
            font.family: root.textFontFamily
            font.weight: Font.DemiBold
        }
    }

    Connections {
        target: root.device
        ignoreUnknownSignals: true

        function onPairedChanged() {
            if (!root.provider || !root.device)
                return;
            if (root.provider.bluetoothPairAndConnectPath !== root.device.dbusPath)
                return;

            if (root.device.paired || root.device.bonded) {
                root.device.trusted = true;
                root.device.connect();
                root.provider.bluetoothInfoMessage = "Connecting to "
                    + root.provider.bluetoothDeviceName(root.device) + "...";
            }
        }

        function onPairingChanged() {
            if (!root.provider || !root.device)
                return;
            if (root.provider.bluetoothPairAndConnectPath !== root.device.dbusPath)
                return;

            if (!root.device.pairing && !(root.device.paired || root.device.bonded)) {
                root.provider.bluetoothPairAndConnectPath = "";
                root.provider.bluetoothInfoMessage = "";
                if (!root.provider.bluetoothPairingActive)
                    root.provider.bluetoothError = "Pairing failed or was canceled.";
            }
        }

        function onConnectedChanged() {
            if (!root.provider || !root.device)
                return;
            if (root.provider.bluetoothPairAndConnectPath !== root.device.dbusPath)
                return;

            if (root.device.connected) {
                root.provider.bluetoothPairAndConnectPath = "";
                root.provider.bluetoothInfoMessage = "";
                root.provider.bluetoothError = "";
            }
        }
    }
}
