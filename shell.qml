import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import IslandBackend

Scope {
    id: shellRoot

    readonly property bool screenRecordingActive: SystemServices.screenRecordingActive
    property bool shuttingDown: false

    readonly property var userConfig: UserConfig

    readonly property var primaryScreen: Quickshell.primaryScreen ?? (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)

    function forEachWindow(callback) {
        const windows = panelVariants.instances ? panelVariants.instances : [];
        for (let index = 0; index < windows.length; index++) {
            const window = windows[index];
            if (window)
                callback(window);
        }
    }

    function showNotificationAll(appName, summary, body) {
        shellRoot.forEachWindow(window => {
            if (window && window.showNotification)
                window.showNotification(appName, summary, body);
        });
    }

    function anyOverviewOpen() {
        const windows = panelVariants.instances ? panelVariants.instances : [];
        for (let index = 0; index < windows.length; index++) {
            const window = windows[index];
            if (window && window.overviewPhase !== "closed")
                return true;
        }
        return false;
    }

    function prepareOverviewAll() {
        shellRoot.forEachWindow(window => window.prepareOverview());
    }

    function cancelPreparedOverviewAll() {
        shellRoot.forEachWindow(window => window.cancelPreparedOverview());
    }

    function openOverviewAll() {
        shellRoot.forEachWindow(window => window.openOverview());
    }

    function closeOverviewAll() {
        shellRoot.forEachWindow(window => window.closeOverview());
    }

    function toggleOverviewAll() {
        if (shellRoot.anyOverviewOpen())
            shellRoot.closeOverviewAll();
        else
            shellRoot.openOverviewAll();
    }

    IpcHandler {
        target: "tide"

        function toggleAppLauncher() {
            shellRoot.forEachWindow(window => {
                if (!window || !window.islandContainerRef || window.hyprMonitor !== Hyprland.focusedMonitor)
                    return;
                const ic = window.islandContainerRef;
                if (ic.islandState === "app_launcher")
                    ic.smartRestoreState();
                else
                    ic.showAppLauncher();
            });
        }
        function showLockUnlock() {
            shellRoot.forEachWindow(window => {
                if (!window || !window.islandContainerRef)
                    return;
                window.islandContainerRef.showLockUnlock();
            });
        }
        function toggleWallpaperPicker() {
            shellRoot.forEachWindow(window => {
                if (!window || !window.islandContainerRef || window.hyprMonitor !== Hyprland.focusedMonitor)
                    return;
                const ic = window.islandContainerRef;
                if (ic.islandState === "wallpaper_picker")
                    ic.smartRestoreState();
                else
                    ic.showWallpaperPicker();
            });
        }
        function toggleAiTranslate() {
            shellRoot.forEachWindow(window => {
                if (!window || !window.islandContainerRef || window.hyprMonitor !== Hyprland.focusedMonitor)
                    return;
                const ic = window.islandContainerRef;
                if (ic.islandState === "ai_translate")
                    ic.smartRestoreState();
                else
                    ic.showAiTranslate();
            });
        }

        function toggleClipboardHistory() {
            shellRoot.forEachWindow(window => {
                if (!window || !window.islandContainerRef || window.hyprMonitor !== Hyprland.focusedMonitor)
                    return;
                const ic = window.islandContainerRef;
                if (ic.islandState === "clipboard_history")
                    ic.smartRestoreState();
                else
                    ic.showClipboardHistory();
            });
        }

        function togglePowerMenu() {
            shellRoot.forEachWindow(window => {
                if (!window || !window.islandContainerRef || window.hyprMonitor !== Hyprland.focusedMonitor)
                    return;
                const ic = window.islandContainerRef;
                if (ic.islandState === "power_menu")
                    ic.smartRestoreState();
                else
                    ic.showPowerMenu();
            });
        }

        function toggleControlCenter() {
            shellRoot.forEachWindow(window => {
                if (!window || !window.islandContainerRef || window.hyprMonitor !== Hyprland.focusedMonitor)
                    return;
                window.islandContainerRef.handleConfiguredClickAction("toggleControlCenter");
            });
        }

        function showLyrics() {
            shellRoot.forEachWindow(window => {
                if (!window || !window.islandContainerRef || window.hyprMonitor !== Hyprland.focusedMonitor)
                    return;
                window.islandContainerRef.showLyricsCapsule();
            });
        }

        function showCustom() {
            shellRoot.forEachWindow(window => {
                if (!window || !window.islandContainerRef || window.hyprMonitor !== Hyprland.focusedMonitor)
                    return;
                window.islandContainerRef.showCustomCapsule();
            });
        }

        function showClock() {
            shellRoot.forEachWindow(window => {
                if (!window || !window.islandContainerRef || window.hyprMonitor !== Hyprland.focusedMonitor)
                    return;
                window.islandContainerRef.showTimeCapsule();
            });
        }

        function togglePlayer() {
            shellRoot.forEachWindow(window => {
                if (!window || !window.islandContainerRef || window.hyprMonitor !== Hyprland.focusedMonitor)
                    return;
                window.islandContainerRef.handleConfiguredClickAction("toggleExpandedPlayer");
            });
        }

        function toggleAlcoveMusicCapsule() {
            shellRoot.forEachWindow(window => {
                if (!window || !window.islandContainerRef || window.hyprMonitor !== Hyprland.focusedMonitor)
                    return;
                window.islandContainerRef.toggleAlcoveMusicCapsule();
            });
        }
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
            shellRoot.forEachWindow(window => {
                if (window && window.prewarmWallpaperCache)
                    window.prewarmWallpaperCache();
            });
        }
    }

    GlobalShortcut {
        appid: userConfig.overviewGlobalShortcutAppid
        name: userConfig.overviewGlobalShortcutName

        onPressed: shellRoot.toggleOverviewAll()
    }

    Connections {
        target: Notifs
        function onNotificationAdded(notif) {
            if (Notifs.dndEnabled)
                return;

            const windows = panelVariants.instances ? panelVariants.instances : [];
            for (let i = 0; i < windows.length; i++) {
                const w = windows[i];
                if (w && w.islandContainerRef) {
                    const cc = w.islandContainerRef.controlCenterRef;
                    if (cc && cc.focusEnabled)
                        return;
                    break;
                }
            }

            shellRoot.showNotificationAll(notif.appName, notif.summary, notif.body);
        }
    }
    Component.onDestruction: {
        shuttingDown = true;
    }

    Component.onCompleted: {
        SystemServices.ensureSetupComplete(Quickshell.shellDir);
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
