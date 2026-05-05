import QtQuick

Item {
    id: root

    property bool active: false
    property real contentOpacity: 1
    property int dotSize: 4
    property color dotColor: "#ff453a"

    implicitWidth: dotSize
    implicitHeight: dotSize
    width: dotSize
    height: dotSize
    opacity: active ? contentOpacity : 0
    visible: active || opacity > 0.01

    onActiveChanged: {
        if (!active)
            core.opacity = 1.0;
    }

    Behavior on opacity {
        NumberAnimation {
            duration: root.active ? 180 : 220
            easing.type: Easing.InOutQuad
        }
    }

    Rectangle {
        id: core
        width: root.dotSize
        height: root.dotSize
        anchors.centerIn: parent
        radius: width / 2
        color: root.dotColor
        opacity: 1.0
    }

    SequentialAnimation {
        running: root.active
        loops: Animation.Infinite

        PauseAnimation {
            duration: 110
        }

        NumberAnimation {
            target: core
            property: "opacity"
            to: 0.35
            duration: 980
            easing.type: Easing.InOutSine
        }

        PauseAnimation {
            duration: 120
        }

        NumberAnimation {
            target: core
            property: "opacity"
            to: 1.0
            duration: 1040
            easing.type: Easing.InOutSine
        }
    }
}
