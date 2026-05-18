import QtQuick

Item {
    id: root

    visible: false
    width: 0
    height: 0

    property bool active: false
    property string wallpaperPath: ""
    property var hyprMonitor: null
    property var screenObject: null

    readonly property real wallpaperScale: 0.18
    readonly property real cacheScaleMultiplier: 1.75
    readonly property bool ready: cacheLoader.item
        ? (cacheLoader.item.cacheAvailable || !cacheLoader.item.busy)
        : false
    readonly property string effectiveSource: cacheLoader.item
        ? cacheLoader.item.effectiveSource
        : wallpaperPath
    readonly property int targetWidth: {
        const screenWidth = hyprMonitor ? hyprMonitor.width : (screenObject ? screenObject.width : 1920);
        const monitorScale = hyprMonitor && hyprMonitor.scale ? hyprMonitor.scale : 1;
        const workspaceWidth = Math.max(180, screenWidth * wallpaperScale / monitorScale);
        return Math.max(1, Math.round(workspaceWidth * cacheScaleMultiplier));
    }
    readonly property int targetHeight: {
        const screenHeight = hyprMonitor ? hyprMonitor.height : (screenObject ? screenObject.height : 1080);
        const monitorScale = hyprMonitor && hyprMonitor.scale ? hyprMonitor.scale : 1;
        const workspaceHeight = Math.max(120, screenHeight * wallpaperScale / monitorScale);
        return Math.max(1, Math.round(workspaceHeight * cacheScaleMultiplier));
    }

    property bool refreshPending: false
    property bool cacheBusy: false

    function prewarm() {
        refreshPending = true;
        keepAliveTimer.restart();

        if (cacheLoader.item) {
            cacheLoader.item.refreshNow();
            refreshPending = false;
        }
    }

    Timer {
        id: keepAliveTimer

        interval: 3000
        repeat: false
    }

    Loader {
        id: cacheLoader

        active: root.active || keepAliveTimer.running || root.cacheBusy
        asynchronous: false
        visible: false

        onLoaded: {
            if (root.refreshPending && item) {
                item.refreshNow();
                root.refreshPending = false;
            }
        }

        sourceComponent: Component {
            WallpaperThumbnailCache {
                sourcePath: root.wallpaperPath
                targetWidth: root.targetWidth
                targetHeight: root.targetHeight

                onBusyChanged: root.cacheBusy = busy
                Component.onCompleted: root.cacheBusy = busy
                Component.onDestruction: root.cacheBusy = false
            }
        }
    }
}
