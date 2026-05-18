import QtQuick
import Quickshell.Io
import IslandBackend

Item {
    id: root

    visible: false
    width: 0
    height: 0

    signal transientRequested(string icon, real progress, string text)

    property var statusIcons: ({})
    property var configuredLeftSwipeItems: []
    property string timeText: "00:00"
    property string dateText: "Mon, Jan 01"
    property int currentWorkspace: 1
    property bool customSwipeActive: false

    readonly property var configuredLeftSwipeIds: buildNormalizedSwipeItemIds(configuredLeftSwipeItems)
    readonly property bool usesSystemStatsModule: configuredLeftSwipeIds.indexOf("cpu") !== -1
        || configuredLeftSwipeIds.indexOf("ram") !== -1
    readonly property bool usesCavaModule: configuredLeftSwipeIds.indexOf("cava") !== -1
    readonly property bool hasCustomLeftItems: customLeftItems.length > 0

    property int batteryCapacity: SysBackend.batteryCapacity
    property bool isCharging: SysBackend.batteryStatus === "Charging" || SysBackend.batteryStatus === "Full"
    property real currentVolume: -1
    property bool isMuted: false
    property real currentBrightness: -1
    property real currentCpuUsage: -1
    property real currentRamUsage: -1
    property var cavaLevels: [0, 0, 0, 0, 0, 0, 0, 0]
    property var customLeftItems: []

    property real _lastCpuTotal: -1
    property real _lastCpuIdle: -1
    property string _lastChargeStatus: SysBackend.batteryStatus
    property string _pendingVolType: ""
    property real _pendingVolVal: 0.0
    property string _lastVolType: ""
    property real _lastVolVal: -1.0
    property bool _bluetoothVolumeSuppressed: false
    property real _pendingBrightnessValue: 0.0
    property string _customLeftItemsSignature: ""
    property bool _cavaRestartDelayActive: false

    onConfiguredLeftSwipeIdsChanged: {
        syncCustomLeftItems();
        refreshMissingValues();
    }
    onBatteryCapacityChanged: syncCustomLeftItems()
    onIsChargingChanged: syncCustomLeftItems()
    onCurrentVolumeChanged: syncCustomLeftItems()
    onIsMutedChanged: syncCustomLeftItems()
    onCurrentBrightnessChanged: syncCustomLeftItems()
    onCurrentCpuUsageChanged: syncCustomLeftItems()
    onCurrentRamUsageChanged: syncCustomLeftItems()
    onCurrentWorkspaceChanged: syncCustomLeftItems()
    onTimeTextChanged: syncCustomLeftItems()
    onDateTextChanged: syncCustomLeftItems()
    onStatusIconsChanged: syncCustomLeftItems()

    Component.onCompleted: {
        syncCustomLeftItems();
        refreshMissingValues();
    }

    Component.onDestruction: {
        cavaRestartTimer.stop();

        if (brightnessSnapshot.running) brightnessSnapshot.running = false;
        if (volumeSnapshot.running) volumeSnapshot.running = false;
        if (systemStatsSnapshot.running) systemStatsSnapshot.running = false;
        if (cavaMonitor.running) cavaMonitor.running = false;
    }

    function statusIcon(name) {
        if (!statusIcons)
            return "";
        const iconValue = statusIcons[name];
        return iconValue === undefined || iconValue === null ? "" : String(iconValue);
    }

    function normalizeSwipeItemId(rawId) {
        return String(rawId === undefined || rawId === null ? "" : rawId).trim().toLowerCase();
    }

    function formatPercentText(value) {
        return Math.round(Math.max(0, value) * 100) + "%";
    }

    function clamp01(value) {
        return Math.max(0, Math.min(1, value));
    }

    function brightnessStatusIcon(value) {
        if (value < 0.3) return statusIcon("brightnessLow");
        if (value < 0.7) return statusIcon("brightnessMedium");
        return statusIcon("brightnessHigh");
    }

    function applyBrightnessOutput(text) {
        const match = String(text === undefined || text === null ? "" : text).match(/,(\d+)%/);
        if (!match) return;
        currentBrightness = clamp01(parseInt(match[1], 10) / 100);
    }

    function applyVolumeOutput(text) {
        const source = String(text === undefined || text === null ? "" : text);
        const match = source.match(/([0-9]*\.?[0-9]+)/);
        if (match) currentVolume = clamp01(parseFloat(match[1]));
        isMuted = /\bMUTED\b/i.test(source);
    }

    function refreshMissingValues() {
        if (currentBrightness < 0 && !brightnessSnapshot.running)
            brightnessSnapshot.exec(["brightnessctl", "-m"]);
        if (currentVolume < 0 && !volumeSnapshot.running)
            volumeSnapshot.exec(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]);
        if (usesSystemStatsModule && !systemStatsSnapshot.running)
            systemStatsSnapshot.exec(systemStatsSnapshot.command);
    }

    function buildNormalizedSwipeItemIds(rawItems) {
        const source = Array.isArray(rawItems) ? rawItems : [];
        const resolved = [];
        const seen = {};

        for (let index = 0; index < source.length; index++) {
            const itemId = normalizeSwipeItemId(source[index]);
            if (itemId === "" || seen[itemId]) continue;
            seen[itemId] = true;
            resolved.push(itemId);
        }

        return resolved;
    }

    function applySystemStatsOutput(text) {
        const lines = String(text === undefined || text === null ? "" : text).trim().split(/\r?\n/);

        for (let index = 0; index < lines.length; index++) {
            const line = lines[index].trim();
            if (line === "") continue;

            const parts = line.split(/\s+/);
            if (parts[0] === "cpu" && parts.length >= 6) {
                let total = 0;
                for (let valueIndex = 1; valueIndex < parts.length; valueIndex++)
                    total += Number(parts[valueIndex]) || 0;

                const idle = (Number(parts[4]) || 0) + (Number(parts[5]) || 0);
                if (_lastCpuTotal >= 0 && _lastCpuIdle >= 0 && total > _lastCpuTotal) {
                    const totalDiff = total - _lastCpuTotal;
                    const idleDiff = idle - _lastCpuIdle;
                    currentCpuUsage = totalDiff > 0 ? clamp01((totalDiff - idleDiff) / totalDiff) : 0;
                } else {
                    currentCpuUsage = currentCpuUsage >= 0 ? currentCpuUsage : 0;
                }

                _lastCpuTotal = total;
                _lastCpuIdle = idle;
                continue;
            }

            if (parts[0] === "mem" && parts.length >= 3) {
                const totalMem = Number(parts[1]) || 0;
                const availableMem = Number(parts[2]) || 0;
                if (totalMem > 0) currentRamUsage = clamp01((totalMem - availableMem) / totalMem);
            }
        }
    }

    function applyCavaOutput(line) {
        const values = String(line === undefined || line === null ? "" : line).split(";");
        if (values.length < 8) return;

        const nextLevels = [
            clamp01((Number(values[0]) || 0) / 7.0),
            clamp01((Number(values[1]) || 0) / 7.0),
            clamp01((Number(values[2]) || 0) / 7.0),
            clamp01((Number(values[3]) || 0) / 7.0),
            clamp01((Number(values[4]) || 0) / 7.0),
            clamp01((Number(values[5]) || 0) / 7.0),
            clamp01((Number(values[6]) || 0) / 7.0),
            clamp01((Number(values[7]) || 0) / 7.0)
        ];

        const previousLevels = Array.isArray(cavaLevels) ? cavaLevels : [];
        let changed = previousLevels.length !== nextLevels.length;
        for (let index = 0; !changed && index < nextLevels.length; index++)
            changed = Math.abs((Number(previousLevels[index]) || 0) - nextLevels[index]) >= 0.03;

        if (changed)
            cavaLevels = nextLevels;
    }

    function buildCustomSwipeItem(itemId) {
        switch (itemId) {
        case "time":
            return { id: itemId, icon: "", text: timeText };
        case "date":
            return { id: itemId, icon: "", text: dateText };
        case "battery":
            if (batteryCapacity < 0) return null;
            return {
                id: itemId,
                kind: "battery",
                level: Math.max(0, Math.min(100, batteryCapacity)),
                isCharging: isCharging,
                icon: "",
                text: Math.max(0, batteryCapacity) + "%"
            };
        case "volume":
            if (currentVolume < 0) return null;
            return {
                id: itemId,
                icon: isMuted ? statusIcon("mute") : statusIcon("volume"),
                text: formatPercentText(currentVolume)
            };
        case "brightness":
            if (currentBrightness < 0) return null;
            return {
                id: itemId,
                icon: brightnessStatusIcon(currentBrightness),
                text: formatPercentText(currentBrightness)
            };
        case "workspace":
            return { id: itemId, icon: "", text: "Workspace " + currentWorkspace };
        case "cpu":
            if (currentCpuUsage < 0) return null;
            return {
                id: itemId,
                icon: statusIcon("cpu"),
                text: formatPercentText(currentCpuUsage)
            };
        case "ram":
            if (currentRamUsage < 0) return null;
            return {
                id: itemId,
                icon: statusIcon("ram"),
                text: formatPercentText(currentRamUsage)
            };
        case "cava":
            return { id: itemId, kind: "cava" };
        default:
            return null;
        }
    }

    function buildCustomSwipeItems(itemIds) {
        const source = Array.isArray(itemIds) ? itemIds : [];
        const resolved = [];

        for (let index = 0; index < source.length; index++) {
            const itemId = String(source[index] || "");
            if (itemId === "") continue;

            const nextItem = buildCustomSwipeItem(itemId);
            if (nextItem) resolved.push(nextItem);
        }

        return resolved;
    }

    function customSwipeItemsSignature(items) {
        const source = Array.isArray(items) ? items : [];
        let signature = "";

        for (let index = 0; index < source.length; index++) {
            const item = source[index] || {};
            signature += String(item.id || "")
                + "\u001f" + String(item.kind || "")
                + "\u001f" + String(item.icon || "")
                + "\u001f" + String(item.text || "")
                + "\u001f" + String(item.level === undefined ? "" : item.level)
                + "\u001f" + String(item.isCharging === undefined ? "" : item.isCharging)
                + "\u001e";
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
            if (root._bluetoothVolumeSuppressed) return;
            if (root._pendingVolType !== root._lastVolType
                    || Math.abs(root._pendingVolVal - root._lastVolVal) > 0.001) {
                root._lastVolType = root._pendingVolType;
                root._lastVolVal = root._pendingVolVal;
                root.transientRequested(
                    root._pendingVolType === "MUTE" ? root.statusIcon("mute") : root.statusIcon("volume"),
                    root._pendingVolVal,
                    ""
                );
            }
        }
    }

    Timer {
        id: brightnessDebounce

        interval: 16

        onTriggered: root.transientRequested(
            root.brightnessStatusIcon(root._pendingBrightnessValue),
            root._pendingBrightnessValue,
            ""
        )
    }

    Process {
        id: brightnessSnapshot

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.applyBrightnessOutput(text)
        }
    }

    Process {
        id: volumeSnapshot

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.applyVolumeOutput(text)
        }
    }

    Process {
        id: systemStatsSnapshot

        command: [
            "sh",
            "-lc",
            "awk 'NR == 1 { print \"cpu\", $2, $3, $4, $5, $6, $7, $8, $9, $10 } $1 == \"MemTotal:\" { total = $2 } $1 == \"MemAvailable:\" { available = $2 } END { print \"mem\", total, available }' /proc/stat /proc/meminfo"
        ]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.applySystemStatsOutput(text)
        }
    }

    Timer {
        id: systemStatsPollTimer

        interval: 3000
        repeat: true
        running: root.usesSystemStatsModule && root.customSwipeActive
        triggeredOnStart: true

        onTriggered: {
            if (!systemStatsSnapshot.running)
                systemStatsSnapshot.exec(systemStatsSnapshot.command);
        }
    }

    Timer {
        id: cavaRestartTimer

        interval: 1200
        repeat: false

        onTriggered: root._cavaRestartDelayActive = false
    }

    Process {
        id: cavaMonitor

        running: root.usesCavaModule && root.customSwipeActive && !root._cavaRestartDelayActive
        command: [
            "sh",
            "-lc",
            "exec cava -p /dev/stdin <<'EOF'\n[general]\nframerate = 30\nbars = 8\nautosens = 1\n[output]\nmethod = raw\nraw_target = /dev/stdout\ndata_format = ascii\nascii_max_range = 7\nchannels = mono\nEOF"
        ]

        stdout: SplitParser {
            splitMarker: "\n"

            onRead: function(data) {
                root.applyCavaOutput(data);
            }
        }

        onExited: {
            if (root.usesCavaModule && root.customSwipeActive) {
                root._cavaRestartDelayActive = true;
                cavaRestartTimer.restart();
            }
        }
    }

    Connections {
        target: SysBackend

        function onVolumeChanged(volPercentage, isMuted) {
            const nextVolType = isMuted ? "MUTE" : "VOL";
            const nextVolValue = root.clamp01(volPercentage / 100.0);
            const unchanged = root.isMuted === isMuted
                && Math.abs(root.currentVolume - nextVolValue) <= 0.001
                && root._pendingVolType === nextVolType
                && Math.abs(root._pendingVolVal - nextVolValue) <= 0.001;

            if (unchanged)
                return;

            root._pendingVolType = nextVolType;
            root._pendingVolVal = nextVolValue;
            root.currentVolume = nextVolValue;
            root.isMuted = isMuted;
            volumeDebounce.restart();
        }

        function onBatteryChanged(capacity, statusString) {
            root.batteryCapacity = capacity;
            root.isCharging = (statusString === "Charging" || statusString === "Full");
            if (root._lastChargeStatus !== "" && root._lastChargeStatus !== statusString) {
                if (statusString === "Charging")
                    root.transientRequested(root.statusIcon("charging"), -1.0, "");
                else if (statusString === "Discharging")
                    root.transientRequested(root.statusIcon("discharging"), -1.0, "");
            }
            root._lastChargeStatus = statusString;
        }

        function onBrightnessChanged(value) {
            root._pendingBrightnessValue = value;
            root.currentBrightness = value;
            brightnessDebounce.restart();
        }

        function onCapsLockChanged(isOn) {
            root.transientRequested(
                isOn ? root.statusIcon("capsLockOn") : root.statusIcon("capsLockOff"),
                -1.0,
                isOn ? "Caps Lock ON" : "Caps Lock OFF"
            );
        }

        function onBluetoothChanged(isConnected) {
            root._bluetoothVolumeSuppressed = true;
            bluetoothVolumeSuppressionTimer.restart();
            if (isConnected)
                return;

            root.transientRequested(root.statusIcon("bluetooth"), -1.0, "Disconnected");
        }
    }
}
