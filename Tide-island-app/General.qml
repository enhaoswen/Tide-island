import TideIsland 1.0
import QtQuick.Controls
import QtQuick

PagePanel {
    id: root

    function intValue(key, fallback) {
        return String(ConfigStore.value(key, fallback))
    }

    function saveInt(key, value, fallback, minimumValue, maximumValue) {
        if (String(value).trim().length === 0) {
            return fallback
        }

        const parsedValue = Number(value)
        if (isNaN(parsedValue)) {
            return fallback
        }

        const roundedValue = Math.min(maximumValue, Math.max(minimumValue, Math.round(parsedValue)))
        ConfigStore.setValue(key, roundedValue)
        ConfigStore.save()
        return roundedValue
    }

    Flickable {
        id: scroller
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: content.height
        boundsBehavior: Flickable.StopAtBounds
        boundsMovement: Flickable.StopAtBounds
        interactive: false

        WheelHandler {
            target: null
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

            onWheel: function(event) {
                const rawDelta = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y / 120 * 64
                const maxY = Math.max(0, scroller.contentHeight - scroller.height)
                scroller.contentY = Math.max(0, Math.min(maxY, scroller.contentY - rawDelta))
                event.accepted = true
            }
        }

        Item {
            id: content
            width: scroller.width
            height: tlpPanel.y + tlpPanel.height + 40

            Text {
                id: title
                font.family: Theme.titleFontFamily
                text: "General"
                font.pixelSize: 30
                x: 60
                y: 50
            }

            Text {
                id: apperanceTitle
                text: "Island apperance"
                anchors.top: title.bottom
                anchors.topMargin: 34
                anchors.left: parent.left
                anchors.leftMargin: 32
                anchors.right: parent.right
                anchors.rightMargin: 40
                font.family: Theme.titleFontFamily
                font.pixelSize: 23
            }

            Rectangle {
                id: apperance
                color: Theme.cardBgColor
                radius: 16
                border.width: 1
                border.color: Theme.splitLineColor

                anchors.top: apperanceTitle.bottom
                anchors.topMargin: 15
                anchors.left: parent.left
                anchors.leftMargin: 30
                anchors.right: parent.right
                anchors.rightMargin: 40
                height: apperanceColumn.implicitHeight + 36

                Column {
                    id: apperanceColumn

                    anchors.top: parent.top
                    anchors.topMargin: 18
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    spacing: 16

                    ConfigRow {
                        title: "Island Width"
                        description: "Width of island in clock mode"
                        keyName: "islandWidth"
                        fallbackText: "140"
                        numeric: true
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ConfigRow {
                        title: "Island Height"
                        description: "Height of island in clock mode"
                        keyName: "islandHeight"
                        fallbackText: "38"
                        numeric: true
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ClockFormatRow { width: parent.width }

                    SplitLine { width: parent.width }

                    ConfigRow {
                        title: "Reserved Top Space"
                        description: "Screen space reserved for the island (exclusive zone)"
                        keyName: "islandExclusiveZone"
                        fallbackText: "45"
                        numeric: true
                        minimumValue: 0
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ConfigRow {
                        title: "Top Margin"
                        description: "Distance between the island and the top of the screen"
                        keyName: "islandTopMargin"
                        fallbackText: "4"
                        numeric: true
                        minimumValue: 0
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ConfigRow {
                        title: "Island Position"
                        description: "X position of island"
                        keyName: "islandPositionX"
                        fallbackText: "50"
                        numeric: true
                        minimumValue: 0
                        maximumValue: 100
                        width: parent.width
                    }
                }
            }

            Text {
                id: customPageTitle
                text: "Custom Page"
                anchors.top: apperance.bottom
                anchors.topMargin: 34
                anchors.left: parent.left
                anchors.leftMargin: 32
                anchors.right: parent.right
                anchors.rightMargin: 40
                font.family: Theme.titleFontFamily
                font.pixelSize: 23
            }

            CustomPage {
                id: customPagePanel
                anchors.top: customPageTitle.bottom
                anchors.topMargin: 15
                anchors.left: parent.left
                anchors.leftMargin: 30
                anchors.right: parent.right
                anchors.rightMargin: 40
                height: implicitHeight
            }

            Text {
                id: tlpTitle
                text: "TLP"
                anchors.top: customPagePanel.bottom
                anchors.topMargin: 34
                anchors.left: parent.left
                anchors.leftMargin: 32
                anchors.right: parent.right
                anchors.rightMargin: 40
                font.family: Theme.titleFontFamily
                font.pixelSize: 23
            }

            TlpSettings {
                id: tlpPanel
                anchors.top: tlpTitle.bottom
                anchors.topMargin: 15
                anchors.left: parent.left
                anchors.leftMargin: 30
                anchors.right: parent.right
                anchors.rightMargin: 40
                height: implicitHeight
            }

        }
    }

    component SplitLine: Rectangle {
        height: 1
        color: Theme.splitLineColor
    }

    component ConfigRow: Item {
        id: row

        property string title: ""
        property string description: ""
        property string keyName: ""
        property string fallbackText: ""
        property bool numeric: false
        property int minimumValue: 1
        property int maximumValue: 1000

        height: 49

        Text {
            id: rowTitle
            text: row.title
            font.family: Theme.textFontFamily
            font.pixelSize: 18
            anchors.top: parent.top
            anchors.left: parent.left
        }

        Text {
            text: row.description
            font.family: Theme.textFontFamily
            font.pixelSize: 14
            anchors.top: rowTitle.bottom
            anchors.topMargin: 5
            anchors.left: rowTitle.left
            color: Theme.subtleTextColor
        }

        ConfigTextField {
            id: field
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: row.numeric ? 100 : 230
            height: 36
            placeholderText: row.fallbackText
            inputMethodHints: row.numeric ? Qt.ImhDigitsOnly : Qt.ImhNone
            validator: row.numeric ? intValidator : null

            Component.onCompleted: {
                text = root.intValue(row.keyName, Number(row.fallbackText))
            }

            onAccepted: row.commit()
            onEditingFinished: row.commit()
        }

        IntValidator {
            id: intValidator
            bottom: row.minimumValue
            top: row.maximumValue
        }

        function commit() {
            if (numeric) {
                field.text = String(root.saveInt(row.keyName, field.text, Number(row.fallbackText), row.minimumValue, row.maximumValue))
            }
        }
    }

    component ClockFormatRow: Item {
        id: clockRow

        property string selectedFormat: String(ConfigStore.value("clockFormat", "12")) === "24" ? "24" : "12"

        height: 49

        Text {
            id: clockTitle
            text: "Clock Format"
            font.family: Theme.textFontFamily
            font.pixelSize: 18
            anchors.top: parent.top
            anchors.left: parent.left
        }

        Text {
            text: "Choose 12-hour or 24-hour time"
            font.family: Theme.textFontFamily
            font.pixelSize: 14
            anchors.top: clockTitle.bottom
            anchors.topMargin: 5
            anchors.left: clockTitle.left
            color: Theme.subtleTextColor
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Repeater {
                model: ["12", "24"]

                Rectangle {
                    id: formatButton
                    readonly property bool selected: clockRow.selectedFormat === modelData

                    width: 82
                    height: 36
                    radius: 7
                    color: selected ? Theme.cardBgColor
                                    : formatMouse.pressed ? Theme.controlPressedColor
                                                          : Theme.componentBgColor
                    border.width: 1
                    border.color: Theme.inputBorderColor

                    Behavior on color { ColorAnimation { duration: Theme.animationDuration } }
                    Behavior on border.color { ColorAnimation { duration: Theme.animationDuration } }

                    Text {
                        anchors.centerIn: parent
                        text: modelData + " hour"
                        color: formatButton.selected ? Theme.textColor : Theme.secondaryTextColor
                        font.family: Theme.textFontFamily
                        font.pixelSize: 14
                        font.weight: formatButton.selected ? Font.DemiBold : Font.Normal
                    }

                    MouseArea {
                        id: formatMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            clockRow.selectedFormat = modelData
                            ConfigStore.setValue("clockFormat", modelData)
                            ConfigStore.save()
                        }
                    }
                }
            }
        }
    }
}
