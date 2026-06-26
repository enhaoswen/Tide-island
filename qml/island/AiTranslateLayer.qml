import QtQuick
import QtQuick.Controls

Item {
    id: aiTranslateLayer

    property string iconFontFamily: ""
    property string textFontFamily: ""
    property bool showCondition: false
    signal closeRequested

    AiTranslateBackend {
        id: backend
    }

    opacity: showCondition ? 1 : 0
    Behavior on opacity {
        NumberAnimation {
            duration: 180
            easing.type: Easing.InOutQuad
        }
    }

    anchors.fill: parent

    Item {
        id: header
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            topMargin: 12
        }
        height: 36

        Text {
            anchors.centerIn: parent
            text: "⇄  Translate"
            font.family: aiTranslateLayer.textFontFamily
            font.pixelSize: 13
            font.weight: Font.DemiBold
            color: "#ffffff"
        }

        Rectangle {
            width: 28
            height: 28
            anchors {
                right: parent.right
                rightMargin: 12
                verticalCenter: parent.verticalCenter
            }
            radius: 8
            color: closeMa.containsMouse ? "#2a2a2a" : "transparent"
            Behavior on color {
                ColorAnimation {
                    duration: 120
                }
            }

            Text {
                anchors.centerIn: parent
                text: "✕"
                font.pixelSize: 12
                color: "#666666"
            }

            MouseArea {
                id: closeMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: aiTranslateLayer.closeRequested()
            }
        }
    }

    Rectangle {
        id: headerDivider
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            topMargin: 4
            leftMargin: 12
            rightMargin: 12
        }
        height: 1
        color: "#222222"
    }

    TranslateTab {
        id: translateTab
        anchors {
            top: headerDivider.bottom
            bottom: parent.bottom
            left: parent.left
            right: parent.right
            topMargin: 8
            leftMargin: 12
            rightMargin: 12
            bottomMargin: 12
        }
        textFontFamily: aiTranslateLayer.textFontFamily
        backend: backend
        isActive: aiTranslateLayer.showCondition
    }
}
