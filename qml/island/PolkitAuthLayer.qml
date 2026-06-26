import QtQuick
import IslandBackend

Item {
    id: root

    property bool showCondition: false
    property string iconFontFamily: ""
    property string textFontFamily: ""

    signal closeRequested

    anchors.fill: parent
    opacity: showCondition ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: showCondition ? 280 : 140
            easing.type: Easing.InOutQuad
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 14

        Row {
            width: parent.width
            spacing: 10

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf023"
                font.family: root.iconFontFamily
                font.pixelSize: 18
                color: Qt.rgba(1, 1, 1, 0.75)
            }

            Column {
                spacing: 2
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    text: "Authentication Required"
                    color: "white"
                    font.family: root.textFontFamily
                    font.pixelSize: 14
                    font.weight: Font.SemiBold
                    font.letterSpacing: -0.2
                }

                Text {
                    text: PolkitAgent.message !== "" ? PolkitAgent.message : "Enter your password to continue"
                    color: Qt.rgba(1, 1, 1, 0.45)
                    font.family: root.textFontFamily
                    font.pixelSize: 11
                    font.weight: Font.Regular
                    width: 320
                    elide: Text.ElideRight
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Qt.rgba(1, 1, 1, 0.07)
        }

        Row {
            width: parent.width
            spacing: 6

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf013"
                font.family: root.iconFontFamily
                font.pixelSize: 11
                color: Qt.rgba(1, 1, 1, 0.3)
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: PolkitAgent.appName !== "" ? PolkitAgent.appName : "System"
                color: Qt.rgba(1, 1, 1, 0.38)
                font.family: root.textFontFamily
                font.pixelSize: 11
                font.weight: Font.Regular
            }
        }

        Rectangle {
            width: parent.width
            height: 34
            radius: 10
            color: passwordInput.activeFocus ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.06)

            Behavior on color {
                ColorAnimation {
                    duration: 120
                }
            }

            SequentialAnimation {
                id: shakeAnim
                NumberAnimation {
                    target: passwordField
                    property: "x"
                    to: passwordField.x + 6
                    duration: 40
                }
                NumberAnimation {
                    target: passwordField
                    property: "x"
                    to: passwordField.x - 6
                    duration: 40
                }
                NumberAnimation {
                    target: passwordField
                    property: "x"
                    to: passwordField.x + 4
                    duration: 40
                }
                NumberAnimation {
                    target: passwordField
                    property: "x"
                    to: passwordField.x - 4
                    duration: 40
                }
                NumberAnimation {
                    target: passwordField
                    property: "x"
                    to: passwordField.x
                    duration: 40
                }
            }

            Row {
                id: passwordField
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uf084"
                    font.family: root.iconFontFamily
                    font.pixelSize: 12
                    color: Qt.rgba(1, 1, 1, 0.3)
                }

                TextInput {
                    id: passwordInput
                    width: parent.width - 30
                    anchors.verticalCenter: parent.verticalCenter
                    color: "white"
                    font.family: root.textFontFamily
                    font.pixelSize: 13
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    clip: true
                    focus: root.showCondition

                    Text {
                        anchors.fill: parent
                        anchors.verticalCenter: parent.verticalCenter
                        verticalAlignment: Text.AlignVCenter
                        text: "Password"
                        color: Qt.rgba(1, 1, 1, 0.22)
                        font.family: root.textFontFamily
                        font.pixelSize: 13
                        visible: passwordInput.text === "" && !passwordInput.activeFocus
                    }

                    Keys.onReturnPressed: {
                        if (text !== "")
                            doAuthenticate();
                    }
                    Keys.onEscapePressed: doCancel()
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottomMargin: 0
                height: 2
                radius: 1
                color: "#ff3b30"
                opacity: PolkitAgent.lastAuthFailed ? 1 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 200
                    }
                }
            }
        }

        Text {
            visible: PolkitAgent.lastAuthFailed
            text: "Incorrect password. Try again."
            color: "#ff3b30"
            font.family: root.textFontFamily
            font.pixelSize: 11
            opacity: PolkitAgent.lastAuthFailed ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                }
            }
        }

        Row {
            width: parent.width
            spacing: 8
            layoutDirection: Qt.RightToLeft

            Rectangle {
                width: 120
                height: 32
                radius: 10
                color: {
                    if (PolkitAgent.authenticating)
                        return Qt.rgba(1, 1, 1, 0.08);
                    return authMouse.pressed ? Qt.rgba(0.22, 0.52, 1, 0.9) : Qt.rgba(0.22, 0.52, 1, 0.75);
                }
                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        visible: PolkitAgent.authenticating
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\uf110"
                        font.family: root.iconFontFamily
                        font.pixelSize: 11
                        color: "white"
                        opacity: 0.7

                        RotationAnimation on rotation {
                            running: PolkitAgent.authenticating
                            from: 0
                            to: 360
                            duration: 1000
                            loops: Animation.Infinite
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: PolkitAgent.authenticating ? "Verifying…" : "Authenticate"
                        color: "white"
                        font.family: root.textFontFamily
                        font.pixelSize: 12
                        font.weight: Font.SemiBold
                    }
                }

                MouseArea {
                    id: authMouse
                    anchors.fill: parent
                    enabled: !PolkitAgent.authenticating
                    onClicked: doAuthenticate()
                }
            }

            Rectangle {
                width: 80
                height: 32
                radius: 10
                color: cancelMouse.pressed ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.07)
                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "Cancel"
                    color: Qt.rgba(1, 1, 1, 0.75)
                    font.family: root.textFontFamily
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }

                MouseArea {
                    id: cancelMouse
                    anchors.fill: parent
                    onClicked: doCancel()
                }
            }
        }
    }

    function doAuthenticate() {
        if (passwordInput.text === "")
            return;
        PolkitAgent.authenticate(passwordInput.text);
        passwordInput.text = "";
    }

    function doCancel() {
        passwordInput.text = "";
        PolkitAgent.cancel();
        root.closeRequested();
    }

    onShowConditionChanged: {
        if (showCondition) {
            passwordInput.text = "";
            passwordInput.forceActiveFocus();
        }
    }

    Connections {
        target: PolkitAgent
        function onLastAuthFailedChanged() {
            if (PolkitAgent.lastAuthFailed)
                shakeAnim.restart();
        }
        function onAuthCompleted(success) {
            if (success)
                root.closeRequested();
        }
    }
}
