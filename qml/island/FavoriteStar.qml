import QtQuick

Item {
    id: root

    signal toggleRequested

    property bool active: false
    property bool hovered: false

    width: 20
    height: 20
    opacity: active ? 1 : (hovered ? 0.68 : 0)

    Image {
        id: starSource
        anchors.centerIn: parent
        width: 18
        height: 18
        source: Qt.resolvedUrl(root.active ? "assets/star-filled.svg" : "assets/star.svg")
        sourceSize: Qt.size(48, 48)
        smooth: true
        mipmap: true
        visible: true
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: root.toggleRequested()
    }
}
