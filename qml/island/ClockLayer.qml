import QtQuick
import IslandBackend

Item {
    id: root
    signal hovered

    readonly property var userConfig: UserConfig

    property string currentTime: "00:00"
    property var configSource: null
    readonly property var activeConfig: configSource || userConfig
    property string heroFontFamily: activeConfig.heroFontFamily
    property bool showCondition: false
    property real contentOffsetX: 0
    property int textPixelSize: 18

    anchors.fill: parent
    opacity: showCondition ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: showCondition ? 300 : 200
            easing.type: Easing.InOutQuad
        }
    }

    Item {
        width: parent.width
        height: parent.height
        x: contentOffsetX
        clip: true

        Text {
            anchors.centerIn: parent
            text: currentTime
            color: "white"
            font.pixelSize: textPixelSize
            font.family: heroFontFamily
            font.weight: Font.Bold
            font.letterSpacing: -0.35
            wrapMode: Text.NoWrap
        }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            propagateComposedEvents: true
            onEntered: root.hovered()
        }
    }
}
