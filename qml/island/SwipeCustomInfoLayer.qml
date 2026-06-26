import QtQuick
import Quickshell
import IslandBackend

Item {
    id: root

    readonly property var userConfig: UserConfig

    property var items: []
    property var cavaLevels: []
    property string timeText: ""
    property var configSource: null
    readonly property var activeConfig: configSource || userConfig
    property string iconFontFamily: activeConfig.iconFontFamily
    property string textFontFamily: activeConfig.textFontFamily
    property string timeFontFamily: activeConfig.timeFontFamily
    property bool showCondition: false
    property bool showSecondaryText: true
    property bool showTimeLayer: (activeConfig.showTimeInCustomInfoLayer !== undefined) ? activeConfig.showTimeInCustomInfoLayer : true
    property bool recordingActive: false
    property real transitionProgress: 0
    property real minimumWidth: 220
    property real maximumWidth: minimumWidth
    property real horizontalPadding: 14
    property real hiddenLeftPadding: 18
    property real hiddenRightPadding: 18
    property real groupSpacing: 20
    property real iconSpacing: 2
    property int textPixelSize: 13
    property int iconPixelSize: 16
    property int iconBoxSize: 18
    property int batteryIconWidth: 37
    property int batteryIconHeight: 17
    property int batteryFontSize: 13
    property int batteryFontSizeCharging: 12
    property int batteryBoltSize: 10
    property int batteryTipWidth: 2
    property int batteryTipHeight: 5
    property int batteryOuterRadius: 6
    property int batteryInnerRadius: 3
    property real iconVerticalOffset: 1
    property int recordingDotSpacing: 12
    property real batteryChargingXOffset: 0
    property real batteryChargingYOffset: 0
    readonly property string chargingIconGlyph: "\uf0e7"

    readonly property real clampedProgress: Math.max(0, Math.min(1, -transitionProgress))
    readonly property real textWidth: Math.max(0, width - horizontalPadding * 2)
    readonly property real centeredTimeX: horizontalPadding
    readonly property real centeredItemsX: Math.max(horizontalPadding, (width - contentRow.implicitWidth) / 2)
    readonly property real timeHiddenLeftX: -textWidth - hiddenLeftPadding
    readonly property real itemsHiddenRightX: width + hiddenRightPadding
    readonly property real timeExitDistance: Math.max(0, centeredTimeX - timeHiddenLeftX)
    readonly property real itemsEntryDistance: Math.max(0, itemsHiddenRightX - centeredItemsX)
    readonly property real dragDistance: Math.max(timeExitDistance, itemsEntryDistance)
    readonly property real itemsX: centeredItemsX + (1 - clampedProgress) * dragDistance
    readonly property real timeX: centeredTimeX - clampedProgress * dragDistance
    readonly property real visibleTimeWidth: Math.min(textWidth, Math.max(0, timeMetrics.advanceWidth))
    readonly property real timeRecordingDotX: Math.max(4, timeX + (textWidth - visibleTimeWidth) / 2 - recordingDotSpacing - timeRecordingIndicator.width)
    readonly property real preferredWidth: Math.max(minimumWidth, contentRow.implicitWidth + horizontalPadding * 2)

    anchors.fill: parent
    clip: true
    opacity: showCondition ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: showCondition ? 220 : 140
            easing.type: Easing.InOutQuad
        }
    }

    TextMetrics {
        id: timeMetrics
        font.family: timeFontFamily
        font.pixelSize: root.textPixelSize + 1
        font.weight: Font.Bold
        text: timeText
    }

    Row {
        id: contentRow
        x: itemsX
        height: parent.height
        anchors.verticalCenter: parent.verticalCenter
        opacity: clampedProgress
        spacing: groupSpacing

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.timeText
            color: "white"
            font.pixelSize: root.textPixelSize + 2
            font.family: root.timeFontFamily
            font.weight: Font.Bold
            font.letterSpacing: -0.25
            verticalAlignment: Text.AlignVCenter
        }

        Repeater {
            model: root.items

            delegate: Item {
                readonly property bool hasIcon: modelData.icon !== undefined && modelData.icon !== ""
                readonly property bool isCava: modelData.kind === "cava"
                readonly property bool isBattery: modelData.kind === "battery"
                readonly property bool isThemeIcon: hasIcon && modelData.iconKind === "theme"
                readonly property bool isGlyphIcon: hasIcon && modelData.iconKind !== "theme"
                readonly property bool hasLeadingVisual: hasIcon || isBattery
                implicitWidth: isCava ? cavaBars.implicitWidth : isBattery ? (root.batteryIconWidth + (modelData.isCharging ? 0 : 0)) : leadingVisual.width + (hasLeadingVisual ? root.iconSpacing : 0) + valueText.implicitWidth
                implicitHeight: root.height
                width: implicitWidth
                height: implicitHeight

                SwipeCavaBars {
                    id: cavaBars
                    visible: parent.isCava
                    anchors.centerIn: parent
                    levels: root.cavaLevels
                }

                Item {
                    id: leadingVisual
                    visible: !parent.isCava && parent.hasLeadingVisual
                    width: parent.isBattery ? root.batteryIconWidth : (parent.hasIcon ? root.iconBoxSize : 0)
                    height: parent.isBattery ? Math.max(root.batteryIconHeight, valueText.implicitHeight) : root.iconBoxSize
                    anchors.left: parent.left
                    anchors.leftMargin: 0
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        anchors.centerIn: parent
                        visible: parent.parent.isThemeIcon && !parent.parent.isBattery
                        width: root.iconBoxSize
                        height: root.iconBoxSize
                        source: (parent.parent.isThemeIcon && modelData.icon) ? Quickshell.iconPath(modelData.icon, true) : ""
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: parent.parent.isGlyphIcon && !parent.parent.isBattery
                        text: parent.parent.isGlyphIcon ? (modelData.icon || "") : ""
                        color: "white"
                    }

                    Item {
                        id: batteryShape
                        visible: parent.parent.isBattery
                        width: root.batteryIconWidth
                        height: root.batteryIconHeight
                        anchors.verticalCenter: parent.verticalCenter

                        readonly property real level: Math.max(0, Math.min(100, Number(modelData.level || 0)))
                        readonly property bool charging: modelData.isCharging || false
                        readonly property bool roundedEnd: level >= 85
                        readonly property color bodyColor: {
                            if (charging)
                                return "white";
                            if (level <= 20)
                                return "#ff3b30";
                            return "white";
                        }
                        readonly property color emptyColor: Qt.rgba(1, 1, 1, 0.56)

                        Rectangle {
                            id: batteryBody
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - root.batteryTipWidth - 1
                            height: parent.height
                            radius: root.batteryOuterRadius
                            color: batteryShape.emptyColor
                            border.width: 0
                            clip: true

                            Rectangle {
                                id: batteryFill
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                radius: 0
                                topLeftRadius: root.batteryOuterRadius
                                bottomLeftRadius: root.batteryOuterRadius
                                topRightRadius: batteryShape.roundedEnd ? root.batteryOuterRadius : 0
                                bottomRightRadius: batteryShape.roundedEnd ? root.batteryOuterRadius : 0
                                width: Math.max(root.batteryOuterRadius * 2, parent.width * (batteryShape.level / 100.0))
                                color: batteryShape.bodyColor

                                Behavior on width {
                                    NumberAnimation {
                                        duration: 300
                                        easing.type: Easing.OutCubic
                                    }
                                }
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 300
                                    }
                                }
                            }

                            Row {
                                visible: batteryShape.charging
                                anchors.centerIn: parent
                                anchors.horizontalCenterOffset: root.batteryChargingXOffset
                                anchors.verticalCenterOffset: root.batteryChargingYOffset
                                spacing: 2
                                z: 2

                                Text {
                                    text: batteryShape.level + ""
                                    color: "black"
                                    font.pixelSize: root.batteryFontSizeCharging
                                    font.family: root.textFontFamily
                                    font.weight: Font.DemiBold
                                    verticalAlignment: Text.AlignVCenter
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: "\uf0e7"
                                    color: "#242424"
                                    font.pixelSize: root.batteryBoltSize
                                    font.family: root.iconFontFamily
                                    verticalAlignment: Text.AlignVCenter
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Text {
                                visible: !batteryShape.charging
                                anchors.centerIn: parent
                                text: batteryShape.level + ""
                                color: batteryShape.level <= 20 ? "white" : "black"
                                font.pixelSize: root.batteryFontSize
                                font.family: root.textFontFamily
                                font.weight: batteryShape.level <= 20 ? Font.Bold : Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                                horizontalAlignment: Text.AlignHCenter
                                z: 2
                            }
                        }

                        Rectangle {
                            width: root.batteryTipWidth
                            height: root.batteryTipHeight
                            radius: Math.round(root.batteryTipWidth / 2)
                            color: batteryShape.level >= 100 ? batteryShape.bodyColor : batteryShape.emptyColor
                            anchors.left: batteryBody.right
                            anchors.leftMargin: 1
                            anchors.verticalCenter: parent.verticalCenter

                            Behavior on color {
                                ColorAnimation {
                                    duration: 300
                                }
                            }
                        }
                    }
                }

                Text {
                    id: valueText
                    visible: !parent.isCava && !parent.isBattery
                    anchors.left: leadingVisual.right
                    anchors.leftMargin: parent.hasLeadingVisual && !parent.isBattery ? root.iconSpacing : 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.text || ""
                    font.pixelSize: root.textPixelSize
                    font.weight: Font.Bold
                    color: "white"
                }
            }
        }
    }

    RecordingIndicator {
        id: timeRecordingIndicator
        active: root.recordingActive && root.showSecondaryText && root.timeText !== "" && root.clampedProgress < 0.001
        contentOpacity: 1 - root.clampedProgress
        x: root.timeRecordingDotX
        anchors.verticalCenter: parent.verticalCenter
    }

    Text {
        visible: timeText !== "" && showSecondaryText
        x: timeX
        width: textWidth
        anchors.verticalCenter: parent.verticalCenter
        text: timeText
        color: "white"
        opacity: 1 - clampedProgress
        font.pixelSize: root.textPixelSize + 1
        font.family: timeFontFamily
        font.weight: Font.Bold
        font.letterSpacing: -0.25
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        wrapMode: Text.NoWrap
    }
}
