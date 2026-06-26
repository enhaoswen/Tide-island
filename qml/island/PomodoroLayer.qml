import QtQuick

Item {
    id: root

    property string iconFontFamily: ""
    property string textFontFamily: ""
    property bool showCondition: false

    // State passed in from NookTrayLayer
    property int pomodoroTotal: 25 * 60
    property int pomodoroRemaining: 25 * 60
    property bool pomodoroRunning: false
    property string pomodoroMode: "focus"
    property int sessionsCompleted: 0

    // Signals back up to parent
    signal requestSetRunning(bool running)
    signal requestSetMode(string mode, int total)
    signal requestReset

    opacity: showCondition ? 1 : 0
    anchors.fill: parent

    Behavior on opacity {
        NumberAnimation {
            duration: 200
            easing.type: Easing.InOutQuad
        }
    }

    readonly property var modes: [
        {
            label: "Focus",
            secs: 25 * 60,
            mode: "focus"
        },
        {
            label: "Short break",
            secs: 5 * 60,
            mode: "short"
        },
        {
            label: "Long break",
            secs: 15 * 60,
            mode: "long"
        }
    ]

    function formatTime(secs) {
        const m = Math.floor(secs / 60);
        const s = secs % 60;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    readonly property real progress: 1.0 - pomodoroRemaining / Math.max(1, pomodoroTotal)

    // ── UI ────────────────────────────────────────────────────────
    Row {
        anchors.centerIn: parent
        spacing: 20

        // ── Left: ring + time ─────────────────────────────────────
        Item {
            width: 120
            height: 120
            anchors.verticalCenter: parent.verticalCenter

            Canvas {
                id: bgRing
                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.beginPath();
                    ctx.arc(width / 2, height / 2, 50, 0, Math.PI * 2);
                    ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.08);
                    ctx.lineWidth = 7;
                    ctx.stroke();
                }
            }

            Canvas {
                id: progressRing
                anchors.fill: parent
                property real prog: root.progress
                property string mode: root.pomodoroMode
                onProgChanged: requestPaint()
                onModeChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    if (prog <= 0)
                        return;
                    ctx.beginPath();
                    ctx.arc(width / 2, height / 2, 50, -Math.PI / 2, -Math.PI / 2 + prog * Math.PI * 2);
                    ctx.strokeStyle = mode === "focus" ? "#b56cff" : "#60a5fa";
                    ctx.lineWidth = 7;
                    ctx.lineCap = "round";
                    ctx.stroke();
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 3

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: formatTime(pomodoroRemaining)
                    color: pomodoroRunning ? "white" : Qt.rgba(1, 1, 1, 0.75)
                    font.pixelSize: 28
                    font.family: root.textFontFamily
                    font.weight: Font.Light
                    font.letterSpacing: -1
                    Behavior on color {
                        ColorAnimation {
                            duration: 200
                        }
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: pomodoroMode === "focus" ? "Focus" : pomodoroMode === "short" ? "Short" : "Long"
                    color: Qt.rgba(1, 1, 1, 0.28)
                    font.pixelSize: 10
                    font.family: root.textFontFamily
                }
            }
        }

        // ── Right: mode pills + controls + dots ───────────────────
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            // Mode pills stacked
            Column {
                spacing: 5

                Repeater {
                    model: root.modes
                    delegate: Rectangle {
                        width: 118
                        height: 26
                        radius: 13
                        color: pomodoroMode === modelData.mode ? Qt.rgba(181 / 255, 108 / 255, 1, 0.22) : Qt.rgba(1, 1, 1, 0.06)
                        border.color: pomodoroMode === modelData.mode ? "#b56cff" : "transparent"
                        border.width: 1
                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            color: pomodoroMode === modelData.mode ? "#b56cff" : Qt.rgba(1, 1, 1, 0.42)
                            font.pixelSize: 11
                            font.family: root.textFontFamily
                            font.weight: Font.Medium
                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (pomodoroRunning)
                                    return;
                                root.requestSetMode(modelData.mode, modelData.secs);
                            }
                        }
                    }
                }
            }

            // Start/Pause + Reset
            Row {
                spacing: 6

                Rectangle {
                    width: 68
                    height: 26
                    radius: 13
                    color: pomodoroRunning ? Qt.rgba(1, 1, 1, 0.10) : "#b56cff"
                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: pomodoroRunning ? "Pause" : "Start"
                        color: "white"
                        font.pixelSize: 11
                        font.family: root.textFontFamily
                        font.weight: Font.SemiBold
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.requestSetRunning(!pomodoroRunning)
                    }
                }

                Rectangle {
                    width: 44
                    height: 26
                    radius: 13
                    color: resetMouse.pressed ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.07)
                    Behavior on color {
                        ColorAnimation {
                            duration: 100
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "Reset"
                        color: Qt.rgba(1, 1, 1, 0.45)
                        font.pixelSize: 11
                        font.family: root.textFontFamily
                    }

                    MouseArea {
                        id: resetMouse
                        anchors.fill: parent
                        onClicked: root.requestReset()
                    }
                }

                // Session dots
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Repeater {
                        model: 4
                        delegate: Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            anchors.verticalCenter: parent.verticalCenter
                            color: index < (sessionsCompleted % 4) ? "#b56cff" : Qt.rgba(1, 1, 1, 0.12)
                            Behavior on color {
                                ColorAnimation {
                                    duration: 200
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
