import QtQuick
import QtQuick.Controls
import Theme 1.0

ApplicationWindow {
    id: window
    visible: true
    width: 1000
    height: 600
    title: "Tide Island Config Application"
    color: Theme.totalBgColor

    property int currentPage: 1

    Rectangle{// main split line
        id:mainSplitLine
        height: parent.height - 60
        width:2
        color: Theme.splitLineColor
        x: Theme.animationDuration
        y: 30

        DragHandler {
            target: parent
            xAxis.enabled: true
            yAxis.enabled: false
            xAxis.minimum: 50
            xAxis.maximum: 250
        }

        MouseArea{
            anchors.fill:parent
            cursorShape: Qt.SizeHorCursor
        }
    }

    Item{
        id: outline
        width: mainSplitLine.x
        height:window.height
        
        Text{
            id: title
            anchors.horizontalCenter: parent.horizontalCenter
            y: 80
            color: Theme.textColor
            text: tideIslandText.width > mainSplitLine.x ? "T" : "Tide Island"
            font.pixelSize: 25
            font.family: Theme.fontFamily

            TextMetrics {
                id: tideIslandText
                font: islandButton.font
                text: "Tide Island"
            }

            Behavior on color {ColorAnimation{ duration:Theme.animationDuration}}

            MouseArea{
                hoverEnabled: true
                anchors.fill: parent
                onEntered: title.color = Theme.selectedColor
                onExited: title.color = Theme.textColor
                onClicked: Qt.openUrlExternally("https://github.com/enhaoswen/Tide-island")
            }
        }

        Text{
            id: islandButton
            anchors.horizontalCenter: parent.horizontalCenter
            y: 300
            color: currentPage === 1 ? Theme.selectedColor : Theme.textColor
            text: islandButtonText.width > mainSplitLine.x ? "G" : "General"
            font.family: Theme.fontFamily
            font.pixelSize: 25

            TextMetrics {
                id: islandButtonText
                font: islandButton.font
                text: "General"
            }

            Behavior on color {ColorAnimation{ duration:Theme.animationDuration}}

            MouseArea{
                anchors.fill:parent

                onClicked: {
                    currentPage = 1
                }
            }
        }

        Text{
            id: shortcutButton
            anchors.horizontalCenter: parent.horizontalCenter
            y: 350
            color: currentPage === 2 ? Theme.selectedColor : Theme.textColor
            text: shortcutButtonText.width > mainSplitLine.x ? "S" : "Shortcut"
            font.family: Theme.fontFamily
            font.pixelSize: 25

            TextMetrics {
                id: shortcutButtonText
                font: shortcutButton.font
                text: "Shortcut"
            }

            Behavior on color {ColorAnimation{ duration:Theme.animationDuration}}

            MouseArea{
                anchors.fill:parent

                onClicked: {
                    currentPage = 2
                }
            }
        }

        Text{
            id: interactionButton
            anchors.horizontalCenter: parent.horizontalCenter
            y: 400
            color: currentPage === 2 ? Theme.selectedColor : Theme.textColor
            text: interactionButtonText.width > mainSplitLine.x ? "I" : "Interaction"
            font.family: Theme.fontFamily
            font.pixelSize: 25

            TextMetrics {
                id: interactionButtonText
                font:interactionButton.font
                text: "Interaction"
            }

            Behavior on color {ColorAnimation{ duration:Theme.animationDuration}}

            MouseArea{
                anchors.fill:parent

                onClicked: {
                    currentPage = 2
                }
            }
        }
    }



    Item{
        id: page
        anchors.left: mainSplitLine.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom

    }
}
