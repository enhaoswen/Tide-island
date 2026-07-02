import QtQuick
import TideIsland 1.0

Rectangle {
    id: pagePanel
    color: "transparent"
    anchors.fill: parent

    default property alias content: pagePanel.data

    function showPage() {
        hideAnim.stop()
        showAnim.start()
    }

    function hidePage() {
        showAnim.stop()
        hideAnim.start()
    }

    SequentialAnimation {
        id: hideAnim

        NumberAnimation {
            target: pagePanel
            property: "opacity"
            to: 0
            duration: Theme.animationDuration
            easing.type: Easing.InOutQuad
        }

        ScriptAction {
            script: pagePanel.visible = false
        }
    }

    SequentialAnimation {
        id: showAnim

        ScriptAction {
            script: {
                pagePanel.visible = true
                pagePanel.opacity = 0
            }
        }

        NumberAnimation {
            target: pagePanel
            property: "opacity"
            to: 1
            duration: Theme.animationDuration
            easing.type: Easing.InOutQuad
        }
    }
}
