import QtQuick
import QtQuick.Controls

Button {
    id: root
    property string glyph: "play"
    property bool prominent: false
    property bool selected: false
    property bool transport: false
    // Frosted round button for chrome such as power actions.
    property bool glass: false
    property bool armed: false
    property bool spinning: false
    property real glyphSize: transport ? (glyph === "heart" ? 17 : glyph === "play" || glyph === "pause" ? 22 : 19) : glass ? 18 : 16
    property var styleTokens: null
    property color accent: styleTokens ? styleTokens.accent : "#0a84ff"
    property color foreground: styleTokens ? styleTokens.textPrimary : "#f5f5f7"
    property color danger: styleTokens ? styleTokens.error : "#ff7c72"
    implicitWidth: transport ? 36 : 40
    implicitHeight: implicitWidth
    padding: 0
    hoverEnabled: true
    focusPolicy: Qt.NoFocus
    Accessible.name: text
    opacity: enabled ? 1 : (prominent ? 0.55 : 0.35)
    Behavior on opacity {
        NumberAnimation {
            duration: 160
        }
    }

    HoverHandler {
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    background: Rectangle {
        radius: width / 2
        antialiasing: true
        color: {
            if (root.prominent)
                return root.enabled ? Qt.rgba(1, 1, 1, root.down ? 0.78 : root.hovered ? 1 : 0.92) : Qt.rgba(1, 1, 1, 0.14);
            if (root.armed)
                return Qt.rgba(root.danger.r, root.danger.g, root.danger.b, root.down ? 0.55 : 0.42);
            if (root.glass)
                return Qt.rgba(1, 1, 1, root.down ? 0.2 : root.hovered ? 0.16 : 0.09);
            return Qt.rgba(1, 1, 1, root.down ? 0.16 : root.hovered ? 0.09 : 0);
        }
        border.width: root.glass && !root.armed ? 1 : 0
        border.color: Qt.rgba(1, 1, 1, 0.12)
        Behavior on color {
            ColorAnimation {
                duration: 140
            }
        }
    }
    contentItem: Item {
        LockGlyph {
            id: glyphItem
            anchors.centerIn: parent
            width: root.glyphSize
            height: width
            name: root.spinning ? "spinner" : root.glyph
            stroke: root.prominent ? 2.1 : 1.8
            ink: root.prominent && root.enabled ? "#141518" : root.foreground
            filled: !root.spinning && (root.glyph === "heart" ? root.selected : root.transport)
            scale: root.down ? 0.86 : 1
            Behavior on scale {
                NumberAnimation {
                    duration: 110
                    easing.type: Easing.OutCubic
                }
            }
            RotationAnimator on rotation {
                running: root.spinning
                from: 0
                to: 360
                duration: 900
                loops: Animation.Infinite
            }
            onNameChanged: if (!root.spinning)
                rotation = 0
        }
    }
    ToolTip.visible: hovered && text.length > 0 && !armed
    ToolTip.text: text
    ToolTip.delay: 650
}
