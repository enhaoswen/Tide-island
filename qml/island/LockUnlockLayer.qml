import QtQuick

Item {
    id: root

    property string iconFontFamily: ""
    property string textFontFamily: ""
    property bool showCondition: false

    signal animationFinished

    property bool unlocked: false

    function playUnlock() {
        if (unlockSequence.running)
            return;
        root.unlocked = false;
        unlockSequence.restart();
    }

    opacity: 1
    Behavior on opacity {
        NumberAnimation {
            duration: 200
            easing.type: Easing.InOutQuad
        }
    }

    Text {
        id: lockIcon
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        text: root.unlocked ? "\uf2fc" : "\uF023"
        font.family: root.iconFontFamily
        font.pixelSize: 16
        color: "white"
        opacity: 0

        Component.onCompleted: {
            opacity = 1;
        }
        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }
    }

    SequentialAnimation {
        id: unlockSequence

        PauseAnimation {
            duration: 300
        }

        // Swap icon
        ScriptAction {
            script: root.unlocked = true
        }

        PauseAnimation {
            duration: 600
        }

        NumberAnimation {
            target: root
            property: "opacity"
            to: 0
            duration: 240
            easing.type: Easing.InQuad
        }

        onFinished: {
            root.unlocked = false;
            root.animationFinished();
        }
    }
}
