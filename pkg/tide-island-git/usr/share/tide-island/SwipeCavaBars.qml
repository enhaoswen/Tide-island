import QtQuick

Item {
    id: root

    property var levels: [0, 0, 0, 0, 0, 0, 0, 0]
    property int barCount: Math.max(1, levels.length > 0 ? levels.length : 8)
    property real barWidth: 4
    property real barSpacing: 3
    property real minimumBarHeight: 4
    property color barColor: "white"

    implicitWidth: barCount * barWidth + Math.max(0, barCount - 1) * barSpacing
    implicitHeight: 18
    width: implicitWidth
    height: implicitHeight

    Row {
        anchors.fill: parent
        spacing: root.barSpacing

        Repeater {
            model: root.barCount

            delegate: Rectangle {
                readonly property real rawLevel: {
                    if (!Array.isArray(root.levels) || index >= root.levels.length) return 0;
                    return Number(root.levels[index]);
                }
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
