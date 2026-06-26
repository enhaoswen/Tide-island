import QtQuick
import Quickshell.Hyprland
import Quickshell.Io
import IslandBackend

Item {
    id: root

    visible: false
    width: 0
    height: 0

    signal transientRequested(string icon, real progress, string text)

    property var configuredLeftSwipeItems: []
    property string timeText: "00:00"
    property string dateText: "Mon, Jan 01"
    property int currentWorkspace: 1
    property bool customSwipeActive: false
    property bool musicActive: false
    property real _ramTotalGb: 0
    property real _ramUsedGb: 0
    property var _notifiedMilestones: ({})
    property bool _criticalBatteryActive: false

    signal criticalBatteryRequested(string icon, real progress, string text)

    readonly property var configuredLeftSwipeIds: buildNormalizedSwipeItemIds(configuredLeftSwipeItems)
    readonly property bool usesSystemStatsModule: configuredLeftSwipeIds.indexOf("cpu") !== -1 || configuredLeftSwipeIds.indexOf("ram") !== -1
    readonly property bool usesCavaModule: configuredLeftSwipeIds.indexOf("cava") !== -1
    readonly property bool hasCustomLeftItems: customLeftItems.length > 0
    readonly property string systemServicesClientId: "island-system-state-" + Math.random().toString(36).slice(2)
    readonly property string defaultStatusIcon: "\ud83c\udfa7"
    readonly property string volumeStatusIcon: "\u{F057E}"
    readonly property string muteStatusIcon: "\u{F075F}"
    readonly property string brightnessLowStatusIcon: "\u{F00DE}"
    readonly property string brightnessMediumStatusIcon: "\u{F00DF}"
    readonly property string brightnessHighStatusIcon: "\u{F00E0}"
    readonly property string chargingStatusIcon: "\uf0e7"
    readonly property string dischargingStatusIcon: "\uf244"
    readonly property string cpuStatusIcon: "\u{F035B}"
    readonly property string ramStatusIcon: "\u{F061A}"
    readonly property string bluetoothStatusIcon: "\u{F02CB}"

    property int batteryCapacity: SysBackend.batteryCapacity
    property bool isCharging: false
    property bool _lowBatteryNotified: false
    property real currentVolume: -1
    property bool isMuted: false
    property real currentBrightness: -1
    property real currentCpuUsage: -1
    property real currentRamUsage: -1
    property string currentActiveApp: ""
    property var cavaLevels: [0, 0, 0, 0, 0, 0, 0, 0]
    property var customLeftItems: []

    property string _lastChargeStatus: ""
    property real _lastChargeNotificationTime: 0
    property string _pendingVolType: ""
    property real _pendingVolVal: 0.0
    property string _lastVolType: ""
    property real _lastVolVal: -1.0
    property bool _bluetoothVolumeSuppressed: false
    property real _pendingBrightnessValue: 0.0
    property string _customLeftItemsSignature: ""
    property string _memInfoBuffer: ""

    onConfiguredLeftSwipeIdsChanged: {
        syncCustomLeftItems();
        refreshMissingValues();
        updateCavaSubscription();
    }
    onUsesCavaModuleChanged: updateCavaSubscription()
    onCustomSwipeActiveChanged: updateCavaSubscription()
    onMusicActiveChanged: updateCavaSubscription()
    onBatteryCapacityChanged: syncCustomLeftItems()
    onIsChargingChanged: syncCustomLeftItems()
    onCurrentVolumeChanged: syncCustomLeftItems()
    onIsMutedChanged: syncCustomLeftItems()
    onCurrentBrightnessChanged: syncCustomLeftItems()
    onCurrentCpuUsageChanged: syncCustomLeftItems()
    onCurrentRamUsageChanged: syncCustomLeftItems()
    onCurrentActiveAppChanged: syncCustomLeftItems()
    onCurrentWorkspaceChanged: syncCustomLeftItems()
    onTimeTextChanged: syncCustomLeftItems()
    onDateTextChanged: syncCustomLeftItems()

    Component.onCompleted: {
        const initDirection = (SysBackend.batteryStatus === "Charging" || SysBackend.batteryStatus === "Full") ? "charging" : "discharging";
        root.isCharging = (initDirection === "charging");
        root._lastChargeStatus = initDirection;
        root._lastChargeNotificationTime = Date.now();
        syncCustomLeftItems();
        refreshMissingValues();
        updateCavaSubscription();
    }
    Component.onDestruction: {
        SystemServices.setCavaClientActive(systemServicesClientId, false);
    }

    FileView {
        id: memInfoView
        path: "/proc/meminfo"
        watchChanges: false
        preload: false
        printErrors: false

        onTextChanged: {
            const text = memInfoView.text();
            if (!text || text === "")
                return;
            const lines = text.split("\n");
            let total = 0, available = 0;
            for (let i = 0; i < lines.length; i++) {
                if (lines[i].startsWith("MemTotal:")) {
                    const parts = lines[i].split(/\s+/);
                    if (parts.length >= 2)
                        total = parseInt(parts[1]);
                } else if (lines[i].startsWith("MemAvailable:")) {
                    const parts = lines[i].split(/\s+/);
                    if (parts.length >= 2)
                        available = parseInt(parts[1]);
                }
            }
            if (total > 0) {
                root.currentRamUsage = root.clamp01((total - available) / total);
                root._ramTotalGb = total / (1024 * 1024);
                root._ramUsedGb = (total - available) / (1024 * 1024);
            }
        }
    }

    Timer {
        id: ramPollTimer
        interval: 1000
        repeat: true
        running: root.usesSystemStatsModule
        triggeredOnStart: true
        onTriggered: memInfoView.reload()
    }

    function statusIcon(name) {
        switch (name) {
        case "default":
            return defaultStatusIcon;
        case "volume":
            return volumeStatusIcon;
        case "mute":
            return muteStatusIcon;
        case "brightnessLow":
            return brightnessLowStatusIcon;
        case "brightnessMedium":
            return brightnessMediumStatusIcon;
        case "brightnessHigh":
            return brightnessHighStatusIcon;
        case "charging":
            return chargingStatusIcon;
        case "discharging":
            return dischargingStatusIcon;
        case "cpu":
            return cpuStatusIcon;
        case "ram":
            return ramStatusIcon;
        case "bluetooth":
            return bluetoothStatusIcon;
        default:
            return "";
        }
    }

    function normalizeSwipeItemId(rawId) {
        return String(rawId === undefined || rawId === null ? "" : rawId).trim().toLowerCase();
    }

    function listValues(rawItems) {
        if (!rawItems)
            return [];
        if (Array.isArray(rawItems))
            return rawItems;
        const length = Number(rawItems.length);
        if (!isFinite(length) || length < 0)
            return [];
        const resolved = [];
        for (let index = 0; index < Math.floor(length); index++)
            resolved.push(rawItems[index]);
        return resolved;
    }

    function formatPercentText(value) {
        return Math.round(Math.max(0, value) * 100) + "%";
    }

    function clamp01(value) {
        return Math.max(0, Math.min(1, value));
    }

    function brightnessStatusIcon(value) {
        if (value < 0.3)
            return statusIcon("brightnessLow");
        if (value < 0.7)
            return statusIcon("brightnessMedium");
        return statusIcon("brightnessHigh");
    }

    function refreshMissingValues() {
        if (currentBrightness < 0)
            SystemServices.requestBrightness();
        if (currentVolume < 0)
            SystemServices.requestVolume();
        if (usesSystemStatsModule)
            SystemServices.requestSystemStats();
    }

    function updateCavaSubscription() {
        const active = musicActive || (usesCavaModule && customSwipeActive);
        SystemServices.setCavaClientActive(systemServicesClientId, active);
        if (active)
            cavaLevels = SystemServices.cavaLevels;
    }

    function buildNormalizedSwipeItemIds(rawItems) {
        const source = listValues(rawItems);
        const resolved = [];
        const seen = {};
        for (let index = 0; index < source.length; index++) {
            const itemId = normalizeSwipeItemId(source[index]);
            if (itemId === "" || seen[itemId])
                continue;
            seen[itemId] = true;
            resolved.push(itemId);
        }
        return resolved;
    }

    function resolveApp(cls) {
        const lower = cls.toLowerCase();
        const base = "/home/latif/.local/share/icons/MacTahoe/apps/scalable/";
        switch (lower) {
        case "org.gnome.nautilus":
            return {
                name: "Files",
                icon: base + "org.gnome.files.svg",
                iconKind: "theme"
            };
        case "brave-browser":
        case "brave":
            return {
                name: "Brave",
                icon: base + "brave-desktop.svg",
                iconKind: "theme"
            };
        case "code":
        case "com.visualstudio.code-oss":
            return {
                name: " VS Code",
                icon: base + "com.visualstudio.code.svg",
                iconKind: "theme"
            };
        case "pinentry-gtk":
            return {
                name: " Password",
                icon: base + "dialog-password.svg",
                iconKind: "theme"
            };
        case "nvim":
        case "neovim":
            return {
                name: "Neovim",
                icon: base + "neovim.svg",
                iconKind: "theme"
            };
        case "com.obsproject.studio":
            return {
                name: " OBS",
                icon: base + "com.obsproject.Studio.svg",
                iconKind: "theme"
            };
        case "org.gnome.calculator":
            return {
                name: " Calculator",
                icon: base + "calc.svg",
                iconKind: "theme"
            };
        case "com.gabm.satty":
            return {
                name: " Satty",
                icon: base + "accessories-camera.svg",
                iconKind: "theme"
            };
        case "org.gnome.texteditor":
            return {
                name: "Text Editor",
                icon: base + "text-editor.svg",
                iconKind: "theme"
            };
        case "localsend":
            return {
                name: "LocalSend",
                icon: base + "localsend.svg",
                iconKind: "theme"
            };
        case "nwg-look":
            return {
                name: " GTK-Settings",
                icon: base + "nwg-look.svg",
                iconKind: "theme"
            };
        case "com.stremio.stremio":
            return {
                name: "Stremio",
                icon: base + "com.stremio.Stremio.svg",
                iconKind: "theme"
            };
        case "kitty":
            return {
                name: "Kitty",
                icon: base + "kitty.svg",
                iconKind: "theme"
            };
        case "discord":
            return {
                name: "Discord",
                icon: base + "discord.svg",
                iconKind: "theme"
            };
        case "spotify":
            return {
                name: "Spotify",
                icon: base + "spotify.svg",
                iconKind: "theme"
            };
        case "obsidian":
            return {
                name: "Obsidian",
                icon: base + "obsidian.svg",
                iconKind: "theme"
            };
        default:
            return {
                name: lower.charAt(0).toUpperCase() + lower.slice(1),
                icon: "\u{F0315}",
                iconKind: "glyph"
            };
        }
    }

    function buildCustomSwipeItem(itemId) {
        switch (itemId) {
        case "time":
            return {
                id: itemId,
                icon: "",
                iconKind: "glyph",
                text: timeText
            };
        case "date":
            return {
                id: itemId,
                icon: "",
                iconKind: "glyph",
                text: dateText
            };
        case "battery":
            if (batteryCapacity < 0)
                return null;
            return {
                id: itemId,
                kind: "battery",
                level: Math.max(0, Math.min(100, batteryCapacity)),
                isCharging: isCharging,
                icon: "",
                iconKind: "glyph",
                text: Math.max(0, batteryCapacity) + "%"
            };
        case "volume":
            if (currentVolume < 0)
                return null;
            return {
                id: itemId,
                icon: isMuted ? statusIcon("mute") : statusIcon("volume"),
                iconKind: "glyph",
                text: formatPercentText(currentVolume)
            };
        case "brightness":
            if (currentBrightness < 0)
                return null;
            return {
                id: itemId,
                icon: brightnessStatusIcon(currentBrightness),
                iconKind: "glyph",
                text: formatPercentText(currentBrightness)
            };
        case "workspace":
            return {
                id: itemId,
                icon: "",
                iconKind: "glyph",
                text: "Workspace " + currentWorkspace
            };
        case "app":
            if (currentActiveApp === "")
                return null;
            const appInfo = resolveApp(currentActiveApp);
            return {
                id: itemId,
                icon: appInfo.icon,
                iconKind: appInfo.iconKind,
                text: appInfo.name
            };
        case "cpu":
            if (currentCpuUsage < 0)
                return null;
            return {
                id: itemId,
                icon: statusIcon("cpu"),
                iconKind: "glyph",
                text: formatPercentText(currentCpuUsage)
            };
        case "ram":
            if (currentRamUsage < 0)
                return null;
            return {
                id: itemId,
                icon: statusIcon("ram"),
                iconKind: "glyph",
                text: _ramUsedGb.toFixed(1) + "/" + _ramTotalGb.toFixed(0) + "GB"
            };
        case "cava":
            return {
                id: itemId,
                kind: "cava"
            };
        default:
            return null;
        }
    }

    function buildCustomSwipeItems(itemIds) {
        const source = listValues(itemIds);
        const resolved = [];
        for (let index = 0; index < source.length; index++) {
            const itemId = String(source[index] || "");
            if (itemId === "")
                continue;
            const nextItem = buildCustomSwipeItem(itemId);
            if (nextItem)
                resolved.push(nextItem);
        }
        return resolved;
    }

    function customSwipeItemsSignature(items) {
        const source = listValues(items);
        let signature = "";
        for (let index = 0; index < source.length; index++) {
            const item = source[index] || {};
            signature += String(item.id || "") + "\u001f" + String(item.kind || "") + "\u001f" + String(item.icon || "") + "\u001f" + String(item.iconKind || "") + "\u001f" + String(item.text || "") + "\u001f" + String(item.level === undefined ? "" : item.level) + "\u001f" + String(item.isCharging === undefined ? "" : item.isCharging) + "\u001e";
        }
        return signature;
    }

    function syncCustomLeftItems() {
        const nextItems = buildCustomSwipeItems(configuredLeftSwipeIds);
        const nextSignature = customSwipeItemsSignature(nextItems);
        if (nextSignature === _customLeftItemsSignature)
            return;
        _customLeftItemsSignature = nextSignature;
        customLeftItems = nextItems;
    }

    Timer {
        id: bluetoothVolumeSuppressionTimer
        interval: 2000
        onTriggered: root._bluetoothVolumeSuppressed = false
    }

    Timer {
        id: volumeDebounce
        interval: 16
        onTriggered: {
            if (root._bluetoothVolumeSuppressed)
                return;
            if (root._pendingVolType !== root._lastVolType || Math.abs(root._pendingVolVal - root._lastVolVal) > 0.001) {
                root._lastVolType = root._pendingVolType;
                root._lastVolVal = root._pendingVolVal;
                root.transientRequested(root._pendingVolType === "MUTE" ? root.statusIcon("mute") : root.statusIcon("volume"), root._pendingVolVal, "");
            }
        }
    }

    Timer {
        id: chargeNotificationDebounce
        interval: 2000
        repeat: false
        property string pendingStatus: ""
        onTriggered: {
            if (pendingStatus === root._lastChargeStatus)
                return;
            root._lastChargeStatus = pendingStatus;
            root.isCharging = (pendingStatus === "charging");
            if (pendingStatus === "charging") {
                root._lowBatteryNotified = false;
                root.transientRequested("\uf0e7", -1.0, "Charger connected");
            } else if (pendingStatus === "discharging") {
                root.transientRequested("\uf244", -1.0, "Charger disconnected");
            }
        }
    }

    Timer {
        id: brightnessDebounce
        interval: 16
        onTriggered: root.transientRequested(root.brightnessStatusIcon(root._pendingBrightnessValue), root._pendingBrightnessValue, "")
    }

    Timer {
        id: systemStatsPollTimer
        interval: 1000
        repeat: true
        running: root.usesSystemStatsModule
        triggeredOnStart: true
        onTriggered: SystemServices.requestSystemStats()
    }

    Connections {
        target: SystemServices

        function onBrightnessSnapshotReady(value, errorString) {
            if (errorString === "" && value >= 0)
                root.currentBrightness = root.clamp01(value);
        }

        function onVolumeSnapshotReady(value, muted, errorString) {
            if (errorString !== "" || value < 0)
                return;
            root.currentVolume = root.clamp01(value);
            root.isMuted = muted;
        }

        function onSystemStatsReady(cpuUsage, ramUsage, errorString) {
            if (errorString !== "")
                return;
            if (cpuUsage >= 0)
                root.currentCpuUsage = root.clamp01(cpuUsage);
        }

        function onCavaLevelsChanged() {
            root.cavaLevels = SystemServices.cavaLevels;
        }
    }

    Connections {
        target: SysBackend

        function onVolumeChanged(volPercentage, isMuted) {
            const nextVolType = isMuted ? "MUTE" : "VOL";
            const nextVolValue = root.clamp01(volPercentage / 100.0);
            const unchanged = root.isMuted === isMuted && Math.abs(root.currentVolume - nextVolValue) <= 0.001 && root._pendingVolType === nextVolType && Math.abs(root._pendingVolVal - nextVolValue) <= 0.001;
            if (unchanged)
                return;
            root._pendingVolType = nextVolType;
            root._pendingVolVal = nextVolValue;
            root.currentVolume = nextVolValue;
            root.isMuted = isMuted;
            volumeDebounce.restart();
        }

        function onBatteryChanged(capacity, statusString) {
            console.log("Battery:", capacity, statusString);

            root.batteryCapacity = capacity;

            const direction = (statusString === "Charging" || statusString === "Full") ? "charging" : "discharging";

            if (direction !== chargeNotificationDebounce.pendingStatus) {
                chargeNotificationDebounce.pendingStatus = direction;
                chargeNotificationDebounce.restart();
            }

            if (direction === "charging") {
                root._lowBatteryNotified = false;
                root._criticalBatteryActive = false;
                return;
            }

            const milestones = [25, 20, 15, 10];
            for (const m of milestones) {
                if (capacity <= m && !root._notifiedMilestones[m]) {
                    root._notifiedMilestones = Object.assign({}, root._notifiedMilestones, {
                        [m]: true
                    });
                    root.transientRequested("\uf244", capacity / 100.0, "Battery at " + m + "%");
                    break;
                }
            }

            if (capacity <= 10) {
                root._criticalBatteryActive = true;
                root.criticalBatteryRequested("\uf244", capacity / 100.0, "Battery critically low — " + capacity + "%");
            }
        }

        function onBrightnessChanged(value) {
            root._pendingBrightnessValue = value;
            root.currentBrightness = value;
            brightnessDebounce.restart();
        }

        function onBluetoothChanged(isConnected) {
            root._bluetoothVolumeSuppressed = true;
            bluetoothVolumeSuppressionTimer.restart();
            if (isConnected)
                return;
            root.transientRequested(root.statusIcon("bluetooth"), -1.0, "Disconnected");
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (!event)
                return;
            if (event.name === "activewindow") {
                const args = event.parse(2);
                if (args.length >= 1) {
                    const cls = String(args[0] || "").trim();
                    if (cls !== "" && cls !== root.currentActiveApp)
                        root.currentActiveApp = cls.toLowerCase();
                }
            }
        }
    }
}
