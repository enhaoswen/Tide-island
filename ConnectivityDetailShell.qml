import QtQuick

Item {
    id: shell

    property bool open: false
    property bool mounted: false
    property bool rightSide: false
    property string panelKind: "wifi"
    property var provider: null
    property var mainCapsule: null
    property real availableWidth: 0
    property real detailWidth: 318
    property real detailHeight: 404
    property real detailGap: 16
    property string iconFontFamily: ""
    property string textFontFamily: ""
    property string heroFontFamily: ""

    property real revealProgress: 0

    readonly property real capsuleX: mainCapsule ? mainCapsule.x : 0
    readonly property real capsuleY: mainCapsule ? mainCapsule.y : 0
    readonly property real capsuleWidth: mainCapsule ? mainCapsule.width : 0
    readonly property real capsuleHeight: mainCapsule ? mainCapsule.height : 0
    readonly property real shownX: rightSide
        ? Math.min(availableWidth - width - 16, capsuleX + capsuleWidth + detailGap)
        : Math.max(16, capsuleX - width - detailGap)
    readonly property real hiddenX: rightSide
        ? capsuleX + capsuleWidth - width - 28
        : capsuleX + 28
    readonly property real hiddenY: capsuleY + 20
    readonly property real panelScale: revealProgress

    function startPanelAnimation(nextOpen) {
        revealAnimation.stop();

        if (nextOpen) {
            revealAnimation.to = 1;
            revealAnimation.duration = 420;
            revealAnimation.easing.type = Easing.OutBack;
            revealAnimation.easing.overshoot = 0.5;
            revealAnimation.start();
        } else {
            revealAnimation.to = 0;
            revealAnimation.duration = 180;
            revealAnimation.easing.type = Easing.InCubic;
            revealAnimation.start();
        }
    }

    x: hiddenX + (shownX - hiddenX) * revealProgress
    y: hiddenY + (capsuleY - hiddenY) * revealProgress
    width: detailWidth
    height: detailHeight
    opacity: revealProgress
    visible: mounted || opacity > 0.001
    z: 3

    onOpenChanged: startPanelAnimation(open)

    NumberAnimation {
        id: revealAnimation

        target: shell
        property: "revealProgress"
    }

    Component.onCompleted: revealProgress = open ? 1 : 0

    Item {
        id: panelBody

        anchors.fill: parent
        transform: Scale {
            origin.x: shell.rightSide ? 0 : panelBody.width
            origin.y: Math.min(panelBody.height - 32, Math.max(36, shell.capsuleHeight - 215))
            xScale: shell.panelScale
            yScale: shell.panelScale
        }

        Loader {
            anchors.fill: parent
            active: shell.mounted
            asynchronous: false
            visible: active

            sourceComponent: Component {
                ConnectivityDetailPanel {
                    provider: shell.provider
                    panelKind: shell.panelKind
                    iconFontFamily: shell.iconFontFamily
                    textFontFamily: shell.textFontFamily
                    heroFontFamily: shell.heroFontFamily
                    presentationProgress: shell.revealProgress
                }
            }
        }
    }
}
