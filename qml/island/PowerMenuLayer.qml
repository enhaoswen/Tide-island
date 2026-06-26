import QtQuick
import Quickshell.Io

Item {
    id: root

    signal closeRequested

    property string iconFontFamily: ""
    property string textFontFamily: ""
    property bool showCondition: false
    property int highlightedIndex: -1

    focus: true
    opacity: showCondition ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: 200
            easing.type: Easing.InOutQuad
        }
    }

    onShowConditionChanged: {
        if (showCondition) {
            highlightedIndex = -1;
            focusTimer.restart();
        }
    }

    Timer {
        id: focusTimer
        interval: 80
        repeat: false
        onTriggered: root.forceActiveFocus()
    }

    function moveHighlight(delta) {
        const count = 5;
        let next = highlightedIndex + delta;
        if (next < 0)
            next = count - 1;
        if (next >= count)
            next = 0;
        highlightedIndex = next;
    }

    function activateHighlighted() {
        switch (highlightedIndex) {
        case 0:
            lockProcess.running = true;
            break;
        case 1:
            suspendProcess.running = true;
            break;
        case 2:
            logoutProcess.running = true;
            break;
        case 3:
            rebootProcess.running = true;
            break;
        case 4:
            shutdownProcess.running = true;
            break;
        }
    }

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Right:
        case Qt.Key_Tab:
            moveHighlight(1);
            event.accepted = true;
            break;
        case Qt.Key_Left:
        case Qt.Key_Backtab:
            moveHighlight(-1);
            event.accepted = true;
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (highlightedIndex >= 0)
                activateHighlighted();
            event.accepted = true;
            break;
        case Qt.Key_Escape:
            root.closeRequested();
            event.accepted = true;
            break;
        }
    }

    // Uptime process
    Process {
        id: uptimeProcess
        command: ["bash", "-c", "uptime -p | sed 's/up //'"]
        running: root.showCondition
        stdout: SplitParser {
            onRead: data => uptimeLabel.text = "Uptime: " + data.trim()
        }
    }

    // Action processes
    Process {
        id: lockProcess
        command: ["bash", "-c", "hyprlock"]
    }
    Process {
        id: suspendProcess
        command: ["bash", "-c", "systemctl suspend"]
    }
    Process {
        id: logoutProcess
        command: ["bash", "-c", "loginctl terminate-user $USER"]
    }
    Process {
        id: rebootProcess
        command: ["bash", "-c", "systemctl reboot"]
    }
    Process {
        id: shutdownProcess
        command: ["bash", "-c", "systemctl poweroff"]
    }

    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        Text {
            id: uptimeLabel
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Uptime: ..."
            color: Qt.rgba(1, 1, 1, 0.45)
            font.pixelSize: 11
            font.family: root.textFontFamily
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 0

            Repeater {
                model: [
                    {
                        label: "Lock",
                        icon: "\uf023",
                        process: lockProcess
                    },
                    {
                        label: "Suspend",
                        icon: "\uf186",
                        process: suspendProcess
                    },
                    {
                        label: "Logout",
                        icon: "\uf2f5 ",
                        process: logoutProcess
                    },
                    {
                        label: "Reboot",
                        icon: "\uf021",
                        process: rebootProcess
                    },
                    {
                        label: "Shutdown",
                        icon: "\uf011",
                        process: shutdownProcess
                    },
                ]

                delegate: Item {
                    width: 72
                    height: 80

                    Column {
                        anchors.centerIn: parent
                        spacing: 6

                        Rectangle {
                            width: 44
                            height: 44
                            radius: 22
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: (index === root.highlightedIndex) ? Qt.rgba(1, 1, 1, 0.22) : buttonMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)

                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: modelData.icon
                                color: "white"
                                font.pixelSize: 18
                                font.family: root.iconFontFamily
                            }

                            MouseArea {
                                id: buttonMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: modelData.process.running = true
                                onContainsMouseChanged: {
                                    if (containsMouse)
                                        root.highlightedIndex = index;
                                }
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.label
                            color: (index === root.highlightedIndex) ? "white" : Qt.rgba(1, 1, 1, 0.75)
                            font.pixelSize: 11
                            font.family: root.textFontFamily
                            font.weight: Font.Medium

                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
