import QtQuick

Item {
    id: root

    UserConfig {
        id: userConfig
    }

    property string iconText: ""
    property var configSource: null
    readonly property var activeConfig: configSource || userConfig
    property string iconFontFamily: activeConfig.iconFontFamily
    property string slideDirection: "none"
    property real transitionProgress: 0
    property bool showCondition: false
    property real hiddenLeftPadding: 16
    property real hiddenRightPadding: 16
    readonly property real clampedProgress: slideDirection === "right"
        ? Math.max(0, Math.min(1, transitionProgress))
        : (slideDirection === "left"
            ? Math.max(0, Math.min(1, -transitionProgress))
            : 0)
    readonly property real revealProgress: slideDirection === "none" ? 1 : (1 - clampedProgress)
    readonly property real contentX: slideDirection === "right"
        ? (width + hiddenRightPadding) * clampedProgress
        : (slideDirection === "left"
            ? -(width + hiddenLeftPadding) * clampedProgress
            : 0)

    anchors.fill: parent
    clip: true
    opacity: showCondition ? revealProgress : 0

    Behavior on opacity {
        enabled: slideDirection === "none"

        NumberAnimation {
            duration: showCondition ? 220 : 150
            easing.type: Easing.InOutQuad
        }
    }

    Text {
        x: contentX
        width: parent.width
        anchors.verticalCenter: parent.verticalCenter
        text: iconText
        color: "white"
        font.pixelSize: 18
        font.family: iconFontFamily
        horizontalAlignment: Text.AlignHCenter
    }
}
