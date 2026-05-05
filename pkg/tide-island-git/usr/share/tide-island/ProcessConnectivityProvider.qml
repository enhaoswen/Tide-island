import QtQuick
import Quickshell.Io

Item {
    id: root

    signal connectivityPanelRequested(string kind, bool open)

    property bool active: false
    property bool wifiPanelOpen: false
    property bool bluetoothPanelOpen: false

    property bool wifiSupported: true
    property bool wifiReadOnly: false
    property bool wifiAvailable: false
    property bool wifiEnabled: false
    property bool wifiBusy: false
    property bool wifiListRunning: false
    property string wifiCurrentSsid: ""
    property string wifiStatusText: wifiSupported ? (wifiEnabled ? (wifiCurrentSsid !== "" ? wifiCurrentSsid : "On") : "Off") : "Unavailable"
    property string wifiLocalInfoMessage: ""
    property string wifiLocalError: ""
    property string wifiUnsupportedReason: ""
    property string wifiPendingPasswordSsid: ""
    property string wifiPendingPasswordValue: ""
    property var wifiNetworks: []
    property var savedWifiConnections: ({})
    readonly property string wifiInfoMessage: wifiLocalInfoMessage
    readonly property string wifiError: wifiLocalError
    readonly property string wifiAvailabilityMessage: {
        if (wifiUnsupportedReason.length > 0) return wifiUnsupportedReason;
        if (wifiSupported && !wifiAvailable) return "No Wi-Fi device is available.";
        return "";
    }

    property bool bluetoothAvailable: false
    property bool bluetoothEnabled: false
    property bool bluetoothBusy: false
    property bool bluetoothListRunning: false
    property string bluetoothInfoMessage: ""
    property string bluetoothError: ""
    property string bluetoothPairAndConnectPath: ""
    property string bluetoothPendingSecretValue: ""
    property var bluetoothDeviceValues: []
    readonly property bool bluetoothPairingActive: false
    readonly property bool bluetoothPairingRequiresInput: false
    readonly property bool bluetoothPairingNumericInput: false
    readonly property bool bluetoothPairingRequiresConfirmation: false
    readonly property string bluetoothPairingTitle: ""
    readonly property string bluetoothPairingMessage: ""
    readonly property string bluetoothPairingDisplayedCode: ""
    readonly property string bluetoothStatusText: buildBluetoothStatusText()
    readonly property string bluetoothAvailabilityMessage: bluetoothAvailable ? "" : "No Bluetooth adapter is available."

    readonly property bool hasConnectivityPrompt: wifiPendingPasswordSsid.length > 0 || bluetoothPairingActive
    readonly property bool anyConnectivityPanelOpen: wifiPanelOpen || bluetoothPanelOpen
    readonly property string wifiGlyph: ""
    readonly property string bluetoothGlyph: ""
    readonly property string nmcliPath: "/usr/bin/nmcli"
    readonly property string bluetoothctlPath: "/usr/bin/bluetoothctl"

    visible: false
    width: 0
    height: 0

    function trimString(value) {
        if (value === undefined || value === null) return "";
        return String(value).trim();
    }

    function parseNmcliFields(line) {
        const fields = [];
        let current = "";
        let escaped = false;
        const source = String(line === undefined || line === null ? "" : line);

        for (let index = 0; index < source.length; index++) {
            const character = source[index];
            if (escaped) {
                current += character;
                escaped = false;
                continue;
            }

            if (character === "\\") {
                escaped = true;
                continue;
            }

            if (character === ":") {
                fields.push(current);
                current = "";
                continue;
            }

            current += character;
        }

        fields.push(current);
        return fields;
    }

    function splitLines(text) {
        const source = String(text === undefined || text === null ? "" : text).trim();
        return source === "" ? [] : source.split(/\r?\n/);
    }

    function clearWifiPrompt() {
        wifiPendingPasswordSsid = "";
        wifiPendingPasswordValue = "";
        wifiLocalInfoMessage = "";
        wifiLocalError = "";
    }

    function clearWifiMessages() {
        wifiLocalInfoMessage = "";
        wifiLocalError = "";
    }

    function clearBluetoothMessages() {
        bluetoothInfoMessage = "";
        bluetoothError = "";
    }

    function clearBluetoothPrompt() {
        bluetoothPairAndConnectPath = "";
        bluetoothPendingSecretValue = "";
    }

    function submitBluetoothPairingSecret() {
        bluetoothError = "PIN/passkey pairing is not kept resident in this lightweight panel. Use bluetoothctl for this device.";
        bluetoothPendingSecretValue = "";
    }

    function confirmBluetoothPairing() {
        bluetoothError = "Confirmation pairing is not kept resident in this lightweight panel. Use bluetoothctl for this device.";
    }

    function cancelBluetoothPairing() {
        clearBluetoothPrompt();
    }

    function isConnectivityPanelOpen(kind) {
        if (kind === "wifi") return wifiPanelOpen;
        if (kind === "bluetooth") return bluetoothPanelOpen;
        return false;
    }

    function setConnectivityPanelOpen(kind, open, emitSignal) {
        if (emitSignal === undefined)
            emitSignal = true;

        const nextOpen = !!open;
        let changed = false;

        if (kind === "wifi") {
            changed = wifiPanelOpen !== nextOpen;
            wifiPanelOpen = nextOpen;

            if (nextOpen) {
                refreshWifiState();
                if (wifiEnabled)
                    refreshWifiNetworks(true);
            } else {
                stopWifiScan();
                wifiNetworks = [];
                clearWifiPrompt();
                clearWifiMessages();
            }
        } else if (kind === "bluetooth") {
            changed = bluetoothPanelOpen !== nextOpen;
            bluetoothPanelOpen = nextOpen;

            if (nextOpen) {
                refreshBluetoothState();
            } else {
                stopBluetoothScan();
                bluetoothDeviceValues = [];
                clearBluetoothPrompt();
                clearBluetoothMessages();
            }
        } else {
            return;
        }

        if (changed && emitSignal)
            connectivityPanelRequested(kind, nextOpen);
    }

    function toggleConnectivityOverlay(kind) {
        setConnectivityPanelOpen(kind, !isConnectivityPanelOpen(kind));
    }

    function closeConnectivityPanels(emitSignals) {
        if (emitSignals === undefined)
            emitSignals = true;

        setConnectivityPanelOpen("wifi", false, emitSignals);
        setConnectivityPanelOpen("bluetooth", false, emitSignals);
        clearWifiPrompt();
        clearWifiMessages();
        clearBluetoothPrompt();
        clearBluetoothMessages();
    }

    function refreshState() {
        if (!active) return;
        refreshWifiState();
        refreshBluetoothState();
    }

    function refreshWifiState() {
        if (!active || wifiStateProcess.running)
            return;
        wifiStateProcess.exec([nmcliPath, "-t", "-f", "WIFI", "general", "status"]);
    }

    function requestWifiStateRefresh() {
        refreshWifiState();
    }

    function refreshWifiConnections() {
        if (!active || wifiConnectionsProcess.running)
            return;
        wifiConnectionsProcess.exec([nmcliPath, "-t", "-e", "yes", "-f", "NAME,TYPE", "connection", "show"]);
    }

    function requestWifiListRefresh(rescan) {
        refreshWifiNetworks(rescan);
    }

    function refreshWifiNetworks(rescan) {
        if (!active || !wifiSupported || !wifiAvailable || !wifiEnabled)
            return;
        if (wifiListProcess.running)
            return;

        wifiListRunning = true;
        refreshWifiConnections();
        wifiListProcess.exec([
            nmcliPath,
            "-t",
            "-e",
            "yes",
            "-f",
            "ACTIVE,SSID,SECURITY,SIGNAL",
            "device",
            "wifi",
            "list",
            "--rescan",
            rescan ? "yes" : "no"
        ]);
    }

    function stopWifiScan() {
        wifiListRunning = false;
        if (wifiListProcess.running)
            wifiListProcess.running = false;
    }

    function toggleWifiEnabled() {
        clearWifiPrompt();
        clearWifiMessages();
        runWifiCommand([nmcliPath, "radio", "wifi", wifiEnabled ? "off" : "on"],
            wifiEnabled ? "Turning Wi-Fi off..." : "Turning Wi-Fi on...");
    }

    function disconnectWifi() {
        if (!wifiSupported || !wifiAvailable) {
            wifiLocalError = wifiAvailabilityMessage.length > 0 ? wifiAvailabilityMessage : "No Wi-Fi device is available.";
            return;
        }

        clearWifiPrompt();
        clearWifiMessages();
        if (wifiCurrentSsid.length > 0) {
            runWifiCommand([nmcliPath, "connection", "down", "id", wifiCurrentSsid], "Disconnecting " + wifiCurrentSsid + "...");
        }
    }

    function connectWifiNetwork(network) {
        if (!network) return;
        if (!wifiSupported) {
            wifiLocalError = wifiAvailabilityMessage.length > 0 ? wifiAvailabilityMessage : "Wi-Fi control is unavailable.";
            return;
        }
        if (!wifiAvailable) {
            wifiLocalError = wifiAvailabilityMessage.length > 0 ? wifiAvailabilityMessage : "No Wi-Fi device is available.";
            return;
        }
        if (!wifiEnabled) {
            wifiLocalError = "Turn on Wi-Fi first.";
            return;
        }
        if (network.connected) return;

        const ssid = trimString(network.ssid);
        const networkType = trimString(network.type).toLowerCase();
        const secure = !!network.secure;
        const savedConnection = !!network.savedConnection;

        if (!ssid) {
            wifiLocalError = "Hidden networks are not supported in this panel yet.";
            return;
        }

        if (!savedConnection && networkType.indexOf("wep") !== -1) {
            wifiLocalError = "WEP networks aren't supported by this panel.";
            return;
        }

        if (!savedConnection && networkType.indexOf("802.1x") !== -1) {
            wifiLocalError = "802.1X networks need to be provisioned first.";
            return;
        }

        clearWifiPrompt();
        clearWifiMessages();

        if (savedConnection || !secure) {
            runWifiCommand([nmcliPath, "device", "wifi", "connect", ssid], "Connecting to " + ssid + "...");
            return;
        }

        wifiPendingPasswordSsid = ssid;
        wifiPendingPasswordValue = "";
        wifiLocalInfoMessage = "Enter the password for " + ssid + ".";
    }

    function submitWifiPassword() {
        const ssid = trimString(wifiPendingPasswordSsid);
        if (!ssid) return;

        if (trimString(wifiPendingPasswordValue).length === 0) {
            wifiLocalError = "Enter a password first.";
            return;
        }

        const password = wifiPendingPasswordValue;
        clearWifiPrompt();
        clearWifiMessages();
        runWifiCommand([nmcliPath, "device", "wifi", "connect", ssid, "password", password],
            "Connecting to " + ssid + "...");
    }

    function runWifiCommand(argumentsList, infoMessage) {
        if (wifiCommandProcess.running)
            return;

        wifiBusy = true;
        wifiLocalInfoMessage = infoMessage;
        wifiLocalError = "";
        wifiCommandProcess.exec(argumentsList);
    }

    function applyWifiStateOutput(text) {
        const state = trimString(text).toLowerCase();
        wifiSupported = state !== "";
        wifiEnabled = state === "enabled";
        refreshWifiDeviceState();
    }

    function refreshWifiDeviceState() {
        if (!active || wifiDeviceProcess.running)
            return;
        wifiDeviceProcess.exec([nmcliPath, "-t", "-e", "yes", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device", "status"]);
    }

    function applyWifiDeviceOutput(text) {
        const lines = splitLines(text);
        let foundWifi = false;
        let connectedSsid = "";

        for (let index = 0; index < lines.length; index++) {
            const fields = parseNmcliFields(lines[index]);
            if (fields.length < 4 || fields[1] !== "wifi")
                continue;

            foundWifi = true;
            if (fields[2].indexOf("connected") === 0 && fields[3] !== "--")
                connectedSsid = fields[3];
        }

        wifiAvailable = foundWifi;
        wifiCurrentSsid = connectedSsid;
        if (!foundWifi)
            wifiNetworks = [];
        if (wifiPanelOpen && wifiEnabled)
            refreshWifiNetworks(false);
    }

    function applyWifiConnectionsOutput(text) {
        const lines = splitLines(text);
        const saved = {};

        for (let index = 0; index < lines.length; index++) {
            const fields = parseNmcliFields(lines[index]);
            if (fields.length >= 2 && fields[1] === "802-11-wireless")
                saved[fields[0]] = true;
        }

        savedWifiConnections = saved;

        if (wifiNetworks.length > 0) {
            const networks = [];
            for (let index = 0; index < wifiNetworks.length; index++) {
                const network = wifiNetworks[index];
                networks.push(Object.assign({}, network, {
                    savedConnection: network.connected || !!saved[network.ssid]
                }));
            }
            wifiNetworks = networks;
        }
    }

    function applyWifiListOutput(text) {
        const lines = splitLines(text);
        const bySsid = {};
        const networks = [];

        for (let index = 0; index < lines.length; index++) {
            const fields = parseNmcliFields(lines[index]);
            if (fields.length < 4)
                continue;

            const connected = fields[0] === "yes";
            const ssid = trimString(fields[1]);
            const security = trimString(fields[2]);
            const signal = Number(fields[3]);
            if (ssid === "")
                continue;

            const existing = bySsid[ssid];
            if (existing && existing.signal >= signal)
                continue;

            const item = {
                ssid: ssid,
                displayName: ssid,
                type: security,
                secure: security !== "" && security !== "--",
                signal: isNaN(signal) ? -1 : signal,
                connected: connected,
                savedConnection: connected || !!savedWifiConnections[ssid]
            };
            bySsid[ssid] = item;
        }

        for (const key in bySsid)
            networks.push(bySsid[key]);

        networks.sort((left, right) => {
            if (left.connected !== right.connected)
                return left.connected ? -1 : 1;
            return right.signal - left.signal;
        });

        wifiNetworks = networks;
        wifiListRunning = false;
    }

    function refreshBluetoothState() {
        if (!active || bluetoothStateProcess.running)
            return;
        bluetoothStateProcess.exec(["sh", "-lc", [
            "\"$1\" show 2>/dev/null",
            "printf '\\n--DEVICES--\\n'",
            "\"$1\" devices 2>/dev/null | while read -r kind mac name; do",
            "  [ -n \"$mac\" ] || continue",
            "  printf 'DeviceLine\\t%s\\t%s\\n' \"$mac\" \"$name\"",
            "  \"$1\" info \"$mac\" 2>/dev/null | sed 's/^/Info\\t/'",
            "done"
        ].join("\n"), "sh", bluetoothctlPath]);
    }

    function toggleBluetoothEnabled() {
        if (!bluetoothAvailable) {
            bluetoothError = "No Bluetooth adapter is available.";
            return;
        }

        clearBluetoothMessages();
        clearBluetoothPrompt();
        runBluetoothCommand([bluetoothctlPath, "power", bluetoothEnabled ? "off" : "on"],
            bluetoothEnabled ? "Turning Bluetooth off..." : "Turning Bluetooth on...");
    }

    function toggleBluetoothScan() {
        if (!bluetoothAvailable) {
            bluetoothError = "No Bluetooth adapter is available.";
            return;
        }
        if (!bluetoothEnabled) {
            bluetoothError = "Turn on Bluetooth first.";
            return;
        }

        bluetoothError = "";
        if (bluetoothListRunning) {
            stopBluetoothScan();
        } else {
            bluetoothListRunning = true;
            bluetoothInfoMessage = "Scanning for nearby devices...";
            bluetoothScanProcess.exec([bluetoothctlPath, "--timeout", "8", "scan", "on"]);
        }
    }

    function stopBluetoothScan() {
        if (bluetoothScanProcess.running)
            bluetoothScanProcess.running = false;
        if (bluetoothListRunning && !bluetoothStopScanProcess.running)
            bluetoothStopScanProcess.exec([bluetoothctlPath, "scan", "off"]);
        bluetoothListRunning = false;
        bluetoothInfoMessage = "";
    }

    function handleBluetoothDevicePressed(device) {
        if (!device) return;
        if (!bluetoothAvailable || !bluetoothEnabled) {
            bluetoothError = "Turn on Bluetooth first.";
            return;
        }

        bluetoothError = "";
        const address = trimString(device.address || device.dbusPath);
        if (address === "") return;

        if (device.connected) {
            runBluetoothCommand([bluetoothctlPath, "disconnect", address], "Disconnecting " + bluetoothDeviceName(device) + "...");
            return;
        }

        if (device.paired || device.bonded) {
            runBluetoothCommand([bluetoothctlPath, "connect", address], "Connecting to " + bluetoothDeviceName(device) + "...");
            return;
        }

        bluetoothPairAndConnectPath = address;
        runBluetoothCommand(["sh", "-lc", "\"$1\" pair \"$2\" && \"$1\" trust \"$2\" && \"$1\" connect \"$2\"", "sh", bluetoothctlPath, address],
            "Pairing " + bluetoothDeviceName(device) + "...");
    }

    function forgetBluetoothDevice(device) {
        if (!device) return;
        const address = trimString(device.address || device.dbusPath);
        if (address === "") return;

        if (bluetoothPairAndConnectPath === address)
            bluetoothPairAndConnectPath = "";
        runBluetoothCommand([bluetoothctlPath, "remove", address], "Forgetting " + bluetoothDeviceName(device) + "...");
    }

    function runBluetoothCommand(argumentsList, infoMessage) {
        if (bluetoothCommandProcess.running)
            return;

        bluetoothBusy = true;
        bluetoothInfoMessage = infoMessage;
        bluetoothError = "";
        bluetoothCommandProcess.exec(argumentsList);
    }

    function bluetoothDeviceName(device) {
        if (!device) return "Unknown device";
        const preferred = trimString(device.deviceName);
        if (preferred.length > 0) return preferred;

        const alias = trimString(device.name);
        if (alias.length > 0) return alias;

        const address = trimString(device.address);
        return address.length > 0 ? address : "Unknown device";
    }

    function bluetoothDeviceStateText(device) {
        if (!device) return "";
        if (device.pairing) return "Pairing";
        if (device.connecting) return "Connecting";
        if (device.connected) return "Connected";
        if (device.paired || device.bonded) return "Paired";
        return "Available";
    }

    function bluetoothDeviceSubtitle(device) {
        const parts = [];
        const stateLabel = bluetoothDeviceStateText(device);
        if (stateLabel.length > 0) parts.push(stateLabel);
        if (device && device.batteryAvailable) parts.push(Math.round(device.battery) + "%");
        return parts.join(" / ");
    }

    function bluetoothDeviceMatchesSection(device, section) {
        if (!device) return false;

        const paired = device.paired || device.bonded;
        if (section === "connected") return device.connected;
        if (section === "paired") return !device.connected && paired;
        if (section === "available") return !paired;
        return false;
    }

    function countBluetoothDevices(section) {
        let count = 0;
        const devices = bluetoothDeviceValues || [];

        for (let index = 0; index < devices.length; index++) {
            if (bluetoothDeviceMatchesSection(devices[index], section))
                count += 1;
        }

        return count;
    }

    function buildBluetoothStatusText() {
        if (!bluetoothAvailable) return "Unavailable";
        if (!bluetoothEnabled) return "Off";

        const devices = bluetoothDeviceValues || [];
        const connectedNames = [];

        for (let index = 0; index < devices.length; index++) {
            const device = devices[index];
            if (device && device.connected)
                connectedNames.push(bluetoothDeviceName(device));
        }

        if (connectedNames.length === 1) return connectedNames[0];
        if (connectedNames.length > 1) return connectedNames[0] + " +" + (connectedNames.length - 1);
        if (bluetoothListRunning) return "Scanning";
        return bluetoothBusy ? "Working..." : "On";
    }

    function applyBluetoothOutput(text) {
        const lines = splitLines(text);
        const devices = [];
        let current = null;
        let powered = false;
        let available = false;

        function commitDevice() {
            if (current)
                devices.push(current);
            current = null;
        }

        for (let index = 0; index < lines.length; index++) {
            const line = lines[index];
            if (line.indexOf("Controller ") === 0)
                available = true;

            const poweredMatch = line.match(/^\s*Powered:\s*(yes|no)\s*$/);
            if (poweredMatch) {
                powered = poweredMatch[1] === "yes";
                continue;
            }

            if (line.indexOf("DeviceLine\t") === 0) {
                commitDevice();
                const parts = line.split("\t");
                current = {
                    address: parts.length > 1 ? parts[1] : "",
                    dbusPath: parts.length > 1 ? parts[1] : "",
                    name: parts.length > 2 ? parts[2] : "",
                    deviceName: parts.length > 2 ? parts[2] : "",
                    connected: false,
                    paired: false,
                    bonded: false,
                    trusted: false,
                    pairing: false,
                    connecting: false,
                    batteryAvailable: false,
                    battery: 0
                };
                continue;
            }

            if (!current || line.indexOf("Info\t") !== 0)
                continue;

            const info = line.substring(5).trim();
            const separator = info.indexOf(":");
            if (separator < 0)
                continue;

            const key = info.substring(0, separator).trim();
            const value = info.substring(separator + 1).trim();
            switch (key) {
            case "Name":
            case "Alias":
                if (current.deviceName === "" || key === "Alias") {
                    current.deviceName = value;
                    current.name = value;
                }
                break;
            case "Paired":
                current.paired = value === "yes";
                break;
            case "Bonded":
                current.bonded = value === "yes";
                break;
            case "Trusted":
                current.trusted = value === "yes";
                break;
            case "Connected":
                current.connected = value === "yes";
                break;
            case "Battery Percentage": {
                const match = value.match(/\((\d+)\)/);
                if (match) {
                    current.batteryAvailable = true;
                    current.battery = Number(match[1]);
                }
                break;
            }
            default:
                break;
            }
        }

        commitDevice();
        devices.sort((left, right) => {
            if (left.connected !== right.connected)
                return left.connected ? -1 : 1;
            const leftPaired = left.paired || left.bonded;
            const rightPaired = right.paired || right.bonded;
            if (leftPaired !== rightPaired)
                return leftPaired ? -1 : 1;
            return bluetoothDeviceName(left).localeCompare(bluetoothDeviceName(right));
        });

        bluetoothAvailable = available;
        bluetoothEnabled = powered;
        bluetoothDeviceValues = devices;
    }

    function shutdown() {
        stopWifiScan();
        stopBluetoothScan();
        if (wifiStateProcess.running) wifiStateProcess.running = false;
        if (wifiDeviceProcess.running) wifiDeviceProcess.running = false;
        if (wifiConnectionsProcess.running) wifiConnectionsProcess.running = false;
        if (wifiCommandProcess.running) wifiCommandProcess.running = false;
        if (bluetoothStateProcess.running) bluetoothStateProcess.running = false;
        if (bluetoothCommandProcess.running) bluetoothCommandProcess.running = false;

        wifiBusy = false;
        bluetoothBusy = false;
        wifiNetworks = [];
        bluetoothDeviceValues = [];
        closeConnectivityPanels(false);
    }

    onActiveChanged: {
        if (active)
            refreshState();
        else
            shutdown();
    }

    Component.onCompleted: {
        if (active)
            refreshState();
    }

    Component.onDestruction: shutdown()

    Process {
        id: wifiStateProcess
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.applyWifiStateOutput(text)
        }
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                root.wifiSupported = false;
                root.wifiAvailable = false;
                root.wifiUnsupportedReason = "NetworkManager is unavailable.";
            }
        }
    }

    Process {
        id: wifiDeviceProcess
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.applyWifiDeviceOutput(text)
        }
    }

    Process {
        id: wifiConnectionsProcess
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.applyWifiConnectionsOutput(text)
        }
    }

    Process {
        id: wifiListProcess
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.applyWifiListOutput(text)
        }
        onExited: root.wifiListRunning = false
    }

    Process {
        id: wifiCommandProcess
        onExited: function(exitCode) {
            root.wifiBusy = false;
            if (exitCode !== 0)
                root.wifiLocalError = "Wi-Fi command failed.";
            root.wifiLocalInfoMessage = "";
            root.refreshWifiState();
        }
    }

    Process {
        id: bluetoothStateProcess
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.applyBluetoothOutput(text)
        }
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                root.bluetoothAvailable = false;
                root.bluetoothEnabled = false;
                root.bluetoothDeviceValues = [];
            }
        }
    }

    Process {
        id: bluetoothCommandProcess
        onExited: function(exitCode) {
            root.bluetoothBusy = false;
            if (exitCode !== 0)
                root.bluetoothError = "Bluetooth command failed. PIN/passkey pairing may need bluetoothctl.";
            root.bluetoothInfoMessage = "";
            root.clearBluetoothPrompt();
            root.refreshBluetoothState();
        }
    }

    Process {
        id: bluetoothScanProcess
        onExited: {
            root.bluetoothListRunning = false;
            root.bluetoothInfoMessage = "";
            root.refreshBluetoothState();
        }
    }

    Process {
        id: bluetoothStopScanProcess
        onExited: root.refreshBluetoothState()
    }
}
