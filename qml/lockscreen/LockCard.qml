import QtQuick

// Shared lock-screen container: owns the staggered enter/exit motion and, when
// `surfaceOpacity` is above zero, a quiet frosted surface. Cardless widgets use
// it with `surfaceOpacity: 0` so every element moves on the same timeline.
Rectangle {
    id: root
    property var styleTokens: null
    property real surfaceOpacity: 0.82
    property color surfaceColor: styleTokens ? styleTokens.panel : "#202125"
    property color outlineColor: Qt.rgba(1, 1, 1, 0.13)
    property real entrance: 1
    property real departure: 0
    property real stagger: 0
    // Extra multiplier for idle dimming; kept separate from the timeline.
    property real fade: 1
    property real offsetX: 0
    property real offsetY: 0
    readonly property bool hasSurface: surfaceOpacity > 0
    readonly property real reveal: {
        const progress = Math.max(0, Math.min(1, (entrance - stagger) / 0.7));
        return 1 - Math.pow(1 - progress, 3);
    }
    readonly property real dismiss: Math.max(0, Math.min(1, (departure - stagger * 0.35) / 0.78))
    opacity: reveal * Math.pow(1 - dismiss, 2) * fade
    visible: opacity > 0.001
    scale: 0.985 + 0.015 * reveal - 0.018 * dismiss
    transform: Translate {
        x: root.offsetX
        y: root.offsetY + (1 - root.reveal) * 22 - root.dismiss * 14
    }
    radius: styleTokens ? styleTokens.radiusPanel : 28
    // A translucent tint reads as glass over the blurred wallpaper; a solid slab does not.
    color: hasSurface ? Qt.rgba(surfaceColor.r, surfaceColor.g, surfaceColor.b, 0.18 + surfaceOpacity * 0.42) : "transparent"
    border.width: hasSurface ? 1 : 0
    border.color: outlineColor
    antialiasing: true

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, root.radius - 1)
        visible: root.hasSurface
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.rgba(1, 1, 1, 0.075)
            }
            GradientStop {
                position: 0.5
                color: Qt.rgba(1, 1, 1, 0.025)
            }
            GradientStop {
                position: 1
                color: Qt.rgba(1, 1, 1, 0.01)
            }
        }
    }
}
