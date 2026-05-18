import QtQuick

Item {
    id: root

    property var screen: null
    property bool showCondition: false
    property bool previewsEnabled: false
    property string textFontFamily: ""
    property string heroFontFamily: ""
    property string wallpaperPath: ""
    property real windowCornerRadius: 22

    property alias overviewView: overviewView
    property alias overviewDataReady: hyprlandData.ready

    signal closeRequested()

    anchors.fill: parent

    HyprlandData {
        id: hyprlandData
    }

    WorkspaceOverviewLayer {
        id: overviewView

        anchors.centerIn: parent
        screen: root.screen
        hyprlandData: hyprlandData
        showCondition: root.showCondition
        previewsEnabled: root.previewsEnabled
        textFontFamily: root.textFontFamily
        heroFontFamily: root.heroFontFamily
        wallpaperPath: root.wallpaperPath
        windowCornerRadius: root.windowCornerRadius
        onCloseRequested: root.closeRequested()
    }
}
