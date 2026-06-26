import QtQuick

Rectangle {
    id: sel
    property string fontFamily: ""
    property var languages: []
    property int selectedIndex: 0
    signal selected(int idx)

    radius: 9
    color: selMa.containsMouse ? "#2a2a2a" : "#1e1e1e"
    Behavior on color {
        ColorAnimation {
            duration: 120
        }
    }

    Text {
        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
            leftMargin: 10
        }
        text: sel.languages.length > 0 ? sel.languages[sel.selectedIndex].label : ""
        font.family: sel.fontFamily
        font.pixelSize: 12
        color: "#cccccc"
    }

    Text {
        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
            rightMargin: 8
        }
        text: "▾"
        font.pixelSize: 10
        color: "#666666"
    }

    MouseArea {
        id: selMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: dropdown.visible = !dropdown.visible
    }

    Rectangle {
        id: dropdown
        visible: false
        z: 100
        anchors.top: parent.bottom
        anchors.topMargin: 4
        anchors.left: parent.left
        width: parent.width
        height: sel.languages.length * 34
        radius: 9
        color: "#1e1e1e"
        border.width: 1
        border.color: "#2a2a2a"

        Column {
            anchors.fill: parent
            anchors.margins: 4
            spacing: 2

            Repeater {
                model: sel.languages
                Rectangle {
                    width: parent.width
                    height: 28
                    radius: 6
                    color: optMa.containsMouse ? "#2a2a2a" : (sel.selectedIndex === index ? "#222233" : "transparent")

                    Behavior on color {
                        ColorAnimation {
                            duration: 100
                        }
                    }

                    Text {
                        anchors {
                            left: parent.left
                            verticalCenter: parent.verticalCenter
                            leftMargin: 8
                        }
                        text: modelData.label
                        font.family: sel.fontFamily
                        font.pixelSize: 12
                        color: sel.selectedIndex === index ? "#3d7aed" : "#cccccc"
                    }

                    MouseArea {
                        id: optMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            sel.selected(index);
                            dropdown.visible = false;
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: sel.Window.window
        function onActiveFocusItemChanged() {
            dropdown.visible = false;
        }
    }
}
