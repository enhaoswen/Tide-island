import QtQuick

Item {
    id: root

    signal controlPressed
    signal settingsPressed
    signal pomodoroFinished(string summary, string body)

    property bool showCondition: false

    property string currentArtUrl: ""
    property string currentTrack: ""
    property string currentArtist: ""
    property string preloadedArtSource: ""
    property string timePlayed: "0:00"
    property string timeTotal: "0:00"
    property real trackProgress: 0
    property var activePlayer: null
    property string iconFontFamily: ""
    property string textFontFamily: ""
    property bool progressDragging: false

    property string activeTab: "nook"

    property int pomodoroTotal: 25 * 60
    property int pomodoroRemaining: 25 * 60
    property bool pomodoroRunning: false
    property string pomodoroMode: "focus"
    property int sessionsCompleted: 0

    Timer {
        id: pomodoroCountdown
        interval: 1000
        repeat: true
        running: root.pomodoroRunning
        onTriggered: {
            if (root.pomodoroRemaining > 0) {
                root.pomodoroRemaining--;
            } else {
                root.pomodoroRunning = false;
                if (root.pomodoroMode === "focus")
                    root.sessionsCompleted++;
                root.pomodoroFinished(root.pomodoroMode === "focus" ? "⏱ Focus Complete" : "⏱ Break Complete", root.pomodoroMode === "focus" ? "Time for a break!" : "Back to work!");
            }
        }
    }

    anchors.fill: parent
    opacity: showCondition ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: showCondition ? 300 : 100
            easing.type: Easing.InOutQuad
        }
    }

    onShowConditionChanged: {
        if (showCondition)
            activeTab = "nook";
    }

    Row {
        id: tabBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 7
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        height: 22
        spacing: 6

        Rectangle {
            id: nookTab
            height: 22
            width: nookInner.implicitWidth + 18
            radius: 11
            color: activeTab === "nook" ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }

            Row {
                id: nookInner
                anchors.centerIn: parent
                spacing: 5
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uf001"
                    font.family: root.iconFontFamily
                    font.pixelSize: 10
                    color: activeTab === "nook" ? "white" : Qt.rgba(1, 1, 1, 0.36)
                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Nook"
                    font.family: root.textFontFamily
                    font.pixelSize: 11
                    font.weight: activeTab === "nook" ? Font.SemiBold : Font.Regular
                    color: activeTab === "nook" ? "white" : Qt.rgba(1, 1, 1, 0.36)
                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                preventStealing: true
                onPressed: root.controlPressed()
                onClicked: root.activeTab = "nook"
            }
        }

        Rectangle {
            id: todoTab
            height: 22
            width: todoInner.implicitWidth + 18
            radius: 11
            color: activeTab === "todo" ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }

            Row {
                id: todoInner
                anchors.centerIn: parent
                spacing: 5
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uf0ae"
                    font.family: root.iconFontFamily
                    font.pixelSize: 10
                    color: activeTab === "todo" ? "white" : Qt.rgba(1, 1, 1, 0.36)
                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Todo"
                    font.family: root.textFontFamily
                    font.pixelSize: 11
                    font.weight: activeTab === "todo" ? Font.SemiBold : Font.Regular
                    color: activeTab === "todo" ? "white" : Qt.rgba(1, 1, 1, 0.36)
                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                preventStealing: true
                onPressed: root.controlPressed()
                onClicked: root.activeTab = "todo"
            }
        }

        Rectangle {
            id: timerTab
            height: 22
            width: timerInner.implicitWidth + 18
            radius: 11
            color: activeTab === "timer" ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }

            Row {
                id: timerInner
                anchors.centerIn: parent
                spacing: 5
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uf017"
                    font.family: root.iconFontFamily
                    font.pixelSize: 10
                    color: activeTab === "timer" ? "white" : Qt.rgba(1, 1, 1, 0.36)
                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Timer"
                    font.family: root.textFontFamily
                    font.pixelSize: 11
                    font.weight: activeTab === "timer" ? Font.SemiBold : Font.Regular
                    color: activeTab === "timer" ? "white" : Qt.rgba(1, 1, 1, 0.36)
                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                preventStealing: true
                onPressed: root.controlPressed()
                onClicked: root.activeTab = "timer"
            }
        }

        Item {
            width: tabBar.width - nookTab.width - todoTab.width - timerTab.width - tabBar.spacing * 3 - gearIcon.contentWidth - 8
            height: 1
        }

        Text {
            id: gearIcon
            anchors.verticalCenter: parent.verticalCenter
            text: "\uf013"
            font.family: root.iconFontFamily
            font.pixelSize: 13
            color: gearMouse.pressed ? Qt.rgba(1, 1, 1, 0.7) : Qt.rgba(1, 1, 1, 0.28)
            Behavior on color {
                ColorAnimation {
                    duration: 100
                }
            }
            MouseArea {
                id: gearMouse
                anchors.fill: parent
                anchors.margins: -8
                preventStealing: true
                onPressed: root.controlPressed()
                onClicked: root.settingsPressed()
            }
        }
    }

    Rectangle {
        anchors.top: tabBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        anchors.topMargin: 4
        height: 1
        color: Qt.rgba(1, 1, 1, 0.06)
    }

    Item {
        anchors.top: tabBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: 5

        ExpandedPlayerLayer {
            anchors.fill: parent
            enabled: root.activeTab === "nook"
            showCondition: root.activeTab === "nook" && root.showCondition
            currentArtUrl: root.currentArtUrl
            preloadedArtSource: root.preloadedArtSource
            currentTrack: root.currentTrack
            currentArtist: root.currentArtist
            timePlayed: root.timePlayed
            timeTotal: root.timeTotal
            trackProgress: root.trackProgress
            activePlayer: root.activePlayer
            iconFontFamily: root.iconFontFamily
            textFontFamily: root.textFontFamily
            onControlPressed: root.controlPressed()
            onProgressDraggingChanged: root.progressDragging = progressDragging
        }

        TodoLayer {
            anchors.fill: parent
            enabled: root.activeTab === "todo"
            showCondition: root.activeTab === "todo" && root.showCondition
            iconFontFamily: root.iconFontFamily
            textFontFamily: root.textFontFamily
        }

        PomodoroLayer {
            anchors.fill: parent
            enabled: root.activeTab === "timer"
            showCondition: root.activeTab === "timer" && root.showCondition
            iconFontFamily: root.iconFontFamily
            textFontFamily: root.textFontFamily

            pomodoroTotal: root.pomodoroTotal
            pomodoroRemaining: root.pomodoroRemaining
            pomodoroRunning: root.pomodoroRunning
            pomodoroMode: root.pomodoroMode
            sessionsCompleted: root.sessionsCompleted

            onRequestSetRunning: root.pomodoroRunning = running
            onRequestSetMode: {
                root.pomodoroMode = mode;
                root.pomodoroTotal = total;
                root.pomodoroRemaining = total;
            }
            onRequestReset: {
                root.pomodoroRunning = false;
                root.pomodoroRemaining = root.pomodoroTotal;
            }
        }
    }
}
