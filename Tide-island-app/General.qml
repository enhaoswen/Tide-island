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

        Item {
            id: content
            width: scroller.width
            height: apperance.y + apperance.height + 40

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
                anchors.top : title.bottom
                anchors.topMargin: 40
                anchors.left: parent.left
                anchors.leftMargin: 32
                anchors.right: parent.right
                anchors.rightMargin: 40
                font.family: Theme.titleFontFamily
                font.pixelSize: 23
            }

            Rectangle {
                id: apperance
                color: "transparent"
                radius: 10
                border.width: 2
                border.color: Theme.splitLineColor

                anchors.top: apperanceTitle.bottom
                anchors.topMargin: 15
                anchors.left: parent.left
                anchors.leftMargin: 30
                anchors.right: parent.right
                anchors.rightMargin: 40
                height: 225

                ConfigRow {
                    id: islandWidthRow
                    title: "Island Width"
                    description: "Width of island in clock mode"
                    keyName: "islandWidth"
                    fallbackText: "140"
                    numeric: true
                    anchors.top: parent.top
                    anchors.topMargin: 15
                    anchors.left: parent.left
                    anchors.leftMargin: 30
                    anchors.right: parent.right
                    anchors.rightMargin: 100
                }

                Rectangle {
                    id: widthSplitLine
                    height: 2
                    anchors.top: islandWidthRow.bottom
                    anchors.topMargin: 15
                    anchors.left: parent.left
                    anchors.leftMargin: 15
                    anchors.right: parent.right
                    anchors.rightMargin: 15
                    color: Theme.splitLineColor
                }

                ConfigRow {
                    id: islandHeightRow
                    title: "Island Height"
                    description: "Height of island in clock mode"
                    keyName: "islandHeight"
                    fallbackText: "38"
                    numeric: true
                    anchors.top: widthSplitLine.top
                    anchors.topMargin: 15
                    anchors.left: parent.left
                    anchors.leftMargin: 30
                    anchors.right: parent.right
                    anchors.rightMargin: 100
                }

                Rectangle {
                    id: heightSplitLine
                    height: 2
                    anchors.top: islandHeightRow.bottom
                    anchors.topMargin: 15
                    anchors.left: parent.left
                    anchors.leftMargin: 15
                    anchors.right: parent.right
                    anchors.rightMargin: 15
                    color: Theme.splitLineColor
                }

                ConfigRow {
                    title: "Island Position"
                    description: "X position of island"
                    keyName: "islandPositionX"
                    fallbackText: "50"
                    numeric: true
                    minimumValue: 0
                    maximumValue: 100
                    anchors.top: heightSplitLine.top
                    anchors.topMargin: 15
                    anchors.left: parent.left
                    anchors.leftMargin: 30
                    anchors.right: parent.right
                    anchors.rightMargin: 100
                }
            }

        }
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

        height: 47

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
            anchors.top: rowTitle.top
            anchors.topMargin: 5
            anchors.right: parent.right
            width: row.numeric ? 100 : 230
            height: 35
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
}
