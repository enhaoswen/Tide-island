import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: root

    property string currentArtUrl: ""
    property string preloadedArtSource: ""
    property var cavaLevels: []
    property string iconFontFamily: ""
    property bool showCondition: true

    signal closeRequested

    readonly property string resolvedArtSource: preloadedArtSource !== "" ? preloadedArtSource : currentArtUrl

    readonly property real artSize: 28
    readonly property real artMarginLeft: 7
    readonly property real cavaMarginRight: 9
    readonly property int numBars: 6
    readonly property real bW: 2
    readonly property real bGap: 3
    readonly property real cavaW: numBars * bW + (numBars - 1) * bGap

    opacity: showCondition ? 1 : 0
    Behavior on opacity {
        NumberAnimation {
            duration: 200
            easing.type: Easing.InOutQuad
        }
    }

    function levelCount() {
        if (!cavaLevels)
            return 0;
        const n = Number(cavaLevels.length);
        return (isFinite(n) && n > 0) ? Math.floor(n) : 0;
    }
    function levelAt(i) {
        if (!cavaLevels || i < 0 || i >= levelCount())
            return 0;
        const v = Number(cavaLevels[i]);
        return isNaN(v) ? 0 : Math.max(0, Math.min(1, v));
    }

    Item {
        id: artWrapper
        x: root.artMarginLeft
        anchors.verticalCenter: parent.verticalCenter
        width: root.artSize
        height: root.artSize

        Rectangle {
            id: artMask
            anchors.fill: parent
            radius: 5
            visible: false
        }

        Image {
            id: artImage
            anchors.fill: parent
            source: root.resolvedArtSource
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: artMask
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: 5
            color: "#2a2a2a"
            visible: artImage.status !== Image.Ready
            Text {
                anchors.centerIn: parent
                text: "\uf001"
                font.family: root.iconFontFamily
                font.pixelSize: 13
                color: "#ffffff"
                opacity: 0.6
            }
        }
    }

    Row {
        id: cavaRow
        anchors {
            right: parent.right
            rightMargin: root.cavaMarginRight
            verticalCenter: parent.verticalCenter
        }
        width: root.cavaW
        height: root.artSize
        spacing: root.bGap

        Repeater {
            model: root.numBars

            delegate: Rectangle {
                readonly property real lvl: root.levelAt(index)

                width: root.bW
                height: Math.max(3, root.artSize * lvl)
                radius: width / 2
                color: "#ffffff"
                anchors.verticalCenter: parent.verticalCenter

                Behavior on height {
                    NumberAnimation {
                        duration: 90
                        easing.type: Easing.InOutQuad
                    }
                }
            }
        }
    }
}
