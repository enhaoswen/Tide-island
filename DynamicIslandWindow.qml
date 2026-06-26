import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import IslandBackend
import Quickshell.Io
import "qml/common"
import "qml/controlcenter"
import "qml/connectivity"
import "qml/island"
import "qml/workspace"

PanelWindow {
    id: root
    property var shellRootController: null
    readonly property alias islandContainerRef: islandContainer
    property string overviewPhase: "closed"
    property bool overviewPreloading: false
    readonly property bool overviewPreparing: overviewPhase === "preparing"
    readonly property bool overviewVisible: overviewPhase === "preparing" || overviewPhase === "opening" || overviewPhase === "open"
    readonly property bool overviewMounted: overviewPhase !== "closed" || overviewPreloading
    readonly property bool overviewLoaderActive: overviewMounted || overviewUnloadGraceTimer.running
    readonly property bool overviewDataReady: overviewLoader.item ? !!overviewLoader.item.overviewDataReady : false
    readonly property bool overviewWallpaperReady: overviewWallpaperCache.ready
    readonly property bool overviewVisualReady: overviewDataReady && overviewWallpaperReady
    readonly property bool overviewContentVisible: (overviewPhase === "opening" || overviewPhase === "open") && overviewVisualReady
    readonly property var hyprMonitor: screen ? Hyprland.monitorFor(screen) : Hyprland.focusedMonitor
    readonly property string hyprMonitorName: hyprMonitor && hyprMonitor.name ? String(hyprMonitor.name) : ""
    readonly property bool monitorFocused: hyprMonitor ? hyprMonitor.focused : false
    readonly property bool connectivityPromptActive: controlCenterLoader.item ? controlCenterLoader.item.hasConnectivityPrompt : false
    readonly property int currentMonitorWorkspaceId: hyprMonitor && hyprMonitor.activeWorkspace ? hyprMonitor.activeWorkspace.id : 1
    readonly property bool screenRecordingActive: shellRootController && shellRootController.screenRecordingActive !== undefined ? !!shellRootController.screenRecordingActive : false
    readonly property real aiTranslateWindowHeight: islandContainer.islandState === "ai_translate" ? 4 + 480 + 12 : 0

    readonly property var userConfig: UserConfig

    HyprlandDispatch {
        id: hyprDispatch
    }

    color: StyleTokens.transparent
    anchors {
        top: true
        left: true
        right: true
    }
    mask: Region {
        Region {
            x: 0
            y: 0
            width: root.width
            height: Math.ceil(root.topGestureInputHeight)
        }
        Region {
            intersection: Intersection.Combine
            x: Math.floor(mainCapsule.x)
            y: Math.floor(mainCapsule.y)
            width: Math.ceil(mainCapsule.width)
            height: Math.ceil(mainCapsule.height)
        }
        Region {
            intersection: Intersection.Combine
            x: Math.floor(wifiConnectivityDetailShell.x)
            y: Math.floor(wifiConnectivityDetailShell.y)
            width: wifiConnectivityDetailShell.visible ? Math.ceil(wifiConnectivityDetailShell.width) : 0
            height: wifiConnectivityDetailShell.visible ? Math.ceil(wifiConnectivityDetailShell.height) : 0
        }

        Region {
            intersection: Intersection.Combine
            x: Math.floor(bluetoothConnectivityDetailShell.x)
            y: Math.floor(bluetoothConnectivityDetailShell.y)
            width: bluetoothConnectivityDetailShell.visible ? Math.ceil(bluetoothConnectivityDetailShell.width) : 0
            height: bluetoothConnectivityDetailShell.visible ? Math.ceil(bluetoothConnectivityDetailShell.height) : 0
        }
    }
    implicitHeight: root.overviewVisible ? Math.max(Math.ceil(4 + root.connectivityDetailHeight + 12), Math.ceil(4 + root.overviewCapsuleHeight + 8), Math.ceil(root.controlCenterWindowHeight), Math.ceil(root.aiTranslateWindowHeight)) : Math.max(Math.ceil(4 + root.connectivityDetailHeight + 12), Math.ceil(root.controlCenterWindowHeight), Math.ceil(root.aiTranslateWindowHeight))
    exclusiveZone: 45
    aboveWindows: true
    focusable: islandContainer.appLauncherLayerVisible || islandContainer.polkitAuthLayerVisible || islandContainer.wallpaperPickerLayerVisible || islandContainer.clipboardHistoryLayerVisible || islandContainer.aiTranslateLayerVisible || (root.monitorFocused && (root.overviewVisible || root.connectivityPromptActive || islandContainer.powerMenuLayerVisible || (islandContainer.expandedLayerVisible && !islandContainer.expandedByPlayerAutoOpen)))
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: {
        if (islandContainer.wallpaperPickerLayerVisible || islandContainer.clipboardHistoryLayerVisible)
            return WlrKeyboardFocus.Exclusive;
        if (!root.monitorFocused)
            return WlrKeyboardFocus.None;
        if (islandContainer.appLauncherLayerVisible || islandContainer.powerMenuLayerVisible || islandContainer.aiTranslateLayerVisible || islandContainer.polkitAuthLayerVisible)
            return WlrKeyboardFocus.Exclusive;
        if (root.overviewVisible || root.connectivityPromptActive || (islandContainer.expandedLayerVisible && !islandContainer.expandedByPlayerAutoOpen))
            return WlrKeyboardFocus.OnDemand;
        return WlrKeyboardFocus.None;
    }

    readonly property string iconFontFamily: userConfig.iconFontFamily
    readonly property string textFontFamily: userConfig.textFontFamily
    readonly property string heroFontFamily: userConfig.heroFontFamily
    readonly property string timeFontFamily: userConfig.timeFontFamily
    readonly property string defaultSplitIcon: "\ud83c\udfa7"
    readonly property string notificationStatusIcon: "\uf0f3"
    readonly property real overviewWindowCornerRadius: 12
    readonly property int dynamicIslandAcceptedButtons: userConfig.mouseButtonsMask([1, userConfig.dynamicIslandPrimaryButton, userConfig.dynamicIslandSecondaryButton])
    readonly property bool topGestureInputActive: !root.overviewVisible && islandContainer.canShowSideSwipe
    readonly property real topGestureInputHeight: topGestureInputActive ? root.exclusiveZone : 0
    readonly property real overviewCapsuleWidth: islandContainer.overviewView ? islandContainer.overviewView.width : 760
    readonly property real overviewCapsuleHeight: islandContainer.overviewView ? islandContainer.overviewView.height : 308
    readonly property real overviewCapsuleRadius: islandContainer.overviewView ? islandContainer.overviewView.largeWorkspaceRadius + islandContainer.overviewView.outerPadding : 44
    readonly property color overviewCapsuleColor: islandContainer.overviewView ? islandContainer.overviewView.cardColor : StyleTokens.overviewCard
    readonly property color overviewCapsuleBorderColor: islandContainer.overviewView ? islandContainer.overviewView.cardBorderColor : StyleTokens.overviewBorder
    property bool wifiConnectivityDetailOpen: false
    property bool wifiConnectivityDetailMounted: false
    property bool bluetoothConnectivityDetailOpen: false
    property bool bluetoothConnectivityDetailMounted: false
    readonly property bool anyConnectivityDetailMounted: wifiConnectivityDetailMounted || bluetoothConnectivityDetailMounted
    readonly property real connectivityDetailWidth: 318
    readonly property real connectivityDetailHeight: 404
    readonly property real controlCenterMaximumExtraHeight: controlCenterLoader.item ? controlCenterLoader.item.controlCenterMaximumExtraHeight : 120
    readonly property real controlCenterWindowHeight: islandContainer.controlCenterLayerVisible ? 4 + 320 + root.controlCenterMaximumExtraHeight + 12 : 0
    readonly property real connectivityDetailGap: 16
    readonly property int connectivityDetailAnimationDuration: 360
    readonly property string overviewWallpaperSource: overviewWallpaperCache.effectiveSource

    function beginOverviewOpening() {
        if (!overviewPreparing)
            return;
        if (overviewLoader.status !== Loader.Ready || !overviewVisualReady)
            return;
        overviewPreloading = false;
        overviewPhase = "opening";
        overviewRevealTimer.restart();
    }

    function prepareOverview() {
        if (overviewPhase !== "closed")
            return;
        overviewUnloadGraceTimer.stop();
        overviewPreloading = true;
        overviewPreloadExpireTimer.restart();
    }

    function cancelPreparedOverview() {
        if (overviewPhase !== "closed")
            return;
        overviewPreloadExpireTimer.stop();
        overviewPreloading = false;
    }

    function openOverview() {
        if (overviewPhase !== "closed")
            return;
        overviewUnloadGraceTimer.stop();
        overviewPreloadExpireTimer.stop();
        overviewPreloading = true;
        overviewPhase = "preparing";
        if (overviewLoader.status === Loader.Ready) {
            beginOverviewOpening();
        }
    }

    function closeOverview() {
        if (!overviewMounted)
            return;
        if (overviewLoader.status === Loader.Ready)
            overviewUnloadGraceTimer.restart();
        overviewRevealTimer.stop();
        overviewPreloadExpireTimer.stop();
        islandContainer.restoreRestingCapsule(true);
        overviewPreloading = false;
        overviewPhase = "closed";
    }

    function closeOverviewEverywhere() {
        if (shellRootController && shellRootController.closeOverviewAll) {
            shellRootController.closeOverviewAll();
            return;
        }
        closeOverview();
    }

    function setConnectivityDetailVisible(kind, open) {
        const nextOpen = !!open;

        if (kind === "wifi") {
            if (nextOpen) {
                wifiConnectivityDetailCleanupTimer.stop();
                wifiConnectivityDetailMounted = true;
                wifiConnectivityDetailOpen = true;
            } else {
                if (!wifiConnectivityDetailMounted && !wifiConnectivityDetailOpen)
                    return;
                wifiConnectivityDetailOpen = false;
                wifiConnectivityDetailCleanupTimer.restart();
            }
            return;
        }

        if (kind === "bluetooth") {
            if (nextOpen) {
                bluetoothConnectivityDetailCleanupTimer.stop();
                bluetoothConnectivityDetailMounted = true;
                bluetoothConnectivityDetailOpen = true;
            } else {
                if (!bluetoothConnectivityDetailMounted && !bluetoothConnectivityDetailOpen)
                    return;
                bluetoothConnectivityDetailOpen = false;
                bluetoothConnectivityDetailCleanupTimer.restart();
            }
        }
    }

    function closeAllConnectivityDetails() {
        setConnectivityDetailVisible("wifi", false);
        setConnectivityDetailVisible("bluetooth", false);
    }

    function openOverviewEverywhere() {
        if (shellRootController && shellRootController.openOverviewAll) {
            shellRootController.openOverviewAll();
            return;
        }
        openOverview();
    }

    function prepareOverviewEverywhere() {
        if (shellRootController && shellRootController.prepareOverviewAll) {
            shellRootController.prepareOverviewAll();
            return;
        }
        prepareOverview();
    }

    function cancelPreparedOverviewEverywhere() {
        if (shellRootController && shellRootController.cancelPreparedOverviewAll) {
            shellRootController.cancelPreparedOverviewAll();
            return;
        }
        cancelPreparedOverview();
    }

    function toggleOverviewEverywhere() {
        if (shellRootController && shellRootController.toggleOverviewAll) {
            shellRootController.toggleOverviewAll();
            return;
        }
        if (overviewMounted)
            closeOverviewEverywhere();
        else
            openOverviewEverywhere();
    }

    function prewarmWallpaperCache() {
        overviewWallpaperCache.prewarm();
    }

    function showNotification(appName, summary, body) {
        islandContainer.showNotificationCapsule(appName, summary, body);
    }

    onOverviewVisibleChanged: {
        if (overviewVisible && monitorFocused)
            overviewFocusTimer.restart();
    }
    onConnectivityPromptActiveChanged: {
        if (connectivityPromptActive && monitorFocused)
            connectivityPromptFocusTimer.restart();
    }
    onOverviewVisualReadyChanged: {
        if (overviewVisualReady)
            beginOverviewOpening();
    }
    onMonitorFocusedChanged: {
        if (overviewVisible && monitorFocused)
            overviewFocusTimer.restart();
        if (connectivityPromptActive && monitorFocused)
            connectivityPromptFocusTimer.restart();
    }
    Timer {
        id: startupSuppressTimer
        interval: 2000
        repeat: false
        running: true
        onTriggered: islandContainer.startupSuppressTransients = false
    }

    Timer {
        id: overviewFocusTimer
        interval: 0
        repeat: false
        onTriggered: islandContainer.forceActiveFocus()
    }

    Timer {
        id: connectivityPromptFocusTimer
        interval: 0
        repeat: false
        onTriggered: islandContainer.forceActiveFocus()
    }

    Timer {
        id: overviewRevealTimer
        interval: 0
        repeat: false
        onTriggered: {
            if (root.overviewPhase === "opening")
                root.overviewPhase = "open";
        }
    }

    Timer {
        id: overviewPreloadExpireTimer
        interval: 1200
        repeat: false
        onTriggered: {
            if (root.overviewPhase === "closed")
                root.overviewPreloading = false;
        }
    }

    Timer {
        id: overviewUnloadGraceTimer
        interval: 260
        repeat: false
    }

    Timer {
        id: wifiConnectivityDetailCleanupTimer
        interval: root.connectivityDetailAnimationDuration
        repeat: false
        onTriggered: root.wifiConnectivityDetailMounted = false
    }

    Timer {
        id: bluetoothConnectivityDetailCleanupTimer
        interval: root.connectivityDetailAnimationDuration
        repeat: false
        onTriggered: root.bluetoothConnectivityDetailMounted = false
    }

    OverviewWallpaperCacheController {
        id: overviewWallpaperCache

        active: root.overviewLoaderActive
        wallpaperPath: userConfig.wallpaperPath
        hyprMonitor: root.hyprMonitor
        screenObject: root.screen
    }

    IslandClock {
        id: timeObj
    }

    TextMetrics {
        id: osdTextMetrics
        font.family: root.textFontFamily
        font.pixelSize: 16
        font.weight: Font.DemiBold
        text: islandContainer.osdCustomText
    }

    FocusScope {
        id: islandContainer
        anchors.fill: parent
        focus: root.monitorFocused && (root.overviewVisible || root.connectivityPromptActive || islandContainer.appLauncherLayerVisible || islandContainer.powerMenuLayerVisible)

        property real lockUnlockCapsuleWidth: 170
        property bool lockUnlockResetting: false
        property bool skipWidthAnimation: false
        property string islandState: "lock_unlock"
        property bool startupSuppressTransients: true
        property string splitIcon: root.defaultSplitIcon
        property real osdProgress: -1.0
        property bool osdProgressAnimationEnabled: true
        property string osdCustomText: ""
        property int currentWs: root.currentMonitorWorkspaceId > 0 ? root.currentMonitorWorkspaceId : 1
        property bool playerProgressDragging: false
        readonly property var controlCenterRef: controlCenterLoader.item

        readonly property int batteryCapacity: systemState.batteryCapacity
        readonly property bool isCharging: systemState.isCharging
        readonly property real currentVolume: systemState.currentVolume
        readonly property bool isMuted: systemState.isMuted
        readonly property real currentBrightness: systemState.currentBrightness
        readonly property real currentCpuUsage: systemState.currentCpuUsage
        readonly property real currentRamUsage: systemState.currentRamUsage
        property string notificationAppName: ""
        property string notificationSummary: ""
        property string notificationBody: ""
        property string notificationImagePath: ""
        property var bluetoothExpandedDevice: null
        readonly property var cavaLevels: systemState.cavaLevels
        property real swipeTransitionProgress: 0
        property string workspaceOriginSide: "none"
        property string splitOriginSide: "none"
        property string restingState: "normal"
        property bool expandedByPlayerAutoOpen: false
        property string alcoveReturnState: "normal"
        property string workspaceReturnState: ""
        property string preloadedArtUrl: ""
        property bool preloadedArtReady: false
        property string lastArtUrl: ""
        property real customCapsuleWidth: 220
        property real lyricsCapsuleWidth: 220
        property bool sideSwipeSettling: false
        readonly property int defaultAutoHideInterval: 1250
        readonly property int notificationAutoHideInterval: 86400000
        readonly property int bluetoothExpandedAutoHideInterval: 2500
        readonly property int swipeAnimationDuration: 220

        readonly property bool blocksTransientSplit: islandState === "expanded" || islandState === "alcove_music" || islandState === "bluetooth_expanded" || islandState === "control_center" || islandState === "notification" || islandState === "power_menu" || islandState === "app_launcher" || islandState === "wallpaper_picker" || islandState === "clipboard_history" || islandState === "lock_unlock" || islandState === "ai_translate" || islandState === "polkit_auth"

        readonly property bool splitShowsProgress: islandState === "split" && osdProgress >= 0
        readonly property bool splitShowsText: islandState === "split" && osdProgress < 0 && osdCustomText !== ""
        readonly property bool splitShowsIconOnly: islandState === "split" && osdProgress < 0 && osdCustomText === ""
        readonly property bool splitUsesExtendedLayout: splitShowsProgress || splitShowsText
        readonly property real splitCapsuleWidth: splitShowsProgress ? 248 : (splitShowsText ? Math.max(220, Math.min(480, osdTextMetrics.advanceWidth + 84)) : 140)
        readonly property bool canShowSideSwipe: islandState === "normal" || islandState === "custom" || islandState === "lyrics" || (islandState === "long_capsule" && workspaceOriginSide === "none")
        readonly property real rightSwipeProgress: Math.max(0, swipeTransitionProgress)
        readonly property var customLeftItems: systemState.customLeftItems
        readonly property bool hasCustomLeftItems: systemState.hasCustomLeftItems
        readonly property bool customSwipeVisible: !root.overviewVisible && hasCustomLeftItems && (capsuleMouseArea.sideSwipeInteractive ? swipeTransitionProgress < 0 : (islandState === "custom" || (islandState === "normal" && swipeTransitionProgress < 0) || (islandState === "split" && splitOriginSide === "left") || (islandState === "long_capsule" && (workspaceOriginSide === "left" || swipeTransitionProgress < 0))))
        readonly property bool lyricsSwipeVisible: !root.overviewVisible && (capsuleMouseArea.sideSwipeInteractive ? swipeTransitionProgress >= 0 : (islandState === "lyrics" || (islandState === "normal" && swipeTransitionProgress >= 0) || (islandState === "split" && splitOriginSide === "right") || (islandState === "long_capsule" && (workspaceOriginSide === "right" || swipeTransitionProgress > 0))))
        readonly property bool expandedLayerVisible: !root.overviewVisible && islandState === "expanded"
        readonly property bool alcoveMusicLayerVisible: !root.overviewVisible && islandState === "alcove_music"
        readonly property bool bluetoothExpandedLayerVisible: !root.overviewVisible && islandState === "bluetooth_expanded"
        readonly property bool notificationLayerVisible: !root.overviewVisible && islandState === "notification"
        readonly property bool controlCenterLayerVisible: !root.overviewVisible && islandState === "control_center"
        readonly property bool powerMenuLayerVisible: !root.overviewVisible && islandState === "power_menu"
        readonly property bool appLauncherLayerVisible: !root.overviewVisible && islandState === "app_launcher"
        readonly property var activePlayer: mediaController.activePlayer
        readonly property string lyricsDisplayText: mediaController.displayText
        readonly property string currentTrack: mediaController.currentTrack
        readonly property string currentArtist: mediaController.currentArtist
        readonly property string currentArtUrl: mediaController.currentArtUrl
        readonly property real trackProgress: mediaController.trackProgress
        readonly property string timePlayed: mediaController.timePlayed
        readonly property string timeTotal: mediaController.timeTotal
        readonly property bool screenRecordingActive: root.screenRecordingActive
        readonly property bool wallpaperPickerLayerVisible: !root.overviewVisible && islandState === "wallpaper_picker"
        readonly property bool clipboardHistoryLayerVisible: !root.overviewVisible && islandState === "clipboard_history"
        readonly property bool aiTranslateLayerVisible: !root.overviewVisible && islandState === "ai_translate"

        readonly property bool polkitAuthLayerVisible: !root.overviewVisible && islandState === "polkit_auth"

        readonly property bool lockUnlockLayerVisible: !root.overviewVisible && islandState === "lock_unlock"

        readonly property var bluetoothDevices: bluetoothConnectionTracker.devices
        readonly property var overviewView: overviewLoader.item && overviewLoader.item.overviewView ? overviewLoader.item.overviewView : null

        onControlCenterLayerVisibleChanged: {
            if (!controlCenterLayerVisible) {
                if (controlCenterLoader.item)
                    controlCenterLoader.item.closeConnectivityPanels();
                else
                    root.closeAllConnectivityDetails();
            }
        }
        onIslandStateChanged: {
            if (islandState !== "lock_unlock" && (lockUnlockResetting || skipWidthAnimation)) {
                lockUnlockResetTimer.stop();
                lockUnlockResetting = false;
                skipWidthAnimation = false;
            }
        }

        onCustomLeftItemsChanged: {
            if (restingState === "custom" && !hasCustomLeftItems) {
                restingState = "normal";
                if (islandState === "custom" || (islandState === "split" && splitOriginSide === "left") || (islandState === "long_capsule" && workspaceOriginSide === "left")) {
                    restoreRestingCapsule(true);
                } else {
                    applyRestingVisuals();
                }
            } else if (restingState === "custom") {
                syncCustomCapsuleWidth();
            }
        }

        IslandMprisController {
            id: mediaController
            expanded: islandContainer.islandState === "expanded"
        }

        Image {
            id: artPreloader
            visible: false
            asynchronous: false
            cache: true
            sourceSize: Qt.size(192, 192)
            onStatusChanged: {
                if (status === Image.Ready) {
                    islandContainer.preloadedArtReady = true;
                }
            }
        }

        BluetoothConnectionTracker {
            id: bluetoothConnectionTracker
            onAdapterChanged: islandContainer.bluetoothExpandedDevice = null
            onNewConnection: function (device) {
                islandContainer.showBluetoothExpanded(device);
            }
        }

        IslandSystemState {
            id: systemState
            configuredLeftSwipeItems: userConfig.dynamicIslandLeftSwipeItems
            timeText: timeObj.currentTime
            dateText: timeObj.currentDateLabel
            currentWorkspace: islandContainer.currentWs
            customSwipeActive: customSwipeLoader.active
            musicActive: islandContainer.alcoveMusicLayerVisible
        }

        Connections {
            target: systemState
            function onTransientRequested(icon, progress, text) {
                islandContainer.showTransientCapsule(icon, progress, text);
            }
            function onCriticalBatteryRequested(icon, progress, text) {
                islandContainer.showCriticalBatteryNotification(icon, progress, text);
            }
        }
        Connections {
            target: PolkitAgent
            function onAuthRequested() {
                if (root.overviewVisible)
                    return;
                islandContainer.showPolkitAuth();
            }
            function onAuthCompleted(success) {
                islandContainer.smartRestoreState();
            }
            function onActiveChanged() {
                if (!PolkitAgent.active && islandContainer.islandState === "polkit_auth")
                    islandContainer.smartRestoreState();
            }
        }

        HyprlandWorkspaceTracker {
            id: workspaceTracker
            hyprMonitor: root.hyprMonitor
            monitorName: root.hyprMonitorName
            monitorFocused: root.monitorFocused
            onWorkspaceSynced: function (workspaceId) {
                islandContainer.currentWs = workspaceId;
            }
            onWorkspaceActivated: function (workspaceId) {
                islandContainer.showWorkspaceCapsule(workspaceId);
            }
        }

        Behavior on osdProgress {
            enabled: islandContainer.osdProgressAnimationEnabled
            SmoothedAnimation {
                velocity: 1.2
                duration: 180
                easing.type: Easing.InOutQuad
            }
        }
        Behavior on lockUnlockCapsuleWidth {
            enabled: islandState === "lock_unlock"
            NumberAnimation {
                duration: 350
                easing.type: Easing.OutBack
            }
        }
        Behavior on swipeTransitionProgress {
            NumberAnimation {
                duration: capsuleMouseArea.sideSwipeInteractive ? 0 : islandContainer.swipeAnimationDuration
                easing.type: Easing.OutCubic
            }
        }

        Keys.onPressed: event => {
            if (islandContainer.powerMenuLayerVisible) {
                if (event.key === Qt.Key_Escape) {
                    islandContainer.smartRestoreState();
                    event.accepted = true;
                }
                return;
            }
            if (!root.overviewVisible)
                return;
        }

        function handleConfiguredClickAction(actionName) {
            switch (actionName) {
            case "":
            case "none":
                return;
            case "toggleExpandedPlayer":
                if (islandState === "expanded") {
                    autoHideTimer.stop();
                    smartRestoreState();
                } else {
                    showExpandedPlayer(false);
                }
                return;
            case "toggleAlcoveMusicCapsule":
                if (islandState === "alcove_music")
                    smartRestoreState();
                else
                    showAlcoveMusicCapsule();
                return;
            case "openExpandedPlayer":
                showExpandedPlayer(false);
                return;
            case "closeExpandedPlayer":
                if (islandState === "expanded")
                    smartRestoreState();
                return;
            case "toggleControlCenter":
                if (islandState === "control_center")
                    smartRestoreState();
                else
                    showControlCenter();
                return;
            case "openControlCenter":
                showControlCenter();
                return;
            case "closeControlCenter":
                if (islandState === "control_center")
                    smartRestoreState();
                return;
            case "toggleOverview":
                root.toggleOverviewEverywhere();
                return;
            case "openOverview":
                root.openOverviewEverywhere();
                return;
            case "closeOverview":
                root.closeOverviewEverywhere();
                return;
            case "toggleLyrics":
                if (restingState === "lyrics")
                    showTimeCapsule();
                else
                    showLyricsCapsule();
                return;
            case "showLyrics":
                showLyricsCapsule();
                return;
            case "showTime":
                showTimeCapsule();
                return;
            case "restoreRestingCapsule":
                smartRestoreState();
                return;
            case "togglePowerMenu":
                if (islandState === "power_menu")
                    smartRestoreState();
                else
                    showPowerMenu();
                return;
            default:
            }
        }

        function clamp01(value) {
            return Math.max(0, Math.min(1, value));
        }

        function normalizeRestingState(nextState) {
            if (nextState === "lyrics")
                return "lyrics";
            if (nextState === "custom" && hasCustomLeftItems)
                return "custom";
            return "normal";
        }

        function restingStateProgress(nextState) {
            switch (normalizeRestingState(nextState)) {
            case "custom":
                return -1;
            case "lyrics":
                return 1;
            default:
                return 0;
            }
        }

        function restingStateSide(nextState) {
            switch (normalizeRestingState(nextState)) {
            case "custom":
                return "left";
            case "lyrics":
                return "right";
            default:
                return "none";
            }
        }

        function swipeRestProgressForState() {
            switch (islandState) {
            case "custom":
                return -1;
            case "lyrics":
                return 1;
            default:
                return 0;
            }
        }

        function currentTransientOriginSide() {
            switch (islandState) {
            case "custom":
                return "left";
            case "lyrics":
                return "right";
            case "long_capsule":
                return workspaceOriginSide;
            case "split":
                return splitOriginSide;
            default:
                return "none";
            }
        }

        function showCriticalBatteryNotification(icon, progress, text) {
            if (root.overviewVisible)
                return;
            if (islandState === "notification" && notificationAppName === "Battery") {
                notificationSummary = text;
                return;
            }
            abortSideTransientMode();
            clearTransientCapsule();
            notificationAppName = "Battery";
            notificationSummary = text;
            notificationBody = "";
            islandState = "notification";
            stopAutoHideTimer();
        }

        function toggleAlcoveMusicCapsule() {
            if (islandState === "alcove_music")
                smartRestoreState();
            else
                showAlcoveMusicCapsule();
        }

        function showAlcoveMusicCapsule() {
            cancelSideSwipeSettle();
            abortSideTransientMode();
            clearTransientCapsule();
            if (islandState !== "alcove_music")
                alcoveReturnState = islandState === "expanded" ? "expanded" : normalizeRestingState(restingState);
            islandState = "alcove_music";
            mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
            stopAutoHideTimer();
        }

        function restoreAlcoveMusicCapsule() {
            const returnState = alcoveReturnState === "alcove_music" ? "normal" : alcoveReturnState;
            if (returnState === "expanded") {
                showExpandedPlayer(expandedByPlayerAutoOpen);
                return;
            }
            showRestingCapsule(returnState);
        }

        function setOsdProgress(nextProgress, animate) {
            osdProgressAnimationReset.stop();
            osdProgressAnimationEnabled = animate;
            osdProgress = nextProgress;
            if (!animate)
                osdProgressAnimationReset.restart();
        }

        function abortSideTransientMode() {
            sideTransientRestoreTimer.stop();
            workspaceOriginSide = "none";
            splitOriginSide = "none";
        }

        function clearTransientCapsule() {
            setOsdProgress(-1.0, false);
            osdCustomText = "";
            notificationAppName = "";
            notificationSummary = "";
            notificationBody = "";
            bluetoothExpandedDevice = null;
        }

        function cleanNotificationText(text) {
            return String(text === undefined || text === null ? "" : text).replace(/<[^>]*>/g, " ").replace(/&nbsp;/g, " ").replace(/&amp;/g, "&").replace(/&quot;/g, "\"").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/\s+/g, " ").trim();
        }

        function prepareRestingCapsuleGeometry() {
            if (restingState === "custom")
                syncCustomCapsuleWidth();
            if (restingState === "lyrics")
                syncLyricsCapsuleWidth();
        }

        function applyRestingVisuals() {
            prepareRestingCapsuleGeometry();
            swipeTransitionProgress = restingStateProgress(restingState);
        }

        function sideSwipeRestProgressForProgress(progressValue) {
            if (progressValue <= -0.5)
                return -1;
            if (progressValue >= 0.5)
                return 1;
            return 0;
        }

        function sideSwipeRestWidthForProgress(progressValue) {
            if (progressValue <= -0.5)
                return customCapsuleWidth;
            if (progressValue >= 0.5)
                return lyricsCapsuleWidth;
            return 140;
        }

        function customSideSwipeDragDistance() {
            const view = customSwipeLoader.item;
            if (view && view.dragDistance > 0)
                return view.dragDistance;
            return Math.max(140, customCapsuleWidth + 4);
        }

        function lyricsSideSwipeDragDistance() {
            const view = lyricsSwipeLoader.item;
            if (view && view.dragDistance > 0)
                return view.dragDistance;
            return Math.max(140, lyricsCapsuleWidth + 2);
        }

        function sideSwipeDragDistanceForDirection(direction) {
            if (direction === "left")
                return customSideSwipeDragDistance();
            if (direction === "right")
                return lyricsSideSwipeDragDistance();
            return 140;
        }

        function advanceSideSwipeProgress(currentProgress, deltaX) {
            const minProgress = hasCustomLeftItems ? -1 : 0;
            let nextProgress = Math.max(minProgress, Math.min(1, currentProgress));
            let remainingDelta = deltaX;

            if (remainingDelta > 0) {
                if (nextProgress < 0) {
                    const leftDistance = Math.max(1, sideSwipeDragDistanceForDirection("left"));
                    const progressToCenter = Math.min(-nextProgress, remainingDelta / leftDistance);
                    nextProgress += progressToCenter;
                    remainingDelta -= progressToCenter * leftDistance;
                }
                if (remainingDelta > 0 && nextProgress < 1) {
                    const rightDistance = Math.max(1, sideSwipeDragDistanceForDirection("right"));
                    nextProgress = Math.min(1, nextProgress + remainingDelta / rightDistance);
                }
            } else if (remainingDelta < 0) {
                if (nextProgress > 0) {
                    const rightDistance = Math.max(1, sideSwipeDragDistanceForDirection("right"));
                    const progressToCenter = Math.min(nextProgress, -remainingDelta / rightDistance);
                    nextProgress -= progressToCenter;
                    remainingDelta += progressToCenter * rightDistance;
                }
                if (remainingDelta < 0 && nextProgress > minProgress) {
                    const leftDistance = Math.max(1, sideSwipeDragDistanceForDirection("left"));
                    nextProgress = Math.max(minProgress, nextProgress + remainingDelta / leftDistance);
                }
            }

            return Math.max(minProgress, Math.min(1, nextProgress));
        }

        function resolveSideSwipeSettle(startProgress, finalProgress) {
            let settleAction = "";
            let settleProgress = sideSwipeRestProgressForProgress(startProgress);
            let settleWidth = sideSwipeRestWidthForProgress(startProgress);

            if (finalProgress >= 0.56) {
                settleAction = "lyrics";
                settleProgress = 1;
                settleWidth = lyricsCapsuleWidth;
            } else if (hasCustomLeftItems && finalProgress <= -0.56) {
                settleAction = "custom";
                settleProgress = -1;
                settleWidth = customCapsuleWidth;
            } else if (startProgress <= -0.5) {
                if (finalProgress >= -0.44) {
                    settleAction = "time";
                    settleProgress = 0;
                    settleWidth = 140;
                }
            } else if (startProgress >= 0.5) {
                if (finalProgress <= 0.44) {
                    settleAction = "time";
                    settleProgress = 0;
                    settleWidth = 140;
                }
            } else {
                settleAction = "time";
                settleProgress = 0;
                settleWidth = 140;
            }

            return {
                action: settleAction,
                progress: settleProgress,
                width: settleWidth
            };
        }

        function beginSideSwipeSettle(targetWidth) {
            sideSwipeSettling = true;
            mainCapsule.displayedWidth = targetWidth;
            sideSwipeSettleReset.restart();
        }

        function cancelSideSwipeSettle() {
            sideSwipeSettleReset.stop();
            sideSwipeSettling = false;
        }

        function finishSideSwipeSettle() {
            sideSwipeSettling = false;
            mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
        }

        function restartAutoHideTimer(duration) {
            autoHideTimer.interval = duration === undefined ? defaultAutoHideInterval : duration;
            autoHideTimer.restart();
        }

        function stopAutoHideTimer() {
            autoHideTimer.stop();
            autoHideTimer.interval = defaultAutoHideInterval;
        }

        function showTransientCapsule(icon, progress, customText) {
            if (startupSuppressTransients)
                return;
            const nextProgress = progress >= 0 ? progress : -1.0;
            const animateProgress = islandState === "split" && osdProgress >= 0 && nextProgress >= 0;
            const animateFromSide = currentTransientOriginSide();
            abortSideTransientMode();
            splitIcon = icon;
            osdCustomText = customText;
            setOsdProgress(nextProgress, animateProgress);
            splitOriginSide = animateFromSide;
            islandState = "split";
            swipeTransitionProgress = 0;
            restartAutoHideTimer();
        }

        function showNotificationCapsule(appName, summary, body) {
            if (root.overviewVisible || islandState === "control_center" || islandState === "expanded")
                return;

            function extractBody(raw) {
                if (!raw)
                    return "";
                const parts = raw.split("\n\n");
                if (parts.length >= 2) {
                    const extracted = parts.slice(1).join(" ").trim();
                    return extracted;
                }
                return raw;
            }

            const cleanedAppName = cleanNotificationText(appName);
            const cleanedSummary = cleanNotificationText(summary);
            const rawBodyExtracted = extractBody(body);
            const cleanedBody = cleanNotificationText(rawBodyExtracted);
            console.log("=== NOTIF DEBUG ===");
            console.log("appName:", appName);
            console.log("summary:", summary);
            console.log("body RAW:", JSON.stringify(body));
            console.log("rawBodyExtracted:", JSON.stringify(rawBodyExtracted));
            console.log("cleanedBody:", JSON.stringify(cleanedBody));
            console.log("cleanedSummary:", JSON.stringify(cleanedSummary));
            const name = cleanedAppName.toLowerCase();
            if (name.includes("brave") || name.includes("chromium") || name.includes("chrome")) {
                notificationImagePath = "/usr/share/icons/hicolor/128x128/apps/brave-desktop.png";
            } else if (name.includes("firefox")) {
                notificationImagePath = "/usr/share/icons/hicolor/128x128/apps/firefox.png";
            } else if (name.includes("telegram")) {
                notificationImagePath = "/usr/share/icons/hicolor/128x128/apps/telegram.png";
            } else {
                notificationImagePath = "";
            }
            const resolvedSummary = cleanedSummary !== "" ? cleanedSummary : (cleanedBody !== "" ? cleanedBody : "New notification");
            if (controlCenterLoader.item)
                controlCenterLoader.item.appendNotification(cleanedAppName !== "" ? cleanedAppName : "Notification", resolvedSummary, cleanedSummary !== "" ? cleanedBody : "");
            abortSideTransientMode();
            clearTransientCapsule();
            notificationAppName = cleanedAppName !== "" ? cleanedAppName : "Notification";
            notificationSummary = resolvedSummary;
            notificationBody = cleanedSummary !== "" ? cleanedBody : "";
            islandState = "notification";
            const isPomodoro = cleanedAppName.toLowerCase().includes("pomodoro");
            restartAutoHideTimer(isPomodoro ? notificationAutoHideInterval : defaultAutoHideInterval);
        }

        function suppressCapsuleClick() {
            capsuleMouseArea.suppressNextClick = true;
            swipeSuppressReset.restart();
        }

        function restoreRestingCapsule(forceImmediate) {
            if (forceImmediate === undefined)
                forceImmediate = false;

            const normalizedRestingState = normalizeRestingState(restingState);
            const targetSide = restingStateSide(normalizedRestingState);
            const shouldAnimateToSide = targetSide !== "none" && ((islandState === "long_capsule" && workspaceOriginSide === targetSide) || (islandState === "split" && splitOriginSide === targetSide));

            if (!forceImmediate && shouldAnimateToSide) {
                expandedByPlayerAutoOpen = false;
                prepareRestingCapsuleGeometry();
                swipeTransitionProgress = restingStateProgress(normalizedRestingState);
                stopAutoHideTimer();
                sideTransientRestoreTimer.restart();
                return;
            }

            abortSideTransientMode();
            prepareRestingCapsuleGeometry();
            islandState = normalizedRestingState;
            clearTransientCapsule();
            applyRestingVisuals();
            expandedByPlayerAutoOpen = false;
            stopAutoHideTimer();
        }

        function setRestingState(nextState) {
            restingState = normalizeRestingState(nextState);
        }

        function smartRestoreState() {
            if (islandState === "alcove_music") {
                restoreAlcoveMusicCapsule();
                return;
            }
            if (islandState === "long_capsule" && workspaceReturnState !== "") {
                const target = workspaceReturnState;
                workspaceReturnState = "";
                if (target === "expanded") {
                    showExpandedPlayer(expandedByPlayerAutoOpen);
                } else {
                    showAlcoveMusicCapsule();
                }
                return;
            }
            restoreRestingCapsule();
        }

        function showRestingCapsule(nextState) {
            setRestingState(nextState);
            restoreRestingCapsule();
            stopAutoHideTimer();
        }

        function showExpandedPlayer(autoOpened) {
            cancelSideSwipeSettle();
            abortSideTransientMode();
            clearTransientCapsule();
            islandState = "expanded";
            mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
            expandedByPlayerAutoOpen = autoOpened;
            if (autoOpened)
                restartAutoHideTimer();
            else
                stopAutoHideTimer();
        }

        function showBluetoothExpanded(device) {
            if (!device || root.overviewVisible || islandState === "control_center" || islandState === "notification")
                return;
            cancelSideSwipeSettle();
            abortSideTransientMode();
            clearTransientCapsule();
            bluetoothExpandedDevice = device;
            islandState = "bluetooth_expanded";
            mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
            expandedByPlayerAutoOpen = false;
            restartAutoHideTimer(bluetoothExpandedAutoHideInterval);
        }

        function showPowerMenu() {
            cancelSideSwipeSettle();
            abortSideTransientMode();
            clearTransientCapsule();
            islandState = "power_menu";
            mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
            stopAutoHideTimer();
        }

        function showControlCenter() {
            cancelSideSwipeSettle();
            abortSideTransientMode();
            clearTransientCapsule();
            islandState = "control_center";
            mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
            stopAutoHideTimer();
        }

        function showAppLauncher() {
            cancelSideSwipeSettle();
            abortSideTransientMode();
            clearTransientCapsule();
            islandState = "app_launcher";
            mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
            stopAutoHideTimer();
        }

        function showWallpaperPicker() {
            cancelSideSwipeSettle();
            abortSideTransientMode();
            clearTransientCapsule();
            islandState = "wallpaper_picker";
            mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
            stopAutoHideTimer();
        }

        function showClipboardHistory() {
            cancelSideSwipeSettle();
            abortSideTransientMode();
            clearTransientCapsule();
            islandState = "clipboard_history";
            mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
            stopAutoHideTimer();
        }
        function showAiTranslate() {
            cancelSideSwipeSettle();
            abortSideTransientMode();
            clearTransientCapsule();
            islandState = "ai_translate";
            mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
            stopAutoHideTimer();
        }
        function showPolkitAuth() {
            cancelSideSwipeSettle();
            abortSideTransientMode();
            clearTransientCapsule();
            islandState = "polkit_auth";
            mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
            stopAutoHideTimer();
        }

        function showLockUnlock() {
            cancelSideSwipeSettle();
            abortSideTransientMode();
            clearTransientCapsule();
            lockUnlockResetting = false;
            skipWidthAnimation = true;
            islandState = "lock_unlock";
            mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
            stopAutoHideTimer();
            Qt.callLater(function () {
                islandContainer.skipWidthAnimation = false;
            });
        }

        function resetLockUnlockCapsule() {
            if (lockUnlockResetting)
                return;
            lockUnlockResetting = true;
            skipWidthAnimation = true;
            lockUnlockCapsuleWidth = 170;
            lockUnlockResetTimer.restart();
        }

        Timer {
            id: lockUnlockResetTimer
            interval: 10
            repeat: false
            onTriggered: {
                islandContainer.lockUnlockResetting = false;
                islandContainer.smartRestoreState();
                Qt.callLater(function () {
                    islandContainer.skipWidthAnimation = false;
                });
            }
        }
        function showCustomCapsule() {
            if (!hasCustomLeftItems) {
                showTimeCapsule();
                return;
            }
            systemState.refreshMissingValues();
            showRestingCapsule("custom");
        }

        function showLyricsCapsule() {
            showRestingCapsule("lyrics");
        }

        function showTimeCapsule() {
            showRestingCapsule("normal");
        }

        function showWorkspaceCapsule(wsId) {
            currentWs = wsId;
            if (islandState === "control_center" || islandState === "notification")
                return;
            if (islandState === "alcove_music" || islandState === "expanded") {
                workspaceReturnState = islandState;
            } else if (islandState !== "long_capsule") {
                workspaceReturnState = "";
            }
            const animateFromSide = currentTransientOriginSide();
            clearTransientCapsule();
            sideTransientRestoreTimer.stop();
            workspaceOriginSide = animateFromSide;
            splitOriginSide = "none";
            islandState = "long_capsule";
            swipeTransitionProgress = 0;
            restartAutoHideTimer();
        }

        Timer {
            id: autoHideTimer
            interval: islandContainer.defaultAutoHideInterval
            onTriggered: islandContainer.smartRestoreState()
        }
        Timer {
            id: osdProgressAnimationReset
            interval: 0
            onTriggered: islandContainer.osdProgressAnimationEnabled = true
        }
        Timer {
            id: sideTransientRestoreTimer
            interval: islandContainer.swipeAnimationDuration
            onTriggered: {
                islandContainer.workspaceOriginSide = "none";
                islandContainer.splitOriginSide = "none";
                islandContainer.prepareRestingCapsuleGeometry();
                islandContainer.islandState = islandContainer.normalizeRestingState(islandContainer.restingState);
                islandContainer.clearTransientCapsule();
                islandContainer.applyRestingVisuals();
                islandContainer.expandedByPlayerAutoOpen = false;
            }
        }
        Timer {
            id: sideSwipeSettleReset
            interval: mainCapsule.morphDuration
            onTriggered: islandContainer.finishSideSwipeSettle()
        }

        function syncCustomCapsuleWidth() {
            const view = customSwipeLoader.item;
            if (!view)
                return;
            customCapsuleWidth = Math.max(220, Math.min(root.width - 48, view.preferredWidth));
        }

        function syncLyricsCapsuleWidth() {
            const view = lyricsSwipeLoader.item;
            if (!view)
                return;
            lyricsCapsuleWidth = Math.max(220, Math.min(root.width - 48, view.preferredWidth));
        }

        onCurrentTrackChanged: {
            if (userConfig.disableAutoExpandOnTrackChange)
                return;
            if (currentTrack !== "" && islandState !== "control_center" && islandState !== "notification" && islandState !== "bluetooth_expanded" && islandState !== "lock_unlock") {
                if (islandState === "expanded" && !expandedByPlayerAutoOpen)
                    return;
                if (islandState === "alcove_music")
                    return;
                showExpandedPlayer(true);
            }
        }
        onCurrentArtUrlChanged: {
            if (currentArtUrl !== "" && currentArtUrl !== islandContainer.lastArtUrl) {
                islandContainer.lastArtUrl = currentArtUrl;
                islandContainer.preloadedArtReady = false;
                artPreloader.source = currentArtUrl;
            }
        }

        Rectangle {
            id: mainCapsule
            z: 5
            property int morphDuration: 400
            property real outlineWidth: root.overviewContentVisible ? 1 : 0
            property color outlineColor: root.overviewContentVisible ? root.overviewCapsuleBorderColor : StyleTokens.clearBlack
            property real displayedWidth: baseTargetWidth

            readonly property real baseTargetWidth: {
                if (root.overviewVisible)
                    return root.overviewCapsuleWidth;
                if (sideTransientRestoreTimer.running) {
                    if (islandContainer.restingState === "lyrics" && ((islandContainer.islandState === "split" && islandContainer.splitOriginSide === "right") || (islandContainer.islandState === "long_capsule" && islandContainer.workspaceOriginSide === "right"))) {
                        return islandContainer.lyricsCapsuleWidth;
                    }
                    if (islandContainer.restingState === "custom" && ((islandContainer.islandState === "split" && islandContainer.splitOriginSide === "left") || (islandContainer.islandState === "long_capsule" && islandContainer.workspaceOriginSide === "left"))) {
                        return islandContainer.customCapsuleWidth;
                    }
                }

                switch (islandContainer.islandState) {
                case "split":
                    return islandContainer.splitCapsuleWidth;
                case "long_capsule":
                    return 220;
                case "custom":
                    return islandContainer.customCapsuleWidth;
                case "lyrics":
                    return islandContainer.lyricsCapsuleWidth;
                case "control_center":
                    return 420;
                case "power_menu":
                    return 420;
                case "app_launcher":
                    return 580;
                case "wallpaper_picker":
                    return 1100;
                case "clipboard_history":
                    return 460;
                case "ai_translate":
                    return 600;
                case "polkit_auth":
                    return 420;
                case "expanded":
                    return 620;
                case "alcove_music":
                    return 230;
                case "bluetooth_expanded":
                    return 400;
                case "lock_unlock":
                    return islandContainer.lockUnlockCapsuleWidth;
                case "notification":
                    if (!notificationLoader.item)
                        return 272;
                    return Math.max(notificationLoader.item.minimumWidth, Math.min(notificationLoader.item.maximumWidth, notificationLoader.item.preferredWidth));
                default:
                    return 140;
                }
            }

            readonly property real targetHeight: {
                if (root.overviewVisible)
                    return root.overviewCapsuleHeight;

                switch (islandContainer.islandState) {
                case "control_center":
                    return 320 + (controlCenterLoader.item ? controlCenterLoader.item.controlCenterExtraHeight : 32);
                case "power_menu":
                    return 130;
                case "app_launcher":
                    return 390;
                case "wallpaper_picker":
                    return 260;
                case "clipboard_history":
                    return 390;
                case "ai_translate":
                    return 480;
                case "polkit_auth":
                    return 260;
                case "expanded":
                    return 192;
                case "alcove_music":
                    return 40;
                case "bluetooth_expanded":
                    return 165;
                case "lock_unlock":
                    return 38;
                case "notification":
                    return notificationLoader.item ? Math.max(56, Math.min(68, notificationLoader.item.preferredHeight)) : 56;
                default:
                    return 38;
                }
            }

            readonly property real targetRadius: {
                if (root.overviewVisible)
                    return root.overviewCapsuleRadius;

                switch (islandContainer.islandState) {
                case "control_center":
                    return 34;
                case "power_menu":
                    return 34;
                case "app_launcher":
                    return 34;
                case "wallpaper_picker":
                    return 34;
                case "clipboard_history":
                    return 34;
                case "ai_translate":
                    return 34;
                case "polkit_auth":
                    return 34;
                case "expanded":
                    return 40;
                case "alcove_music":
                    return 20;
                case "bluetooth_expanded":
                    return 40;
                case "lock_unlock":
                    return 19;
                case "notification":
                    return mainCapsule.targetHeight / 2;
                default:
                    return 19;
                }
            }

            function sideSwipeWidthForProgress(progressValue) {
                if (progressValue < 0)
                    return 140 + (islandContainer.customCapsuleWidth - 140) * islandContainer.clamp01(-progressValue);
                if (progressValue > 0)
                    return 140 + (islandContainer.lyricsCapsuleWidth - 140) * islandContainer.clamp01(progressValue);
                return 140;
            }

            readonly property real sideSwipePreviewWidth: mainCapsule.sideSwipeWidthForProgress(islandContainer.swipeTransitionProgress)
            color: root.overviewContentVisible ? root.overviewCapsuleColor : StyleTokens.black
            y: 4
            anchors.horizontalCenter: parent.horizontalCenter
            clip: true
            width: displayedWidth
            height: targetHeight
            radius: targetRadius

            onBaseTargetWidthChanged: {
                if (!capsuleMouseArea.sideSwipeInteractive && !islandContainer.sideSwipeSettling)
                    displayedWidth = baseTargetWidth;
            }

            Behavior on displayedWidth {
                enabled: !capsuleMouseArea.sideSwipeInteractive
                NumberAnimation {
                    duration: islandContainer.skipWidthAnimation ? 0 : mainCapsule.morphDuration
                    easing.type: Easing.OutQuint
                }
            }
            Behavior on height {
                enabled: !(controlCenterLoader.item && controlCenterLoader.item.batteryDrawerMoving)
                NumberAnimation {
                    duration: mainCapsule.morphDuration
                    easing.type: Easing.OutQuint
                }
            }
            Behavior on radius {
                NumberAnimation {
                    duration: mainCapsule.morphDuration
                    easing.type: Easing.OutQuint
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: 280
                    easing.type: Easing.InOutQuad
                }
            }
            Behavior on outlineWidth {
                NumberAnimation {
                    duration: 260
                    easing.type: Easing.InOutQuad
                }
            }
            Behavior on outlineColor {
                ColorAnimation {
                    duration: 260
                    easing.type: Easing.InOutQuad
                }
            }
            border.width: outlineWidth
            border.color: outlineColor

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: Math.max(parent.radius - 1, 0)
                color: StyleTokens.transparent
                border.width: 1
                border.color: StyleTokens.overviewInnerBorder
                opacity: root.overviewContentVisible ? 1 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: root.overviewContentVisible ? 260 : 140
                        easing.type: Easing.InOutQuad
                    }
                }
            }

            MouseArea {
                id: capsuleMouseArea
                anchors.fill: parent
                z: -1
                enabled: !root.overviewVisible && twoFingerTouchArea.touchPoints.length < 2
                acceptedButtons: root.dynamicIslandAcceptedButtons
                preventStealing: true
                hoverEnabled: true

                onEntered: {
                    hoverCloseTimer.stop();
                    if (islandContainer.islandState === "normal" || islandContainer.islandState === "custom")
                        islandContainer.showExpandedPlayer(false);
                }
                onExited: {
                    if (islandContainer.islandState === "expanded" && islandContainer.expandedByPlayerAutoOpen === false && !islandContainer.playerProgressDragging)
                        hoverCloseTimer.restart();
                }

                Timer {
                    id: hoverCloseTimer
                    interval: 300
                    repeat: false
                    onTriggered: {
                        if (islandContainer.islandState === "expanded" && islandContainer.expandedByPlayerAutoOpen === false && !islandContainer.playerProgressDragging)
                            islandContainer.smartRestoreState();
                    }
                }
                property real swipeStartX: 0
                property real swipeStartY: 0
                property real swipeStartProgress: 0
                property real swipeLastX: 0
                property bool alcoveSwipeArmed: false
                property bool alcoveSwipeMoved: false
                readonly property real sideSwipeVerticalTolerance: 24
                property bool swipeArmed: false
                property bool swipeMoved: false
                property bool sideSwipeInteractive: false
                property bool suppressNextClick: false
                property bool preparedOverviewOnPress: false
                property bool stage2SwipeArmed: false
                property bool stage2SwipeMoved: false

                Timer {
                    id: swipeSuppressReset
                    interval: 180
                    repeat: false
                    onTriggered: capsuleMouseArea.suppressNextClick = false
                }

                onPressed: mouse => {
                    const mappedPoint = capsuleMouseArea.mapToItem(islandContainer, mouse.x, mouse.y);
                    swipeStartX = mappedPoint.x;
                    swipeStartY = mappedPoint.y;
                    islandContainer.cancelSideSwipeSettle();
                    const inLyrics = islandContainer.islandState === "lyrics";
                    stage2SwipeArmed = inLyrics && mouse.button === Qt.LeftButton;
                    stage2SwipeMoved = false;
                    swipeArmed = mouse.button === Qt.LeftButton && islandContainer.canShowSideSwipe && !inLyrics;
                    alcoveSwipeArmed = mouse.button === Qt.LeftButton && !root.overviewVisible && (islandContainer.islandState === "normal" || islandContainer.islandState === "custom" || islandContainer.islandState === "lyrics" || islandContainer.islandState === "expanded");
                    swipeStartProgress = islandContainer.swipeTransitionProgress;
                    swipeLastX = mappedPoint.x;
                    swipeMoved = false;
                    alcoveSwipeMoved = false;
                    sideSwipeInteractive = swipeArmed;
                    islandContainer.swipeTransitionProgress = swipeStartProgress;

                    let pressedAction = "";
                    if (mouse.button === userConfig.mouseButton(userConfig.dynamicIslandPrimaryButton)) {
                        pressedAction = userConfig.dynamicIslandPrimaryAction;
                    } else if (mouse.button === userConfig.mouseButton(userConfig.dynamicIslandSecondaryButton)) {
                        pressedAction = userConfig.dynamicIslandSecondaryAction;
                    }

                    preparedOverviewOnPress = pressedAction === "openOverview" || (pressedAction === "toggleOverview" && root.overviewPhase === "closed");
                    if (preparedOverviewOnPress)
                        root.prepareOverviewEverywhere();
                }

                onPositionChanged: mouse => {
                    if (!pressed || suppressNextClick || twoFingerTouchArea.touchPoints.length >= 2)
                        return;
                    const mappedPoint = capsuleMouseArea.mapToItem(islandContainer, mouse.x, mouse.y);
                    const deltaX = mappedPoint.x - swipeLastX;
                    const deltaY = mappedPoint.y - swipeStartY;
                    const absDeltaY = Math.abs(deltaY);
                    const absDeltaX = Math.abs(mappedPoint.x - swipeStartX);
                    if (stage2SwipeArmed) {
                        const totalDeltaX = mappedPoint.x - swipeStartX;
                        console.log("stage2 check: totalDeltaX=", totalDeltaX, "deltaY=", Math.abs(deltaY), "tolerance=", sideSwipeVerticalTolerance, "moved=", stage2SwipeMoved);
                        if (totalDeltaX > 18 && Math.abs(deltaY) < sideSwipeVerticalTolerance) {
                            stage2SwipeMoved = true;
                            suppressNextClick = true;
                            console.log("stage2SwipeMoved SET");
                        }
                    }
                    if (alcoveSwipeArmed && deltaY < -14 && absDeltaY > absDeltaX + 6) {
                        alcoveSwipeMoved = true;
                        swipeArmed = false;
                        sideSwipeInteractive = false;
                        suppressNextClick = true;
                        return;
                    }
                    if (!swipeArmed)
                        return;
                    const adjustedDeltaX = absDeltaY < sideSwipeVerticalTolerance ? deltaX : 0;
                    const nextProgress = islandContainer.advanceSideSwipeProgress(islandContainer.swipeTransitionProgress, adjustedDeltaX);
                    swipeMoved = swipeMoved || Math.abs(nextProgress - swipeStartProgress) > 0.03 || absDeltaY > 6;
                    swipeLastX = mappedPoint.x;
                    islandContainer.swipeTransitionProgress = nextProgress;
                    mainCapsule.displayedWidth = mainCapsule.sideSwipePreviewWidth;
                }

                onReleased: {
                    console.log("onReleased: stage2SwipeMoved=", stage2SwipeMoved, "stage2SwipeArmed=", stage2SwipeArmed, "alcoveSwipeMoved=", alcoveSwipeMoved, "swipeMoved=", swipeMoved, "islandState=", islandContainer.islandState);
                    if (stage2SwipeMoved) {
                        if (preparedOverviewOnPress)
                            root.cancelPreparedOverviewEverywhere();
                        preparedOverviewOnPress = false;
                        stage2SwipeArmed = false;
                        stage2SwipeMoved = false;
                        suppressNextClick = true;
                        swipeSuppressReset.restart();
                        islandContainer.alcoveReturnState = "lyrics";
                        islandContainer.showAlcoveMusicCapsule();
                        return;
                    }
                    if (alcoveSwipeMoved) {
                        if (preparedOverviewOnPress)
                            root.cancelPreparedOverviewEverywhere();
                        preparedOverviewOnPress = false;
                        islandContainer.showAlcoveMusicCapsule();
                        alcoveSwipeArmed = false;
                        alcoveSwipeMoved = false;
                        swipeArmed = false;
                        swipeMoved = false;
                        sideSwipeInteractive = false;
                        suppressNextClick = true;
                        swipeSuppressReset.restart();
                        return;
                    }
                    if (swipeMoved) {
                        if (preparedOverviewOnPress)
                            root.cancelPreparedOverviewEverywhere();
                        preparedOverviewOnPress = false;
                        suppressNextClick = true;
                        swipeSuppressReset.restart();
                    }
                    let settleResult = {
                        action: "",
                        progress: islandContainer.sideSwipeRestProgressForProgress(swipeStartProgress),
                        width: islandContainer.sideSwipeRestWidthForProgress(swipeStartProgress)
                    };

                    if (swipeArmed)
                        settleResult = islandContainer.resolveSideSwipeSettle(swipeStartProgress, islandContainer.swipeTransitionProgress);

                    sideSwipeInteractive = false;

                    if (swipeArmed)
                        islandContainer.beginSideSwipeSettle(settleResult.width);
                    else
                        mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;

                    if (swipeArmed) {
                        switch (settleResult.action) {
                        case "time":
                            islandContainer.showTimeCapsule();
                            break;
                        case "custom":
                            islandContainer.showCustomCapsule();
                            break;
                        case "lyrics":
                            islandContainer.showLyricsCapsule();
                            break;
                        default:
                            islandContainer.swipeTransitionProgress = settleResult.progress;
                        }
                    } else {
                        islandContainer.swipeTransitionProgress = settleResult.progress;
                    }
                    swipeArmed = false;
                    swipeMoved = false;
                    alcoveSwipeArmed = false;
                    alcoveSwipeMoved = false;
                }

                onCanceled: {
                    if (preparedOverviewOnPress)
                        root.cancelPreparedOverviewEverywhere();
                    swipeArmed = false;
                    swipeMoved = false;
                    alcoveSwipeArmed = false;
                    alcoveSwipeMoved = false;
                    sideSwipeInteractive = false;
                    stage2SwipeArmed = false;
                    stage2SwipeMoved = false;
                    suppressNextClick = false;
                    preparedOverviewOnPress = false;
                    swipeSuppressReset.stop();
                    mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
                    islandContainer.swipeTransitionProgress = islandContainer.swipeRestProgressForState();
                }

                onClicked: mouse => {
                    if (suppressNextClick) {
                        swipeSuppressReset.stop();
                        suppressNextClick = false;
                        preparedOverviewOnPress = false;
                        return;
                    }
                    if (mouse.button === userConfig.mouseButton(userConfig.dynamicIslandPrimaryButton)) {
                        preparedOverviewOnPress = false;
                        islandContainer.handleConfiguredClickAction(userConfig.dynamicIslandPrimaryAction);
                        return;
                    }
                    if (mouse.button === userConfig.mouseButton(userConfig.dynamicIslandSecondaryButton)) {
                        preparedOverviewOnPress = false;
                        islandContainer.handleConfiguredClickAction(userConfig.dynamicIslandSecondaryAction);
                    }
                }
            }

            MultiPointTouchArea {
                id: twoFingerTouchArea
                anchors.fill: parent
                z: 0
                enabled: !root.overviewVisible
                mouseEnabled: false
                minimumTouchPoints: 2
                maximumTouchPoints: 2

                property real swipeStartX: 0
                property real swipeStartProgress: 0
                property bool swipeMoved: false

                onPressed: touchPoints => {
                    const centerPoint = islandContainer.mapFromItem(twoFingerTouchArea, (touchPoints[0].x + touchPoints[1].x) / 2, (touchPoints[0].y + touchPoints[1].y) / 2);
                    swipeStartX = centerPoint.x;
                    swipeStartProgress = islandContainer.swipeTransitionProgress;
                    swipeMoved = false;
                    islandContainer.cancelSideSwipeSettle();
                }

                onUpdated: touchPoints => {
                    const centerPoint = islandContainer.mapFromItem(twoFingerTouchArea, (touchPoints[0].x + touchPoints[1].x) / 2, (touchPoints[0].y + touchPoints[1].y) / 2);
                    const deltaX = centerPoint.x - swipeStartX;
                    const nextProgress = islandContainer.advanceSideSwipeProgress(swipeStartProgress, deltaX);
                    if (Math.abs(nextProgress - swipeStartProgress) > 0.03) {
                        swipeMoved = true;
                    }
                    islandContainer.swipeTransitionProgress = nextProgress;
                    mainCapsule.displayedWidth = mainCapsule.sideSwipePreviewWidth;
                }

                onReleased: {
                    if (swipeMoved) {
                        const settleResult = islandContainer.resolveSideSwipeSettle(swipeStartProgress, islandContainer.swipeTransitionProgress);
                        islandContainer.beginSideSwipeSettle(settleResult.width);
                        switch (settleResult.action) {
                        case "time":
                            islandContainer.showTimeCapsule();
                            break;
                        case "custom":
                            islandContainer.showCustomCapsule();
                            break;
                        case "lyrics":
                            islandContainer.showLyricsCapsule();
                            break;
                        default:
                            islandContainer.swipeTransitionProgress = settleResult.progress;
                        }
                    } else {
                        islandContainer.swipeTransitionProgress = islandContainer.sideSwipeRestProgressForProgress(swipeStartProgress);
                    }
                    swipeMoved = false;
                }
            }

            Loader {
                id: customSwipeLoader
                anchors.fill: parent
                active: islandContainer.customSwipeVisible && islandContainer.islandState !== "lock_unlock"
                asynchronous: false
                visible: active
                onLoaded: islandContainer.syncCustomCapsuleWidth()
                sourceComponent: Component {
                    SwipeCustomInfoLayer {
                        items: islandContainer.customLeftItems
                        cavaLevels: islandContainer.cavaLevels
                        timeText: timeObj.currentTime
                        iconFontFamily: root.iconFontFamily
                        textFontFamily: root.heroFontFamily
                        timeFontFamily: root.heroFontFamily
                        minimumWidth: 220
                        maximumWidth: Math.max(220, root.width - 48)
                        transitionProgress: islandContainer.swipeTransitionProgress
                        recordingActive: islandContainer.screenRecordingActive
                        showSecondaryText: islandContainer.workspaceOriginSide !== "left" && islandContainer.splitOriginSide !== "left"
                        showCondition: true
                        onPreferredWidthChanged: islandContainer.syncCustomCapsuleWidth()
                    }
                }
            }

            Loader {
                id: lyricsSwipeLoader
                anchors.fill: parent
                active: islandContainer.lyricsSwipeVisible && islandContainer.islandState !== "lock_unlock"
                asynchronous: false
                visible: active
                onLoaded: islandContainer.syncLyricsCapsuleWidth()
                sourceComponent: Component {
                    SwipeLyricsLayer {
                        lyricText: islandContainer.lyricsDisplayText
                        timeText: timeObj.currentTime
                        textFontFamily: root.textFontFamily
                        timeFontFamily: root.timeFontFamily
                        textPixelSize: 16
                        minimumWidth: 220
                        maximumWidth: Math.max(220, root.width - 48)
                        transitionProgress: islandContainer.rightSwipeProgress
                        recordingActive: islandContainer.screenRecordingActive
                        showSecondaryText: islandContainer.workspaceOriginSide !== "right" && islandContainer.splitOriginSide !== "right"
                        showCondition: true
                        onPreferredWidthChanged: islandContainer.syncLyricsCapsuleWidth()
                    }
                }
            }

            Loader {
                id: splitIconLoader
                anchors.fill: parent
                active: !root.overviewVisible && islandContainer.splitShowsIconOnly
                asynchronous: false
                visible: active
                sourceComponent: Component {
                    SplitIconLayer {
                        iconText: islandContainer.splitIcon
                        iconFontFamily: root.iconFontFamily
                        transitionProgress: islandContainer.swipeTransitionProgress
                        slideDirection: islandContainer.splitOriginSide
                        showCondition: true
                    }
                }
            }

            Loader {
                id: osdLayerLoader
                anchors.fill: parent
                active: !root.overviewVisible && islandContainer.splitUsesExtendedLayout
                asynchronous: false
                visible: active
                sourceComponent: Component {
                    OsdLayer {
                        iconText: islandContainer.splitIcon
                        progress: islandContainer.osdProgress
                        customText: islandContainer.osdCustomText
                        iconFontFamily: root.iconFontFamily
                        textFontFamily: root.textFontFamily
                        heroFontFamily: root.heroFontFamily
                        transitionProgress: islandContainer.swipeTransitionProgress
                        slideDirection: islandContainer.splitOriginSide
                        showCondition: true
                    }
                }
            }

            Loader {
                id: workspaceLayerLoader
                anchors.fill: parent
                active: !root.overviewVisible && islandContainer.islandState === "long_capsule" && (islandContainer.workspaceOriginSide !== "none" || Math.abs(islandContainer.swipeTransitionProgress) < 0.001)
                asynchronous: false
                visible: active
                sourceComponent: Component {
                    WorkspaceLayer {
                        workspaceId: islandContainer.currentWs
                        displayText: "Workspace " + islandContainer.currentWs
                        textFontFamily: root.textFontFamily
                        textPixelSize: 16
                        animateVisibility: islandContainer.restingState === "normal"
                        transitionProgress: islandContainer.swipeTransitionProgress
                        showCondition: true
                        slideDirection: islandContainer.workspaceOriginSide
                    }
                }
            }

            Loader {
                id: expandedPlayerLoader
                property bool keepAlive: false
                active: islandContainer.expandedLayerVisible || keepAlive
                asynchronous: false
                visible: islandContainer.expandedLayerVisible
                anchors.fill: parent
                onLoaded: {
                    if (item) {
                        item.pomodoroFinished.connect(function (summary, body) {
                            islandContainer.notificationAppName = "Pomodoro";
                            islandContainer.notificationSummary = summary;
                            islandContainer.notificationBody = body;
                            islandContainer.notificationImagePath = "";
                            islandContainer.islandState = "notification";
                            islandContainer.restartAutoHideTimer(islandContainer.notificationAutoHideInterval);
                        });
                    }
                    keepAlive = true;
                }
                sourceComponent: Component {
                    NookTrayLayer {
                        currentArtUrl: islandContainer.currentArtUrl
                        preloadedArtSource: islandContainer.preloadedArtReady ? artPreloader.source : ""
                        currentTrack: islandContainer.currentTrack
                        currentArtist: islandContainer.currentArtist
                        timePlayed: islandContainer.timePlayed
                        timeTotal: islandContainer.timeTotal
                        trackProgress: islandContainer.trackProgress
                        activePlayer: islandContainer.activePlayer
                        iconFontFamily: root.iconFontFamily
                        textFontFamily: root.textFontFamily
                        showCondition: islandContainer.expandedLayerVisible
                        onControlPressed: islandContainer.suppressCapsuleClick()
                        onSettingsPressed: islandContainer.showControlCenter()
                        onProgressDraggingChanged: islandContainer.playerProgressDragging = progressDragging
                    }
                }
            }

            Loader {
                id: bluetoothExpandedLoader
                anchors.fill: parent
                active: islandContainer.bluetoothExpandedLayerVisible
                asynchronous: false
                visible: active
                sourceComponent: Component {
                    BluetoothExpandedLayer {
                        device: islandContainer.bluetoothExpandedDevice
                        volumeLevel: islandContainer.currentVolume
                        iconText: ""
                        iconFontFamily: root.iconFontFamily
                        textFontFamily: root.textFontFamily
                        showCondition: islandContainer.bluetoothExpandedLayerVisible
                    }
                }
            }

            Loader {
                id: alcoveMusicLoader
                anchors.fill: parent
                active: islandContainer.alcoveMusicLayerVisible
                asynchronous: false
                visible: active
                sourceComponent: Component {
                    AlcoveMusicCapsule {
                        currentArtUrl: islandContainer.currentArtUrl
                        preloadedArtSource: islandContainer.preloadedArtReady ? artPreloader.source : ""
                        cavaLevels: islandContainer.cavaLevels
                        iconFontFamily: root.iconFontFamily
                        showCondition: islandContainer.alcoveMusicLayerVisible
                        onCloseRequested: islandContainer.smartRestoreState()
                    }
                }
            }

            Loader {
                id: notificationLoader
                anchors.fill: parent
                active: islandContainer.notificationLayerVisible
                asynchronous: false
                visible: active
                sourceComponent: Component {
                    NotificationLayer {
                        appName: islandContainer.notificationAppName
                        summary: islandContainer.notificationSummary
                        body: islandContainer.notificationBody
                        iconText: root.notificationStatusIcon
                        imagePath: islandContainer.notificationImagePath
                        iconFontFamily: root.iconFontFamily
                        textFontFamily: root.textFontFamily
                        heroFontFamily: root.heroFontFamily
                        showCondition: true
                    }
                }
            }

            Loader {
                id: powerMenuLoader
                anchors.fill: parent
                active: islandContainer.powerMenuLayerVisible
                asynchronous: false
                visible: active
                sourceComponent: Component {
                    PowerMenuLayer {
                        iconFontFamily: root.iconFontFamily
                        textFontFamily: root.textFontFamily
                        showCondition: islandContainer.powerMenuLayerVisible
                        onCloseRequested: islandContainer.smartRestoreState()
                    }
                }
            }

            Loader {
                id: appLauncherLoader
                anchors.fill: parent
                property bool keepAlive: false
                active: islandContainer.appLauncherLayerVisible || keepAlive
                onLoaded: keepAlive = true
                asynchronous: false
                visible: islandContainer.appLauncherLayerVisible
                sourceComponent: Component {
                    AppLauncherLayer {
                        iconFontFamily: root.iconFontFamily
                        textFontFamily: root.textFontFamily
                        showCondition: islandContainer.appLauncherLayerVisible
                        onCloseRequested: islandContainer.smartRestoreState()
                    }
                }
            }

            Loader {
                id: wallpaperPickerLoader
                anchors.fill: parent
                property bool keepAlive: false
                active: islandContainer.wallpaperPickerLayerVisible || keepAlive
                onLoaded: keepAlive = true
                asynchronous: false
                visible: islandContainer.wallpaperPickerLayerVisible
                sourceComponent: Component {
                    WallpaperPickerLayer {
                        iconFontFamily: root.iconFontFamily
                        textFontFamily: root.textFontFamily
                        showCondition: islandContainer.wallpaperPickerLayerVisible
                        onCloseRequested: islandContainer.smartRestoreState()
                    }
                }
            }

            Loader {
                id: clipboardHistoryLoader
                anchors.fill: parent
                property bool keepAlive: false
                active: islandContainer.clipboardHistoryLayerVisible || keepAlive
                onLoaded: keepAlive = true
                asynchronous: false
                visible: islandContainer.clipboardHistoryLayerVisible
                sourceComponent: Component {
                    ClipboardHistoryLayer {
                        iconFontFamily: root.iconFontFamily
                        textFontFamily: root.textFontFamily
                        showCondition: islandContainer.clipboardHistoryLayerVisible
                        onCloseRequested: islandContainer.smartRestoreState()
                    }
                }
            }
            Loader {
                id: aiTranslateLoader
                anchors.fill: parent
                property bool keepAlive: false
                active: islandContainer.aiTranslateLayerVisible || keepAlive
                onLoaded: keepAlive = true
                asynchronous: false
                visible: islandContainer.aiTranslateLayerVisible
                sourceComponent: Component {
                    AiTranslateLayer {
                        iconFontFamily: root.iconFontFamily
                        textFontFamily: root.textFontFamily
                        showCondition: islandContainer.aiTranslateLayerVisible
                        onCloseRequested: islandContainer.smartRestoreState()
                    }
                }
            }
            Loader {
                id: polkitAuthLoader
                anchors.fill: parent
                active: islandContainer.polkitAuthLayerVisible
                asynchronous: false
                visible: active
                sourceComponent: Component {
                    PolkitAuthLayer {
                        iconFontFamily: root.iconFontFamily
                        textFontFamily: root.textFontFamily
                        showCondition: islandContainer.polkitAuthLayerVisible
                        onCloseRequested: islandContainer.smartRestoreState()
                    }
                }
            }

            Loader {
                id: lockUnlockLoader
                anchors.fill: parent
                active: islandContainer.lockUnlockLayerVisible
                asynchronous: false
                visible: active
                sourceComponent: Component {
                    LockUnlockLayer {
                        iconFontFamily: root.iconFontFamily
                        textFontFamily: root.textFontFamily
                        showCondition: islandContainer.lockUnlockLayerVisible
                        onAnimationFinished: {
                            islandContainer.resetLockUnlockCapsule();
                        }
                    }
                }
                onLoaded: {
                    if (item) {
                        unlockStartDelay.restart();
                    }
                }

                Timer {
                    id: unlockStartDelay
                    interval: 420
                    repeat: false
                    onTriggered: {
                        if (lockUnlockLoader.item)
                            lockUnlockLoader.item.playUnlock();
                    }
                }
            }

            Loader {
                id: controlCenterLoader
                anchors.fill: parent
                active: islandContainer.controlCenterLayerVisible || root.anyConnectivityDetailMounted
                asynchronous: false
                visible: active
                onLoaded: {
                    if (item)
                        item.requestNotification.connect(islandContainer.showNotificationCapsule);
                }
                sourceComponent: Component {
                    ControlCenterLayer {
                        iconFontFamily: root.iconFontFamily
                        textFontFamily: root.textFontFamily
                        heroFontFamily: root.heroFontFamily
                        sliderIntroDelay: mainCapsule.morphDuration
                        currentTime: timeObj.currentTime
                        currentDateLabel: timeObj.currentDateLabel
                        batteryCapacity: islandContainer.batteryCapacity
                        isCharging: islandContainer.isCharging
                        volumeLevel: islandContainer.currentVolume
                        brightnessLevel: islandContainer.currentBrightness
                        currentWorkspace: islandContainer.currentWs
                        currentTrack: islandContainer.currentTrack
                        currentArtist: islandContainer.currentArtist
                        showCondition: islandContainer.controlCenterLayerVisible
                    }
                }
            }

            Loader {
                id: overviewLoader
                anchors.fill: parent
                active: root.overviewLoaderActive
                asynchronous: false
                visible: root.overviewContentVisible
                onStatusChanged: {
                    if (status === Loader.Ready && root.overviewPreparing) {
                        root.beginOverviewOpening();
                    }
                }
                sourceComponent: Component {
                    WorkspaceOverviewScene {
                        screen: root.screen
                        showCondition: root.overviewVisible
                        previewsEnabled: root.overviewContentVisible
                        textFontFamily: root.textFontFamily
                        heroFontFamily: root.heroFontFamily
                        wallpaperPath: root.overviewWallpaperSource
                        windowCornerRadius: root.overviewWindowCornerRadius
                        onCloseRequested: root.closeOverviewEverywhere()
                    }
                }
            }
        }

        ConnectivityDetailShell {
            id: wifiConnectivityDetailShell
            open: root.wifiConnectivityDetailOpen
            mounted: root.wifiConnectivityDetailMounted
            rightSide: false
            panelKind: "wifi"
            provider: controlCenterLoader.item
            mainCapsule: mainCapsule
            availableWidth: root.width
            detailWidth: root.connectivityDetailWidth
            detailHeight: root.connectivityDetailHeight
            detailGap: root.connectivityDetailGap
            iconFontFamily: root.iconFontFamily
            textFontFamily: root.textFontFamily
            heroFontFamily: root.heroFontFamily
        }

        ConnectivityDetailShell {
            id: bluetoothConnectivityDetailShell
            open: root.bluetoothConnectivityDetailOpen
            mounted: root.bluetoothConnectivityDetailMounted
            rightSide: true
            panelKind: "bluetooth"
            provider: controlCenterLoader.item
            mainCapsule: mainCapsule
            availableWidth: root.width
            detailWidth: root.connectivityDetailWidth
            detailHeight: root.connectivityDetailHeight
            detailGap: root.connectivityDetailGap
            iconFontFamily: root.iconFontFamily
            textFontFamily: root.textFontFamily
            heroFontFamily: root.heroFontFamily
        }
    }

    IslandRootGestureArea {
        anchors.fill: parent
        enabled: root.topGestureInputActive
        islandController: islandContainer
        capsule: mainCapsule
    }
}
