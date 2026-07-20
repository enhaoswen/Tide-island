import TideIsland 1.0
import QtQuick.Controls
import QtQuick

PagePanel {
    id: root

    function textValue(key, fallback) {
        return String(ConfigStore.value(key, fallback))
    }

    function intValue(key, fallback) {
        return String(ConfigStore.value(key, fallback))
    }

    function saveText(key, value) {
        ConfigStore.setValue(key, value)
        ConfigStore.save()
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
            height: fontPanel.y + fontPanel.height + 40

            Text {
                id: title
                font.family: Theme.titleFontFamily
                text: "Font"
                font.pixelSize: 30
                x: 60
                y: 50
            }

            Text {
                id: fontTitle
                text: "Font settings"
                anchors.top: title.bottom
                anchors.topMargin: 40
                anchors.left: parent.left
                anchors.leftMargin: 32
                anchors.right: parent.right
                anchors.rightMargin: 40
                font.family: Theme.titleFontFamily
                font.pixelSize: 23
            }

            Rectangle {
                id: fontPanel
                color: Theme.cardBgColor
                radius: 16
                border.width: 1
                border.color: Theme.splitLineColor

                anchors.top: fontTitle.bottom
                anchors.topMargin: 15
                anchors.left: parent.left
                anchors.leftMargin: 30
                anchors.right: parent.right
                anchors.rightMargin: 40
                height: fontColumn.height + 30

                Column {
                    id: fontColumn
                    anchors.top: parent.top
                    anchors.topMargin: 15
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    spacing: 15

                    ConfigRow {
                        title: "Icon Font Family"
                        description: "Font used for island icon glyphs"
                        keyName: "iconFontFamily"
                        fallbackText: "JetBrainsMono Nerd Font"
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ConfigRow {
                        title: "Text Font Family"
                        description: "Body and paragraph text font"
                        keyName: "textFontFamily"
                        fallbackText: "Inter Display"
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ConfigRow {
                        title: "Hero Font Family"
                        description: "Heading and hero text font"
                        keyName: "heroFontFamily"
                        fallbackText: "Inter Display"
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ConfigRow {
                        title: "Time Font Family"
                        description: "Clock and time display font"
                        keyName: "timeFontFamily"
                        fallbackText: "Inter Display"
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ConfigRow {
                        title: "Body Font Size"
                        description: "Base pixel size for body text"
                        keyName: "bodyFontSize"
                        fallbackText: "16"
                        numeric: true
                        maximumValue: 200
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ConfigRow {
                        title: "Title Font Size"
                        description: "Base pixel size for headings and hero text"
                        keyName: "titleFontSize"
                        fallbackText: "20"
                        numeric: true
                        maximumValue: 200
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ConfigRow {
                        title: "Icon Font Size"
                        description: "Base pixel size for icon glyphs"
                        keyName: "iconFontSize"
                        fallbackText: "18"
                        numeric: true
                        maximumValue: 200
                        width: parent.width
                    }
                }
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
                text = row.numeric
                    ? root.intValue(row.keyName, Number(row.fallbackText))
                    : root.textValue(row.keyName, row.fallbackText)
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
            } else {
                root.saveText(row.keyName, field.text)
            }
        }
    }
}
