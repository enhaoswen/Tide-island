import QtQuick

Item {
    id: root

    signal buttonPressed
    signal clicked

    property string kind: "play"
    property string textFontFamily: ""
    readonly property bool down: controlArea.pressed
    readonly property string iconText: {
        if (kind === "previous")
            return "⏮";
        if (kind === "next")
            return "⏭";
        if (kind === "pause")
            return "⏸";
        return "▶";
    }

    width: 28
    height: 28
    scale: controlArea.pressed ? 0.8 : 1.0
    opacity: enabled ? 1.0 : 0.45

    Behavior on scale {
        NumberAnimation {
            duration: 100
        }
    }

    Text {
        anchors.centerIn: parent
        text: root.iconText
        color: controlArea.pressed ? "#888888" : "#ffffff"
        font.pixelSize: root.kind === "play" ? 25 : 23
        font.family: root.textFontFamily
        font.weight: Font.DemiBold
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    MouseArea {
        id: controlArea
        anchors.fill: parent
        anchors.margins: -15
        enabled: root.enabled
        preventStealing: true

        onPressed: function (mouse) {
            root.buttonPressed();
            mouse.accepted = true;
        }
        onClicked: root.clicked()
    }
}
