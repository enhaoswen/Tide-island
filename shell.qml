import QtQuick
import Quickshell
import Quickshell.Io
import IslandBackend
import "qml/island"

Scope {
    id: shellRoot

    readonly property bool screenRecordingActive: SystemServices.screenRecordingActive
    property bool focusEnabled: false
    property bool nightLightEnabled: false
    property bool shuttingDown: false
    property bool islandAutoHideRuntimeEnabled: true

    readonly property var userConfig: UserConfig
    readonly property string clipboardHelperScriptPath: {
        const candidate = Qt.resolvedUrl("scripts/cliphist-helper.sh").toString();
        return candidate.startsWith("file://")
            ? decodeURIComponent(candidate.substring(7))
            : "/usr/share/tide-island/scripts/cliphist-helper.sh";
    }

    // Keep clipboard history recording for the lifetime of the shell, even
    // while the clipboard panel is closed.
    Process {
        command: ["bash", shellRoot.clipboardHelperScriptPath, "watch"]
        running: true
    }

    WeatherService {
        id: globalWeatherService
    }
    readonly property var weatherService: globalWeatherService

    function forEachWindow(callback) {
        const windows = panelVariants.instances ? panelVariants.instances : [];
        for (let index = 0; index < windows.length; index++) {
            const window = windows[index];
            if (window)
                callback(window);
        }
    }

    function showNotificationAll(appName, summary, body) {
        if (focusEnabled)
            return;

        shellRoot.forEachWindow((window) => {
            if (window && window.showNotification)
                window.showNotification(appName, summary, body);
        });
    }

    function anyOverviewOpen() {
        if (CompositorBackend.compositor === "niri")
            return false;

        const windows = panelVariants.instances ? panelVariants.instances : [];
        for (let index = 0; index < windows.length; index++) {
            const window = windows[index];
            if (window && window.overviewPhase !== "closed")
                return true;
        }

        return false;
    }

    function prepareOverviewAll() {
        if (CompositorBackend.compositor === "niri")
            return;

        shellRoot.forEachWindow((window) => window.prepareOverview());
    }

    function cancelPreparedOverviewAll() {
        if (CompositorBackend.compositor === "niri")
            return;

        shellRoot.forEachWindow((window) => window.cancelPreparedOverview());
    }

    function openOverviewAll() {
        if (CompositorBackend.compositor === "niri")
            return;

        shellRoot.forEachWindow((window) => window.openOverview());
    }

    function closeOverviewAll() {
        if (CompositorBackend.compositor === "niri")
            return;

        shellRoot.forEachWindow((window) => window.closeOverview());
    }

    function toggleOverviewAll() {
        if (CompositorBackend.compositor === "niri")
            return;

        if (shellRoot.anyOverviewOpen())
            shellRoot.closeOverviewAll();
        else
            shellRoot.openOverviewAll();
    }

    function anyIslandShown() {
        const windows = panelVariants.instances ? panelVariants.instances : [];
        for (let index = 0; index < windows.length; index++) {
            const window = windows[index];
            if (window && window.autoHideTargetVisible)
                return true;
        }

        return false;
    }

    function showIslandAll() {
        shellRoot.forEachWindow((window) => {
            if (window && window.showIslandWindow)
                window.showIslandWindow();
        });
    }

    function hideIslandAll() {
        shellRoot.forEachWindow((window) => {
            if (window && window.hideIslandWindow)
                window.hideIslandWindow();
        });
    }

    function toggleIslandAll() {
        if (shellRoot.anyIslandShown())
            shellRoot.hideIslandAll();
        else
            shellRoot.showIslandAll();
    }

    function refreshIslandAutoHideAll() {
        shellRoot.forEachWindow((window) => {
            if (window && window.refreshAutoHideWindow)
                window.refreshAutoHideWindow();
        });
    }

    function refreshOverviewWallpaperCaches(wallpaperPath) {
        shellRoot.forEachWindow((window) => {
            if (window
                    && wallpaperPath !== undefined
                    && wallpaperPath !== null
                    && String(wallpaperPath) !== "") {
                window.wallpaperPickerActiveWallpaper = String(wallpaperPath);
            }
            if (window && window.prewarmWallpaperCache)
                window.prewarmWallpaperCache();
        });
    }

    function forFocusedWindow(callback) {
        const windows = panelVariants.instances ? panelVariants.instances : [];
        let fallbackWindow = null;
        for (let index = 0; index < windows.length; index++) {
            const window = windows[index];
            if (window && !fallbackWindow)
                fallbackWindow = window;
            if (window && window.monitorFocused) {
                callback(window);
                return;
            }
        }

        if (fallbackWindow)
            callback(fallbackWindow);
    }

    IpcHandler {
        target: "overview"

        function toggle() {
            shellRoot.toggleOverviewAll();
        }

        function open() {
            shellRoot.openOverviewAll();
        }

        function close() {
            shellRoot.closeOverviewAll();
        }

        function refreshWallpaperCache() {
            shellRoot.refreshOverviewWallpaperCaches();
        }
    }

    IpcHandler {
        target: "island"

        function show() {
            shellRoot.showIslandAll();
        }

        function open() {
            shellRoot.showIslandAll();
        }

        function reveal() {
            shellRoot.showIslandAll();
        }

        function hide() {
            shellRoot.hideIslandAll();
        }

        function toggle() {
            shellRoot.toggleIslandAll();
        }

        function enableAutoHide() {
            shellRoot.islandAutoHideRuntimeEnabled = true;
            shellRoot.refreshIslandAutoHideAll();
        }

        function disableAutoHide() {
            shellRoot.islandAutoHideRuntimeEnabled = false;
            shellRoot.showIslandAll();
        }
    }

    IpcHandler {
        target: "tide"

        function spotifyFavoritesStatus(): string {
            return JSON.stringify({
                configured: SpotifyBridge.configured,
                connected: SpotifyBridge.connected,
                stateKnown: SpotifyBridge.stateKnown,
                trackUri: SpotifyBridge.trackUri,
                liked: SpotifyBridge.liked,
                busy: SpotifyBridge.busy,
                error: SpotifyBridge.error
            });
        }

        function showClock() {
            shellRoot.forFocusedWindow((window) => window.showClockWindow());
        }

        function showTimer() {
            shellRoot.forFocusedWindow((window) => window.showTimerWindow());
        }

        function showCustom() {
            shellRoot.forFocusedWindow((window) => window.showCustomInfoWindow());
        }

        function showLyrics() {
            shellRoot.forFocusedWindow((window) => window.showLyricsWindow());
        }

        function swipeRight() {
            shellRoot.forFocusedWindow((window) => window.swipeRightWindow());
        }

        function swipeLeft() {
            shellRoot.forFocusedWindow((window) => window.swipeLeftWindow());
        }

        function togglePlayer() {
            shellRoot.forFocusedWindow((window) => window.togglePlayerWindow());
        }

        function toggleControlCenter() {
            shellRoot.forFocusedWindow((window) => window.toggleControlCenterWindow());
        }

        function togglePowerMenu() {
            shellRoot.forFocusedWindow((window) => window.togglePowerMenuWindow());
        }

        function toggleNotificationCenter() {
            shellRoot.forFocusedWindow((window) => window.toggleNotificationCenterWindow());
        }

        function toggleWallpaperPicker() {
            shellRoot.forFocusedWindow((window) => window.toggleWallpaperPickerWindow());
        }

        function toggleApplicationLauncher() {
            shellRoot.forFocusedWindow((window) => window.toggleApplicationLauncherWindow());
        }

        function toggleFileShelf() {
            shellRoot.forFocusedWindow((window) => window.toggleFileShelfWindow());
        }

        function toggleClipboard() {
            shellRoot.forFocusedWindow((window) => window.toggleClipboardWindow());
        }

        function showClipboard() {
            shellRoot.forFocusedWindow((window) => window.showClipboardWindow ? window.showClipboardWindow() : window.toggleClipboardWindow());
        }

        function openClipboard() {
            shellRoot.forFocusedWindow((window) => window.showClipboardWindow ? window.showClipboardWindow() : window.toggleClipboardWindow());
        }

        function closeClipboard() {
            shellRoot.forFocusedWindow((window) => window.closeClipboardWindow ? window.closeClipboardWindow() : window.toggleClipboardWindow());
        }

        function toggleWeather() {
            shellRoot.forFocusedWindow((window) => window.toggleWeatherWindow());
        }

        function showWeather() {
            shellRoot.forFocusedWindow((window) => window.showWeatherWindow ? window.showWeatherWindow() : window.toggleWeatherWindow());
        }

        function openWeather() {
            shellRoot.forFocusedWindow((window) => window.showWeatherWindow ? window.showWeatherWindow() : window.toggleWeatherWindow());
        }

        function closeWeather() {
            shellRoot.forFocusedWindow((window) => window.closeWeatherWindow ? window.closeWeatherWindow() : window.toggleWeatherWindow());
        }

        function toggleCalendar() {
            shellRoot.forFocusedWindow((window) => window.toggleCalendarWindow());
        }

        function showCalendar() {
            shellRoot.forFocusedWindow((window) => window.showCalendarWindow ? window.showCalendarWindow() : window.toggleCalendarWindow());
        }

        function openCalendar() {
            shellRoot.forFocusedWindow((window) => window.showCalendarWindow ? window.showCalendarWindow() : window.toggleCalendarWindow());
        }

        function closeCalendar() {
            shellRoot.forFocusedWindow((window) => window.closeCalendarWindow ? window.closeCalendarWindow() : window.toggleCalendarWindow());
        }
    }

    IpcHandler {
        target: "clipboard"

        function toggle() {
            shellRoot.forFocusedWindow((window) => window.toggleClipboardWindow());
        }

        function show() {
            shellRoot.forFocusedWindow((window) => window.showClipboardWindow ? window.showClipboardWindow() : window.toggleClipboardWindow());
        }

        function open() {
            shellRoot.forFocusedWindow((window) => window.showClipboardWindow ? window.showClipboardWindow() : window.toggleClipboardWindow());
        }

        function close() {
            shellRoot.forFocusedWindow((window) => window.closeClipboardWindow ? window.closeClipboardWindow() : window.toggleClipboardWindow());
        }
    }

    IpcHandler {
        target: "weather"

        function toggle() {
            shellRoot.forFocusedWindow((window) => window.toggleWeatherWindow());
        }

        function show() {
            shellRoot.forFocusedWindow((window) => window.showWeatherWindow ? window.showWeatherWindow() : window.toggleWeatherWindow());
        }

        function open() {
            shellRoot.forFocusedWindow((window) => window.showWeatherWindow ? window.showWeatherWindow() : window.toggleWeatherWindow());
        }

        function close() {
            shellRoot.forFocusedWindow((window) => window.closeWeatherWindow ? window.closeWeatherWindow() : window.toggleWeatherWindow());
        }

        function refresh() {
            if (shellRoot.weatherService)
                shellRoot.weatherService.refresh();
        }
    }

    IpcHandler {
        target: "calendar"

        function toggle() {
            shellRoot.forFocusedWindow((window) => window.toggleCalendarWindow());
        }

        function show() {
            shellRoot.forFocusedWindow((window) => window.showCalendarWindow ? window.showCalendarWindow() : window.toggleCalendarWindow());
        }

        function open() {
            shellRoot.forFocusedWindow((window) => window.showCalendarWindow ? window.showCalendarWindow() : window.toggleCalendarWindow());
        }

        function close() {
            shellRoot.forFocusedWindow((window) => window.closeCalendarWindow ? window.closeCalendarWindow() : window.toggleCalendarWindow());
        }
    }

    Connections {
        target: SystemServices

        function onNotificationReceived(appName, summary, body) {
            shellRoot.showNotificationAll(appName, summary, body);
        }
    }

    Component.onDestruction: {
        shuttingDown = true;
    }

    Component.onCompleted: {
        SystemServices.ensureUserConfigAvailable();
        SystemServices.requestScreenRecordingSnapshot();
    }

    Variants {
        id: panelVariants

        model: Quickshell.screens

        DynamicIslandWindow {
            required property var modelData

            screen: modelData
            shellRootController: shellRoot
        }
    }
}
