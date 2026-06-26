import QtQuick

Item {
    id: root

    property var levels: [0, 0, 0, 0, 0, 0, 0, 0]
    property int barCount: Math.max(1, levelCount() > 0 ? levelCount() : 8)
    property real barWidth: 4
    property real barSpacing: 3
    property real minimumBarHeight: 4
    property color barColor: "white"

    implicitWidth: barCount * barWidth + Math.max(0, barCount - 1) * barSpacing
    implicitHeight: 18

    function levelCount() {
        if (!levels)
            return 0;
        const count = Number(levels.length);
        return isFinite(count) && count > 0 ? Math.floor(count) : 0;
    }

    function levelAt(index) {
        if (!levels || index < 0 || index >= levelCount())
            return 0;
        return Number(levels[index]);
    }

    Row {
        anchors.fill: parent
        spacing: root.barSpacing

        Repeater {
            model: root.barCount

            delegate: Rectangle {
                readonly property real rawLevel: root.levelAt(index)
                readonly property real clampedLevel: Math.max(0, Math.min(1, isNaN(rawLevel) ? 0 : rawLevel))

                width: root.barWidth
                height: root.minimumBarHeight + (parent.height - root.minimumBarHeight) * clampedLevel
                radius: width / 2
                color: root.barColor
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
