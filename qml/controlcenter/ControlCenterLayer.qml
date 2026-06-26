import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import IslandBackend
import "../connectivity"

Item {
    id: controlCenter

    readonly property var userConfig: UserConfig

    property bool showCondition: false
    property string iconFontFamily: userConfig.iconFontFamily
    property string textFontFamily: userConfig.textFontFamily
    property string heroFontFamily: userConfig.heroFontFamily

    scale: showCondition ? 1.0 : 0.12
    transformOrigin: Item.Top
    Behavior on scale {
        NumberAnimation {
            duration: 400
            easing.type: Easing.OutQuint
        }
    }

    property string currentTime: "00:00"
    property string currentDateLabel: ""
    property int batteryCapacity: 0
    property bool isCharging: false
    property real volumeLevel: -1
    property real brightnessLevel: -1
    property int sliderIntroDelay: 400
    property int currentWorkspace: 1
    property string currentTrack: ""
    property string currentArtist: ""

    property real localVolume: 0.5
    property real localBrightness: 0.5
    property real displayedVolume: 0.5
    property real displayedBrightness: 0.5
    property real pendingVolume: 0.5
    property real pendingBrightness: 0.5
    property real lastAppliedVolume: -1
    property real lastAppliedBrightness: -1
    property bool brightnessSetterRunning: false
    property bool volumeSetterRunning: false
    property bool sliderIntroPending: false
    property bool wifiPanelOpen: false
    property bool bluetoothPanelOpen: false
    property bool batteryDrawerOpen: false
    property bool batteryDrawerDragging: false
    property real batteryDrawerProgress: 0
    property bool batteryDrawerSettling: false
    readonly property bool batteryDrawerMoving: batteryDrawerDragging || batteryDrawerSettling || batteryDrawerProgressAnimation.running
    property bool batteryModeBusy: false
    property bool batteryModeStateRunning: false
    property bool batteryModeSetterRunning: false
    property bool batteryModeSliderDragging: false
    property bool batteryTlpAvailable: false
    property bool batteryTlpChecked: false
    property int batteryModeIndex: 1
    property int batteryModeAppliedIndex: 1
    property int batteryModePendingIndex: 1
    property real batteryModeDragOffset: 0
    property string batteryModeInfoMessage: ""
    property string batteryModeError: ""
    property string batteryModeLastCommandOutput: ""
    property int batteryModeRefreshPollsRemaining: 0
    property bool nightLightEnabled: false
    property bool nightLightBusy: false
    property int nightLightTemperature: 4500
    property bool focusEnabled: false
    property bool focusBusy: false
    property string wifiLocalInfoMessage: ""
    property string wifiLocalError: ""
    property string wifiPendingPasswordSsid: ""
    property string wifiPendingPasswordValue: ""
    property string bluetoothInfoMessage: ""
    property string bluetoothError: ""
    property string bluetoothPairAndConnectPath: ""
    property string bluetoothPendingSecretValue: ""

    readonly property var wifiController: WifiController
    readonly property var bluetoothPairingAgent: BluetoothPairingAgent
    readonly property var wifiNetworks: wifiController ? wifiController.networks : null

    signal requestNotification(string appName, string summary, string body)

    readonly property real sliderKnobSize: 24
    readonly property color panelColor: StyleTokens.panel
    readonly property color moduleColor: StyleTokens.module
    readonly property color moduleHover: StyleTokens.moduleHover
    readonly property color trackColor: StyleTokens.track
    readonly property color textPrimary: StyleTokens.textPrimary
    readonly property color textSecondary: StyleTokens.textSecondary
    readonly property color cardAccent: StyleTokens.accent
    readonly property color cardAccentPressed: StyleTokens.accentPressed
    readonly property color cardFillActive: StyleTokens.cardFillActive
    readonly property color cardFillHover: StyleTokens.cardFillHover
    readonly property color buttonFill: StyleTokens.buttonFill
    readonly property color buttonFillHover: StyleTokens.buttonFillHover
    readonly property color buttonFillPressed: StyleTokens.buttonFillPressed
    readonly property string wifiGlyph: "\uf1eb"
    readonly property string bluetoothGlyph: "\uf294"
    readonly property string chargingIconGlyph: "\uf0e7"
    readonly property string brightnessIconGlyph: "\u{F00DF}"
    readonly property string volumeIconGlyph: "\u{F057E}"
    readonly property string nightLightGlyph: "\uf185"
    readonly property string focusGlyph: "\uf186"
    readonly property var batteryModeGlyphs: ["\uf0e7", "\uf241", "\uf4a4"]
    readonly property real batteryDrawerHandleHeight: 20
    readonly property real batteryDrawerContentGap: 8
    readonly property real batteryModeCardHeight: 80
    readonly property real toggleCardHeight: 80
    readonly property real toggleCardGap: 8
    readonly property real batteryDrawerContentHeight: batteryModeCardHeight + toggleCardGap + toggleCardHeight
    readonly property real controlCenterExtraHeight: 12 + batteryDrawerHandleHeight + batteryDrawerProgress * (batteryDrawerContentGap + batteryDrawerContentHeight)
    readonly property real controlCenterMaximumExtraHeight: 12 + batteryDrawerHandleHeight + batteryDrawerContentGap + batteryDrawerContentHeight
    readonly property bool bluetoothAvailable: !!bluetoothAdapter
    readonly property var bluetoothAdapter: Bluetooth.defaultAdapter
    readonly property var bluetoothDeviceValues: bluetoothAdapter ? bluetoothAdapter.devices.values : []
    readonly property bool wifiSupported: wifiController ? wifiController.supported : false
    readonly property bool wifiReadOnly: wifiController ? wifiController.readOnly : true
    readonly property bool wifiAvailable: wifiController ? wifiController.available : false
    readonly property bool wifiEnabled: wifiController ? wifiController.enabled : false
    readonly property bool wifiBusy: wifiController ? wifiController.busy : false
    readonly property bool wifiListRunning: wifiController ? wifiController.scanning : false
    readonly property string wifiCurrentSsid: wifiController ? wifiController.currentSsid : ""
    readonly property string wifiInfoMessage: wifiLocalInfoMessage.length > 0 ? wifiLocalInfoMessage : (wifiController ? wifiController.infoMessage : "")
    readonly property string wifiError: wifiLocalError.length > 0 ? wifiLocalError : (wifiController ? wifiController.errorMessage : "")
    readonly property string wifiUnsupportedReason: wifiController ? wifiController.unsupportedReason : ""
    readonly property string wifiAvailabilityMessage: {
        if (wifiUnsupportedReason.length > 0)
            return wifiUnsupportedReason;
        if (wifiSupported && !wifiAvailable)
            return "No Wi-Fi device is available.";
        return "";
    }
    readonly property bool bluetoothEnabled: bluetoothAdapter ? bluetoothAdapter.enabled : false
    readonly property bool bluetoothBusy: bluetoothAdapter ? bluetoothAdapter.state === BluetoothAdapterState.Enabling || bluetoothAdapter.state === BluetoothAdapterState.Disabling : false
    readonly property bool bluetoothPairingActive: bluetoothPairingAgent ? bluetoothPairingAgent.requestActive : false
    readonly property bool bluetoothPairingRequiresInput: bluetoothPairingAgent ? bluetoothPairingAgent.requestRequiresInput : false
    readonly property bool bluetoothPairingNumericInput: bluetoothPairingAgent ? bluetoothPairingAgent.requestNumericInput : false
    readonly property bool bluetoothPairingRequiresConfirmation: bluetoothPairingAgent ? bluetoothPairingAgent.requestRequiresConfirmation : false
    readonly property string bluetoothPairingTitle: bluetoothPairingAgent ? bluetoothPairingAgent.promptTitle : ""
    readonly property string bluetoothPairingMessage: bluetoothPairingAgent ? bluetoothPairingAgent.promptMessage : ""
    readonly property string bluetoothPairingDisplayedCode: bluetoothPairingAgent ? bluetoothPairingAgent.displayedCode : ""
    readonly property bool hasConnectivityPrompt: wifiPendingPasswordSsid.length > 0 || bluetoothPairingActive
    readonly property bool anyConnectivityPanelOpen: wifiPanelOpen || bluetoothPanelOpen
    readonly property string wifiStatusText: wifiController ? wifiController.statusText : "Unavailable"
    readonly property string bluetoothStatusText: buildBluetoothStatusText()
    readonly property string bluetoothAvailabilityMessage: bluetoothAvailable ? "" : "No Bluetooth adapter is available."
    readonly property string batteryModeStatusText: buildBatteryModeStatusText()

    function clamp01(value) {
        return Math.max(0, Math.min(1, value));
    }
    function trimString(value) {
        if (value === undefined || value === null)
            return "";
        return String(value).trim();
    }

    function batteryModeLabel(index) {
        if (index <= 0)
            return "Power Saver";
        if (index >= 2)
            return "Performance";
        return "Balanced";
    }
    function batteryModeCommand(index) {
        if (index <= 0)
            return "power-saver";
        if (index >= 2)
            return "performance";
        return "balanced";
    }
    function batteryModeIndexForCommand(command) {
        const normalized = trimString(command).toLowerCase();
        if (normalized === "power-saver" || normalized === "bat")
            return 0;
        if (normalized === "performance" || normalized === "ac")
            return 2;
        return 1;
    }
    function setBatteryModeVisualIndex(index, animate) {
        batteryModeIndex = Math.max(0, Math.min(2, index));
    }
    function setBatteryDrawerOpen(open) {
        batteryDrawerOpen = !!open;
        batteryDrawerSettling = true;
        batteryDrawerProgress = batteryDrawerOpen ? 1 : 0;
        batteryDrawerSettleTimer.restart();
        if (batteryDrawerOpen && !batteryTlpChecked)
            refreshBatteryModeState();
    }
    function toggleBatteryDrawer() {
        setBatteryDrawerOpen(!batteryDrawerOpen);
    }
    function refreshBatteryModeState() {
        if (batteryModeStateRunning)
            return;
        batteryModeStateRunning = true;
        SystemServices.requestTlpState();
    }
    function applyBatteryModeState(available, profile, output, errorString) {
        batteryModeStateRunning = false;
        batteryTlpChecked = true;
        batteryTlpAvailable = !!available;
        if (!batteryTlpAvailable) {
            batteryModeBusy = false;
            batteryModeError = trimString(errorString).length > 0 ? errorString : "TLP is not installed.";
            setBatteryModeVisualIndex(batteryModeAppliedIndex, true);
            return;
        }
        if (batteryModeError === "TLP is not installed.")
            batteryModeError = "";
        let resolvedProfile = trimString(profile);
        if (resolvedProfile.length === 0) {
            const profileMatch = String(output || "").match(/TLP profile\s*=\s*([a-z-]+)/i);
            if (profileMatch)
                resolvedProfile = profileMatch[1];
        }
        if (resolvedProfile.length > 0) {
            const nextIndex = batteryModeIndexForCommand(resolvedProfile);
            batteryModeAppliedIndex = nextIndex;
            setBatteryModeVisualIndex(nextIndex, true);
            if (batteryModeRefreshPollsRemaining > 0 && nextIndex === batteryModePendingIndex) {
                batteryModeRefreshPollsRemaining = 0;
                batteryModeRefreshTimer.stop();
                batteryModeError = "";
                batteryModeInfoMessage = batteryModeLabel(nextIndex) + " active.";
            }
        }
    }
    function buildBatteryModeStatusText() {
        if (batteryModeBusy)
            return "Applying " + batteryModeLabel(batteryModePendingIndex);
        if (trimString(userConfig.tlpPermissionMode) === "skip")
            return "TLP disabled";
        if (!batteryTlpChecked)
            return "Checking TLP";
        if (!batteryTlpAvailable)
            return "TLP is not installed";
        return batteryModeLabel(batteryModeIndex);
    }
    function rollbackBatteryMode(message) {
        batteryModeBusy = false;
        batteryModeError = message;
        batteryModeInfoMessage = "";
        batteryModeDragOffset = 0;
        setBatteryModeVisualIndex(batteryModeAppliedIndex, true);
    }
    function classifyBatteryModeFailure(exitCode) {
        const details = trimString(batteryModeLastCommandOutput).toLowerCase();
        if (details.indexOf("sorry, try again") >= 0 || details.indexOf("incorrect password attempt") >= 0)
            return "The configured sudo password did not work.";
        if (details.indexOf("pkexec") >= 0 && details.indexOf("not installed") >= 0)
            return "Install pkexec or set tlpSudoPassword in userconfig.json.";
        if (details.indexOf("sudo is not installed") >= 0)
            return "sudo is not installed.";
        if (details.indexOf("sudo:") >= 0 && details.indexOf("password") >= 0) {
            if (trimString(userConfig.tlpPermissionMode) === "ask")
                return "Install pkexec or set tlpSudoPassword in userconfig.json.";
            return "sudo needs a password; set tlpSudoPassword in userconfig.json.";
        }
        if (details.indexOf("sudo:") >= 0 && details.indexOf("no new privileges") >= 0)
            return "sudo is blocked by the current process security flags.";
        if (details.indexOf("sudo:") >= 0 && details.indexOf("a terminal is required") >= 0)
            return "sudo needs a real terminal, but the panel could not open one.";
        if (details.indexOf("missing root privilege") >= 0)
            return "TLP needs admin permission.";
        if (details.indexOf("command not found") >= 0 || details.indexOf("not found") >= 0) {
            if (details.indexOf("tlp") >= 0)
                return "TLP is not installed.";
        }
        if (exitCode === 127)
            return "TLP is not installed.";
        if (exitCode === 126)
            return "Install pkexec or set tlpSudoPassword in userconfig.json.";
        return "TLP could not apply that mode.";
    }
    function queueBatteryModeStateRefresh(polls) {
        batteryModeRefreshPollsRemaining = Math.max(0, polls);
        if (batteryModeRefreshPollsRemaining > 0)
            batteryModeRefreshTimer.restart();
        else
            batteryModeRefreshTimer.stop();
    }
    function selectBatteryMode(index) {
        if (batteryModeBusy) {
            if (batteryModeSetterRunning)
                SystemServices.cancelTlpApply();
            batteryModeBusy = false;
            batteryModeSetterRunning = false;
        }
        queueBatteryModeStateRefresh(0);
        const nextIndex = Math.max(0, Math.min(2, index));
        if (trimString(userConfig.tlpPermissionMode) === "skip") {
            rollbackBatteryMode("TLP mode switching is disabled in userconfig.json.");
            return;
        }
        if (!batteryTlpChecked) {
            refreshBatteryModeState();
            rollbackBatteryMode("Checking TLP. Try again in a moment.");
            return;
        }
        if (!batteryTlpAvailable) {
            rollbackBatteryMode("TLP is not installed.");
            return;
        }
        if (nextIndex === batteryModeAppliedIndex) {
            batteryModeError = "";
            batteryModeInfoMessage = batteryModeLabel(nextIndex) + " active.";
            setBatteryModeVisualIndex(nextIndex, true);
            return;
        }
        batteryModePendingIndex = nextIndex;
        batteryModeBusy = true;
        batteryModeSetterRunning = true;
        batteryModeError = "";
        batteryModeInfoMessage = "Applying " + batteryModeLabel(nextIndex) + "...";
        setBatteryModeVisualIndex(nextIndex, true);
        batteryModeLastCommandOutput = "";
        SystemServices.setTlpMode(batteryModeCommand(nextIndex), trimString(userConfig.tlpSudoPassword));
    }
    function finishBatteryModeApply(success, exitCode, output, errorString) {
        batteryModeSetterRunning = false;
        batteryModeBusy = false;
        batteryModeLastCommandOutput = trimString(output);
        if (batteryModeLastCommandOutput.length === 0)
            batteryModeLastCommandOutput = trimString(errorString);
        if (!success) {
            rollbackBatteryMode(classifyBatteryModeFailure(exitCode));
            return;
        }
        batteryModeAppliedIndex = batteryModePendingIndex;
        batteryModeError = "";
        batteryModeInfoMessage = batteryModeLabel(batteryModeAppliedIndex) + " active.";
        setBatteryModeVisualIndex(batteryModeAppliedIndex, true);
        refreshBatteryModeState();
    }

    function toggleNightLight() {
        if (nightLightBusy)
            return;
        nightLightBusy = true;
        if (nightLightEnabled) {
            nightLightDisableProcess.running = true;
        } else {
            nightLightEnableProcess.running = true;
        }
    }

    function toggleFocus() {
        if (focusBusy)
            return;
        focusBusy = true;
        if (focusEnabled) {
            focusDisableProcess.running = true;
        } else {
            focusEnableProcess.running = true;
        }
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
        if (wifiController)
            wifiController.clearMessages();
    }
    function clearBluetoothMessages() {
        bluetoothInfoMessage = "";
        bluetoothError = "";
    }
    function submitBluetoothPairingSecret() {
        if (!bluetoothPairingAgent || !bluetoothPairingRequiresInput)
            return;
        const secret = trimString(bluetoothPendingSecretValue);
        if (!secret) {
            bluetoothError = bluetoothPairingNumericInput ? "Enter the 6-digit passkey first." : "Enter the PIN first.";
            return;
        }
        if (bluetoothPairingNumericInput && !/^\d{1,6}$/.test(secret)) {
            bluetoothError = "Passkeys must be 1 to 6 digits.";
            return;
        }
        bluetoothError = "";
        bluetoothPairingAgent.submitSecret(secret);
        bluetoothPendingSecretValue = "";
    }
    function confirmBluetoothPairing() {
        if (!bluetoothPairingAgent)
            return;
        bluetoothError = "";
        bluetoothPairingAgent.confirmRequest();
    }
    function cancelBluetoothPairing() {
        if (!bluetoothPairingAgent)
            return;
        bluetoothPairingAgent.cancelRequest();
        bluetoothPendingSecretValue = "";
    }
    function isConnectivityPanelOpen(kind) {
        if (kind === "wifi")
            return wifiPanelOpen;
        if (kind === "bluetooth")
            return bluetoothPanelOpen;
        return false;
    }
    function setConnectivityPanelOpen(kind, open, emitSignal) {
        const nextOpen = !!open;
        if (kind === "wifi") {
            wifiPanelOpen = nextOpen;
            if (nextOpen) {
                bluetoothPanelOpen = false;
                if (showCondition) {
                    requestWifiStateRefresh();
                    if (wifiSupported && wifiEnabled)
                        requestWifiListRefresh(true);
                }
            } else {
                clearWifiPrompt();
                clearWifiMessages();
            }
        } else if (kind === "bluetooth") {
            bluetoothPanelOpen = nextOpen;
            if (nextOpen) {
                wifiPanelOpen = false;
            } else {
                if (bluetoothPairingActive)
                    cancelBluetoothPairing();
                if (bluetoothAdapter && bluetoothAdapter.discovering)
                    bluetoothAdapter.discovering = false;
                bluetoothScanStopTimer.stop();
                bluetoothPairAndConnectPath = "";
                bluetoothPendingSecretValue = "";
                clearBluetoothMessages();
            }
        }
    }
    function toggleConnectivityOverlay(kind) {
        setConnectivityPanelOpen(kind, !isConnectivityPanelOpen(kind));
    }
    function closeConnectivityPanels(emitSignals) {
        setConnectivityPanelOpen("wifi", false);
        setConnectivityPanelOpen("bluetooth", false);
        clearWifiPrompt();
        clearWifiMessages();
        clearBluetoothMessages();
    }
    function requestWifiStateRefresh() {
        if (!showCondition || !wifiController)
            return;
        wifiController.refreshState();
    }
    function requestWifiListRefresh(rescan) {
        if (!showCondition || !wifiController)
            return;
        if (!wifiSupported || !wifiAvailable || !wifiEnabled)
            return;
        wifiController.refreshNetworks(!!rescan);
    }
    function toggleWifiEnabled() {
        clearWifiPrompt();
        clearWifiMessages();
        if (wifiController)
            wifiController.setEnabled(!wifiEnabled);
    }
    function disconnectWifi() {
        if (!wifiSupported || !wifiAvailable) {
            wifiLocalError = wifiAvailabilityMessage.length > 0 ? wifiAvailabilityMessage : "No Wi-Fi device is available.";
            return;
        }
        clearWifiPrompt();
        clearWifiMessages();
        if (wifiController)
            wifiController.disconnectCurrent();
    }
    function connectWifiNetwork(network) {
        if (!network)
            return;
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
        if (network.connected)
            return;
        const ssid = trimString(network.ssid);
        const networkType = trimString(network.type);
        const secure = !!network.secure;
        const savedConnection = !!network.savedConnection;
        if (!ssid) {
            wifiLocalError = "Hidden networks are not supported in this panel yet.";
            return;
        }
        if (!savedConnection && networkType === "wep") {
            wifiLocalError = "WEP networks aren't supported by this panel.";
            return;
        }
        if (!savedConnection && networkType === "8021x") {
            wifiLocalError = "802.1X networks need to be provisioned first.";
            return;
        }
        clearWifiPrompt();
        clearWifiMessages();
        if (savedConnection) {
            if (wifiController)
                wifiController.connectToNetwork(ssid);
            return;
        }
        if (!secure) {
            if (wifiController)
                wifiController.connectToNetwork(ssid);
            return;
        }
        wifiPendingPasswordSsid = ssid;
        wifiPendingPasswordValue = "";
        wifiLocalInfoMessage = "Enter the password for " + ssid + ".";
    }
    function submitWifiPassword() {
        const ssid = trimString(wifiPendingPasswordSsid);
        if (!ssid)
            return;
        if (trimString(wifiPendingPasswordValue).length === 0) {
            wifiLocalError = "Enter a password first.";
            return;
        }
        const password = wifiPendingPasswordValue;
        clearWifiPrompt();
        clearWifiMessages();
        if (wifiController)
            wifiController.connectToNetwork(ssid, password);
    }
    function applyBrightnessSnapshot(value) {
        if (value >= 0)
            syncBrightnessFromLevel(value);
    }
    function applyVolumeSnapshot(value) {
        if (value >= 0)
            syncVolumeFromLevel(value);
    }
    function flushBrightness(force) {
        const nextValue = clamp01(pendingBrightness);
        if (!force && Math.abs(nextValue - lastAppliedBrightness) < 0.01)
            return;
        if (brightnessSetterRunning) {
            brightnessApplyTimer.restart();
            return;
        }
        lastAppliedBrightness = nextValue;
        brightnessSetterRunning = true;
        SystemServices.setBrightness(nextValue);
    }
    function queueBrightness(value) {
        localBrightness = clamp01(value);
        if (showCondition && !sliderIntroPending)
            displayedBrightness = localBrightness;
        pendingBrightness = localBrightness;
        brightnessApplyTimer.restart();
    }
    function flushVolume(force) {
        const nextValue = clamp01(pendingVolume);
        if (!force && Math.abs(nextValue - lastAppliedVolume) < 0.01)
            return;
        if (volumeSetterRunning) {
            volumeApplyTimer.restart();
            return;
        }
        lastAppliedVolume = nextValue;
        volumeSetterRunning = true;
        SystemServices.setVolume(nextValue);
    }
    function queueVolume(value) {
        localVolume = clamp01(value);
        if (showCondition && !sliderIntroPending)
            displayedVolume = localVolume;
        pendingVolume = localVolume;
        volumeApplyTimer.restart();
    }
    function syncBrightnessFromLevel(level) {
        if (level < 0)
            return;
        localBrightness = clamp01(level);
        if (showCondition && !sliderIntroPending)
            displayedBrightness = localBrightness;
        pendingBrightness = localBrightness;
        lastAppliedBrightness = localBrightness;
    }
    function syncVolumeFromLevel(level) {
        if (level < 0)
            return;
        localVolume = clamp01(level);
        if (showCondition && !sliderIntroPending)
            displayedVolume = localVolume;
        pendingVolume = localVolume;
        lastAppliedVolume = localVolume;
    }
    function syncLevelsFromProps() {
        syncBrightnessFromLevel(brightnessLevel);
        syncVolumeFromLevel(volumeLevel);
    }

    function bluetoothDeviceName(device) {
        if (!device)
            return "Unknown device";
        const preferred = trimString(device.deviceName);
        if (preferred.length > 0)
            return preferred;
        const alias = trimString(device.name);
        if (alias.length > 0)
            return alias;
        const address = trimString(device.address);
        return address.length > 0 ? address : "Unknown device";
    }
    function bluetoothDeviceStateText(device) {
        if (!device)
            return "";
        if (device.pairing)
            return "Pairing";
        switch (device.state) {
        case BluetoothDeviceState.Connecting:
            return "Connecting";
        case BluetoothDeviceState.Connected:
            return "Connected";
        case BluetoothDeviceState.Disconnecting:
            return "Disconnecting";
        default:
            break;
        }
        if (device.paired || device.bonded)
            return "Paired";
        return "Available";
    }
    function bluetoothDeviceSubtitle(device) {
        const parts = [];
        const stateLabel = bluetoothDeviceStateText(device);
        if (stateLabel.length > 0)
            parts.push(stateLabel);
        if (device && device.batteryAvailable)
            parts.push(bluetoothBatteryPercent(device) + "%");
        return parts.join(" • ");
    }
    function bluetoothBatteryPercent(device) {
        if (!device || !device.batteryAvailable)
            return -1;
        const rawValue = Math.max(0, Number(device.battery) || 0);
        return Math.max(0, Math.min(100, Math.round(rawValue <= 1 ? rawValue * 100 : rawValue)));
    }
    function bluetoothDeviceMatchesSection(device, section) {
        if (!device)
            return false;
        const paired = device.paired || device.bonded;
        if (section === "connected")
            return device.connected;
        if (section === "paired")
            return !device.connected && paired;
        if (section === "available")
            return !paired;
        return false;
    }
    function buildBluetoothStatusText() {
        if (!bluetoothAvailable)
            return "Unavailable";
        if (!bluetoothEnabled)
            return "Off";
        const devices = bluetoothDeviceValues || [];
        const connectedNames = [];
        for (let index = 0; index < devices.length; index++) {
            const device = devices[index];
            if (device && device.connected)
                connectedNames.push(bluetoothDeviceName(device));
        }
        if (connectedNames.length === 1)
            return connectedNames[0];
        if (connectedNames.length > 1)
            return connectedNames[0] + " +" + (connectedNames.length - 1);
        if (bluetoothAdapter.discovering)
            return "Scanning";
        return bluetoothBusy ? "Working..." : "On";
    }
    function toggleBluetoothEnabled() {
        if (!bluetoothAdapter) {
            bluetoothError = "No Bluetooth adapter is available.";
            return;
        }
        bluetoothError = "";
        bluetoothInfoMessage = "";
        bluetoothPairAndConnectPath = "";
        if (bluetoothAdapter.discovering)
            bluetoothAdapter.discovering = false;
        bluetoothAdapter.enabled = !bluetoothAdapter.enabled;
    }
    function toggleBluetoothScan() {
        if (!bluetoothAdapter) {
            bluetoothError = "No Bluetooth adapter is available.";
            return;
        }
        if (!bluetoothEnabled) {
            bluetoothError = "Turn on Bluetooth first.";
            return;
        }
        bluetoothError = "";
        if (bluetoothAdapter.discovering) {
            bluetoothAdapter.discovering = false;
            bluetoothInfoMessage = "";
            bluetoothScanStopTimer.stop();
        } else {
            bluetoothAdapter.discovering = true;
            bluetoothInfoMessage = "Scanning for nearby devices...";
            bluetoothScanStopTimer.restart();
        }
    }
    function handleBluetoothDevicePressed(device) {
        if (!device)
            return;
        if (!bluetoothAdapter || !bluetoothEnabled) {
            bluetoothError = "Turn on Bluetooth first.";
            return;
        }
        bluetoothError = "";
        if (device.connected) {
            bluetoothInfoMessage = "";
            device.disconnect();
            return;
        }
        if (device.paired || device.bonded) {
            bluetoothInfoMessage = "";
            device.connect();
            return;
        }
        bluetoothPairAndConnectPath = device.dbusPath;
        bluetoothInfoMessage = "Pairing " + bluetoothDeviceName(device) + "...";
        device.pair();
    }
    function forgetBluetoothDevice(device) {
        if (!device)
            return;
        if (bluetoothPairAndConnectPath === device.dbusPath)
            bluetoothPairAndConnectPath = "";
        device.forget();
    }

    anchors.fill: parent
    anchors.margins: 12
    opacity: showCondition ? 1 : 0
    visible: opacity > 0

    onBrightnessLevelChanged: syncBrightnessFromLevel(brightnessLevel)
    onVolumeLevelChanged: syncVolumeFromLevel(volumeLevel)
    onShowConditionChanged: {
        if (showCondition) {
            syncLevelsFromProps();
            sliderIntroPending = true;
            displayedBrightness = localBrightness;
            displayedVolume = localVolume;
            sliderIntroTimer.interval = sliderIntroDelay;
            sliderIntroTimer.restart();
            refreshBatteryModeState();
            requestWifiStateRefresh();
            if (wifiPanelOpen && wifiSupported && wifiEnabled)
                requestWifiListRefresh(true);
        } else {
            sliderIntroTimer.stop();
            sliderIntroPending = false;
            displayedBrightness = localBrightness;
            displayedVolume = localVolume;
            closeConnectivityPanels();
        }
    }

    Component.onCompleted: {
        syncLevelsFromProps();
        displayedBrightness = localBrightness;
        displayedVolume = localVolume;
        SystemServices.requestBrightness();
        SystemServices.requestVolume();
        refreshBatteryModeState();
        focusStateProcess.running = true;
    }

    Behavior on opacity {
        NumberAnimation {
            duration: showCondition ? 240 : 100
            easing.type: Easing.InOutQuad
        }
    }
    Behavior on displayedBrightness {
        enabled: controlCenter.showCondition && !controlCenter.sliderIntroPending && !brightnessCard.pressed
        NumberAnimation {
            duration: 130
            easing.type: Easing.OutCubic
        }
    }
    Behavior on displayedVolume {
        enabled: controlCenter.showCondition && !controlCenter.sliderIntroPending && !volumeCard.pressed
        NumberAnimation {
            duration: 130
            easing.type: Easing.OutCubic
        }
    }
    Behavior on batteryDrawerProgress {
        enabled: !controlCenter.batteryDrawerDragging
        NumberAnimation {
            id: batteryDrawerProgressAnimation
            duration: 240
            easing.type: Easing.OutCubic
        }
    }
    Process {
        id: focusStateProcess
        command: ["swaync-client", "--get-dnd"]
        running: false
        stdout: SplitParser {
            onRead: function (line) {
                const val = line.trim().toLowerCase();
                controlCenter.focusEnabled = (val === "true");
            }
        }
    }
    Process {
        id: nightLightEnableProcess
        command: ["hyprctl", "hyprsunset", "temperature", controlCenter.nightLightTemperature.toString()]
        running: false
        onExited: function (exitCode) {
            controlCenter.nightLightBusy = false;
            if (exitCode === 0) {
                controlCenter.nightLightEnabled = true;
                controlCenter.requestNotification("Night Light", "Night Light enabled", controlCenter.nightLightTemperature + "K");
            } else {
                controlCenter.nightLightEnabled = false;
            }
        }
    }

    Process {
        id: nightLightDisableProcess
        command: ["hyprctl", "hyprsunset", "identity"]
        running: false
        onExited: function (exitCode) {
            controlCenter.nightLightBusy = false;
            controlCenter.nightLightEnabled = false;
            controlCenter.requestNotification("Night Light", "Night Light disabled", "");
        }
    }
    Process {
        id: focusEnableProcess
        command: ["swaync-client", "-dn"]
        running: false
        onExited: function (exitCode) {
            controlCenter.focusBusy = false;
            if (exitCode === 0) {
                controlCenter.focusEnabled = true;
                controlCenter.requestNotification("Focus", "Focus enabled", "Notifications paused");
            } else {
                controlCenter.focusEnabled = false;
            }
        }
    }

    Process {
        id: focusDisableProcess
        command: ["swaync-client", "-df"]
        running: false
        onExited: function (exitCode) {
            controlCenter.focusBusy = false;
            controlCenter.focusEnabled = false;
            controlCenter.requestNotification("Focus", "Focus disabled", "");
        }
    }

    Connections {
        target: SystemServices
        function onTlpStateReady(available, profile, output, errorString) {
            controlCenter.applyBatteryModeState(available, profile, output, errorString);
        }
        function onTlpSetFinished(success, exitCode, output, errorString) {
            controlCenter.finishBatteryModeApply(success, exitCode, output, errorString);
        }
        function onBrightnessSnapshotReady(value, errorString) {
            if (errorString === "")
                controlCenter.applyBrightnessSnapshot(value);
        }
        function onBrightnessSetFinished(value, success, errorString) {
            controlCenter.brightnessSetterRunning = false;
            if (success)
                controlCenter.applyBrightnessSnapshot(value);
            if (success && Math.abs(controlCenter.pendingBrightness - controlCenter.lastAppliedBrightness) >= 0.01)
                brightnessApplyTimer.restart();
        }
        function onVolumeSnapshotReady(value, muted, errorString) {
            if (errorString === "")
                controlCenter.applyVolumeSnapshot(value);
        }
        function onVolumeSetFinished(value, success, errorString) {
            controlCenter.volumeSetterRunning = false;
            if (success)
                controlCenter.applyVolumeSnapshot(value);
            if (success && Math.abs(controlCenter.pendingVolume - controlCenter.lastAppliedVolume) >= 0.01)
                volumeApplyTimer.restart();
        }
    }

    Timer {
        id: brightnessApplyTimer
        interval: 55
        repeat: false
        onTriggered: controlCenter.flushBrightness(false)
    }
    Timer {
        id: volumeApplyTimer
        interval: 55
        repeat: false
        onTriggered: controlCenter.flushVolume(false)
    }
    Timer {
        id: sliderIntroTimer
        interval: controlCenter.sliderIntroDelay
        repeat: false
        onTriggered: {
            controlCenter.sliderIntroPending = false;
            controlCenter.displayedBrightness = controlCenter.localBrightness;
            controlCenter.displayedVolume = controlCenter.localVolume;
        }
    }
    Timer {
        id: batteryModeRefreshTimer
        interval: 1500
        repeat: true
        onTriggered: {
            if (controlCenter.batteryModeRefreshPollsRemaining <= 0) {
                stop();
                return;
            }
            controlCenter.batteryModeRefreshPollsRemaining -= 1;
            controlCenter.refreshBatteryModeState();
            if (controlCenter.batteryModeRefreshPollsRemaining <= 0)
                stop();
        }
    }
    Timer {
        id: bluetoothScanStopTimer
        interval: 8000
        repeat: false
        onTriggered: {
            if (controlCenter.bluetoothAdapter && controlCenter.bluetoothAdapter.discovering)
                controlCenter.bluetoothAdapter.discovering = false;
            controlCenter.bluetoothInfoMessage = "";
        }
    }
    Timer {
        id: batteryDrawerSettleTimer
        interval: 300
        repeat: false
        onTriggered: controlCenter.batteryDrawerSettling = false
    }

    Connections {
        target: wifiController
        function onEnabledChanged() {
            if (!controlCenter.wifiEnabled)
                controlCenter.clearWifiPrompt();
        }
    }
    Connections {
        target: bluetoothAdapter
        function onEnabledChanged() {
            if (!controlCenter.bluetoothAdapter.enabled) {
                controlCenter.bluetoothPairAndConnectPath = "";
                controlCenter.bluetoothInfoMessage = "";
                controlCenter.bluetoothError = "";
                controlCenter.bluetoothScanStopTimer.stop();
            }
        }
        function onDiscoveringChanged() {
            if (!controlCenter.bluetoothAdapter.discovering)
                controlCenter.bluetoothScanStopTimer.stop();
        }
    }
    Connections {
        target: bluetoothPairingAgent
        function onRequestChanged() {
            controlCenter.bluetoothPendingSecretValue = "";
            if (controlCenter.bluetoothPairingActive) {
                controlCenter.bluetoothError = "";
                controlCenter.setConnectivityPanelOpen("bluetooth", true);
            }
        }
        function onRegistrationErrorChanged() {
            if (!controlCenter.bluetoothPairingAgent)
                return;
            if (!controlCenter.bluetoothPairingAgent.registered && controlCenter.bluetoothPairingAgent.registrationError.length > 0 && controlCenter.bluetoothPanelOpen)
                controlCenter.bluetoothError = controlCenter.bluetoothPairingAgent.registrationError;
        }
    }

    Item {
        anchors.fill: parent

        Column {
            id: mainView
            anchors.fill: parent
            spacing: 12
            visible: !controlCenter.anyConnectivityPanelOpen
            opacity: controlCenter.anyConnectivityPanelOpen ? 0 : 1
            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.InOutQuad
                }
            }

            Item {
                width: parent.width
                height: 28

                Item {
                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: 220
                    height: parent.height

                    Text {
                        id: timeLabel
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: currentTime
                        color: StyleTokens.textPrimaryBright
                        font.pixelSize: 19
                        font.family: heroFontFamily
                        font.weight: Font.Bold
                        font.letterSpacing: -0.45
                    }
                    Text {
                        anchors.left: timeLabel.right
                        anchors.leftMargin: 10
                        anchors.baseline: timeLabel.baseline
                        text: currentDateLabel
                        color: textSecondary
                        font.pixelSize: 12
                        font.family: textFontFamily
                        font.weight: Font.Medium
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 2
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5

                    Item {
                        readonly property int tipW: 2
                        readonly property int tipH: 5
                        readonly property int outerR: 6
                        readonly property int innerR: 3
                        readonly property int bw: 37
                        readonly property int bh: 17
                        width: bw + tipW + 1
                        height: bh
                        anchors.verticalCenter: parent.verticalCenter

                        readonly property bool roundedEnd: batteryCapacity >= 85
                        readonly property color bodyColor: batteryCapacity <= 20 ? StyleTokens.danger : StyleTokens.white
                        readonly property color emptyColor: Qt.rgba(1, 1, 1, 0.56)

                        Rectangle {
                            id: headerBatteryBody
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.bw
                            height: parent.bh
                            radius: parent.outerR
                            color: parent.emptyColor
                            clip: true

                            Rectangle {
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                radius: 0
                                topLeftRadius: parent.parent.outerR
                                bottomLeftRadius: parent.parent.outerR
                                topRightRadius: parent.parent.roundedEnd ? parent.parent.outerR : 0
                                bottomRightRadius: parent.parent.roundedEnd ? parent.parent.outerR : 0
                                width: Math.max(parent.parent.outerR * 2, parent.width * (batteryCapacity / 100.0))
                                color: parent.parent.bodyColor

                                Behavior on width {
                                    NumberAnimation {
                                        duration: 300
                                        easing.type: Easing.OutCubic
                                    }
                                }
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 300
                                    }
                                }
                            }

                            Row {
                                visible: isCharging
                                anchors.centerIn: parent
                                spacing: 2
                                z: 2
                                Text {
                                    text: batteryCapacity + ""
                                    color: "black"
                                    font.pixelSize: 12
                                    font.family: textFontFamily
                                    font.weight: Font.DemiBold
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: "\uf0e7"
                                    color: "#242424"
                                    font.pixelSize: 11
                                    font.family: iconFontFamily
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            Text {
                                visible: !isCharging
                                anchors.centerIn: parent
                                text: batteryCapacity + ""
                                color: batteryCapacity <= 20 ? "white" : "black"
                                font.pixelSize: 13
                                font.family: textFontFamily
                                font.weight: batteryCapacity <= 20 ? Font.Bold : Font.DemiBold
                                z: 2
                            }
                        }

                        Rectangle {
                            width: parent.tipW
                            height: parent.tipH
                            radius: 1
                            color: batteryCapacity >= 100 ? parent.bodyColor : parent.emptyColor
                            anchors.left: headerBatteryBody.right
                            anchors.leftMargin: 1
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on color {
                                ColorAnimation {
                                    duration: 300
                                }
                            }
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: 80

                Row {
                    id: connectivityCardsRow
                    anchors.fill: parent
                    spacing: 12

                    Rectangle {
                        id: wifiCard
                        width: (connectivityCardsRow.width - 12) / 2
                        height: 80
                        radius: 20
                        color: (wifiCardMouse.containsMouse || wifiPanelOpen) ? StyleTokens.connectivityCardHover : StyleTokens.connectivityCard
                        Behavior on color {
                            ColorAnimation {
                                duration: StyleTokens.durationFast
                            }
                        }

                        MouseArea {
                            id: wifiCardMouse
                            anchors.fill: parent
                            hoverEnabled: true
                        }
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.top: parent.top
                            anchors.topMargin: 12
                            text: wifiGlyph
                            color: wifiEnabled ? cardAccent : StyleTokens.textDisabled
                            font.pixelSize: 18
                            font.family: iconFontFamily
                        }
                        Rectangle {
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.top: parent.top
                            anchors.topMargin: 12
                            width: 34
                            height: 20
                            radius: 10
                            color: wifiEnabled ? StyleTokens.success : StyleTokens.switchOff
                            Behavior on color {
                                ColorAnimation {
                                    duration: StyleTokens.durationFast
                                }
                            }
                            Rectangle {
                                width: 16
                                height: 16
                                radius: 8
                                y: 2
                                x: wifiEnabled ? 16 : 2
                                color: StyleTokens.white
                                Behavior on x {
                                    NumberAnimation {
                                        duration: 140
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                enabled: wifiSupported && wifiAvailable && !wifiBusy
                                onClicked: controlCenter.toggleWifiEnabled()
                            }
                        }
                        Item {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            anchors.bottomMargin: 8
                            height: 30
                            Text {
                                anchors.left: parent.left
                                anchors.right: wifiChevron.left
                                anchors.rightMargin: 8
                                anchors.top: parent.top
                                text: "Wi-Fi"
                                color: textPrimary
                                font.pixelSize: 13
                                font.family: textFontFamily
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            Text {
                                anchors.left: parent.left
                                anchors.right: wifiChevron.left
                                anchors.rightMargin: 8
                                anchors.bottom: parent.bottom
                                text: wifiStatusText
                                color: StyleTokens.textMuted
                                font.pixelSize: 10
                                font.family: textFontFamily
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }
                            Text {
                                id: wifiChevron
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: "›"
                                color: StyleTokens.textSubtle
                                font.pixelSize: 17
                                font.family: textFontFamily
                                font.weight: Font.DemiBold
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: controlCenter.toggleConnectivityOverlay("wifi")
                            }
                        }
                    }

                    Rectangle {
                        id: bluetoothCard
                        width: (connectivityCardsRow.width - 12) / 2
                        height: 80
                        radius: 20
                        color: (bluetoothCardMouse.containsMouse || bluetoothPanelOpen) ? StyleTokens.connectivityCardHover : StyleTokens.connectivityCard
                        Behavior on color {
                            ColorAnimation {
                                duration: StyleTokens.durationFast
                            }
                        }

                        MouseArea {
                            id: bluetoothCardMouse
                            anchors.fill: parent
                            hoverEnabled: true
                        }
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.top: parent.top
                            anchors.topMargin: 12
                            text: bluetoothGlyph
                            color: bluetoothEnabled ? cardAccent : StyleTokens.textDisabled
                            font.pixelSize: 18
                            font.family: iconFontFamily
                        }
                        Rectangle {
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.top: parent.top
                            anchors.topMargin: 12
                            width: 34
                            height: 20
                            radius: 10
                            color: bluetoothEnabled ? StyleTokens.success : StyleTokens.switchOff
                            Behavior on color {
                                ColorAnimation {
                                    duration: StyleTokens.durationFast
                                }
                            }
                            Rectangle {
                                width: 16
                                height: 16
                                radius: 8
                                y: 2
                                x: bluetoothEnabled ? 16 : 2
                                color: StyleTokens.white
                                Behavior on x {
                                    NumberAnimation {
                                        duration: 140
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                enabled: bluetoothAvailable && !bluetoothBusy
                                onClicked: controlCenter.toggleBluetoothEnabled()
                            }
                        }
                        Item {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            anchors.bottomMargin: 8
                            height: 30
                            Text {
                                anchors.left: parent.left
                                anchors.right: bluetoothChevron.left
                                anchors.rightMargin: 8
                                anchors.top: parent.top
                                text: "Bluetooth"
                                color: textPrimary
                                font.pixelSize: 13
                                font.family: textFontFamily
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            Text {
                                anchors.left: parent.left
                                anchors.right: bluetoothChevron.left
                                anchors.rightMargin: 8
                                anchors.bottom: parent.bottom
                                text: bluetoothStatusText
                                color: StyleTokens.textMuted
                                font.pixelSize: 10
                                font.family: textFontFamily
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }
                            Text {
                                id: bluetoothChevron
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: "›"
                                color: StyleTokens.textSubtle
                                font.pixelSize: 17
                                font.family: textFontFamily
                                font.weight: Font.DemiBold
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: controlCenter.toggleConnectivityOverlay("bluetooth")
                            }
                        }
                    }
                }
            }

            Item {
                id: batteryDrawer
                readonly property real cardWidth: parent.width
                readonly property real halfCardWidth: (parent.width - 12) / 2
                readonly property real modeSlotWidth: 44
                readonly property real openDistance: controlCenter.batteryDrawerContentHeight + controlCenter.batteryDrawerContentGap

                width: parent.width
                height: controlCenter.batteryDrawerHandleHeight + controlCenter.batteryDrawerProgress * openDistance
                clip: true

                Item {
                    id: batteryDrawerContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: controlCenter.batteryDrawerContentHeight
                    y: -height + controlCenter.batteryDrawerProgress * height
                    opacity: Math.min(1, controlCenter.batteryDrawerProgress * 1.35)

                    Item {
                        id: drawerRow1
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: controlCenter.batteryModeCardHeight

                        Rectangle {
                            id: batteryModeCard
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: batteryDrawer.halfCardWidth
                            radius: 20
                            color: StyleTokens.connectivityCard
                            clip: true

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 14
                                anchors.top: parent.top
                                anchors.topMargin: 11
                                text: "Battery"
                                color: textPrimary
                                font.pixelSize: 13
                                font.family: textFontFamily
                                font.weight: Font.DemiBold
                            }
                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.top: parent.top
                                anchors.topMargin: 12
                                width: Math.max(0, parent.width - 80)
                                text: controlCenter.batteryModeError.length > 0 ? controlCenter.batteryModeError : (controlCenter.batteryModeInfoMessage.length > 0 ? controlCenter.batteryModeInfoMessage : controlCenter.batteryModeStatusText)
                                color: controlCenter.batteryModeError.length > 0 ? StyleTokens.error : StyleTokens.textMuted
                                horizontalAlignment: Text.AlignRight
                                font.pixelSize: 9
                                font.family: textFontFamily
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }

                            Item {
                                id: batteryModeCarousel
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 8
                                height: 34
                                clip: true

                                Item {
                                    id: batteryModeItems
                                    width: batteryDrawer.modeSlotWidth * 3
                                    height: parent.height
                                    x: batteryModeCarousel.width / 2 - batteryDrawer.modeSlotWidth / 2 - controlCenter.batteryModeIndex * batteryDrawer.modeSlotWidth + controlCenter.batteryModeDragOffset
                                    Behavior on x {
                                        enabled: !controlCenter.batteryModeSliderDragging
                                        NumberAnimation {
                                            duration: 180
                                            easing.type: Easing.OutCubic
                                        }
                                    }

                                    Repeater {
                                        model: 3
                                        delegate: Item {
                                            x: index * batteryDrawer.modeSlotWidth
                                            width: batteryDrawer.modeSlotWidth
                                            height: batteryModeCarousel.height
                                            opacity: index === controlCenter.batteryModeIndex ? 1 : 0.42
                                            Behavior on opacity {
                                                NumberAnimation {
                                                    duration: 140
                                                    easing.type: Easing.OutCubic
                                                }
                                            }

                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: index === controlCenter.batteryModeIndex ? 32 : 28
                                                height: index === controlCenter.batteryModeIndex ? 28 : 24
                                                radius: 12
                                                color: index === controlCenter.batteryModeIndex ? StyleTokens.textPrimary : "#292a2f"
                                                Behavior on width {
                                                    NumberAnimation {
                                                        duration: 140
                                                        easing.type: Easing.OutCubic
                                                    }
                                                }
                                                Behavior on height {
                                                    NumberAnimation {
                                                        duration: 140
                                                        easing.type: Easing.OutCubic
                                                    }
                                                }
                                                Behavior on color {
                                                    ColorAnimation {
                                                        duration: 140
                                                    }
                                                }

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: controlCenter.batteryModeGlyphs[index]
                                                    color: index === controlCenter.batteryModeIndex ? StyleTokens.module : StyleTokens.textDim
                                                    font.pixelSize: index === controlCenter.batteryModeIndex ? 15 : 13
                                                    font.family: controlCenter.iconFontFamily
                                                }
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    width: 22
                                    height: 2
                                    radius: 1
                                    color: "#5d6068"
                                    opacity: 0.75
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    property real startX: 0
                                    property int startIndex: 1
                                    property bool moved: false
                                    function clampDrag(delta) {
                                        return Math.max(-batteryDrawer.modeSlotWidth, Math.min(batteryDrawer.modeSlotWidth, delta));
                                    }
                                    onPressed: function (mouse) {
                                        startX = mouse.x;
                                        startIndex = controlCenter.batteryModeIndex;
                                        moved = false;
                                        controlCenter.batteryModeInfoMessage = "";
                                        controlCenter.batteryModeError = "";
                                        controlCenter.batteryModeSliderDragging = true;
                                        controlCenter.batteryModeDragOffset = 0;
                                    }
                                    onPositionChanged: function (mouse) {
                                        if (!pressed)
                                            return;
                                        const delta = mouse.x - startX;
                                        if (!moved && Math.abs(delta) < 4)
                                            return;
                                        moved = true;
                                        controlCenter.batteryModeDragOffset = clampDrag(delta);
                                    }
                                    onReleased: function (mouse) {
                                        const delta = mouse.x - startX;
                                        let nextIndex = startIndex;
                                        if (delta <= -18)
                                            nextIndex = Math.min(2, startIndex + 1);
                                        else if (delta >= 18)
                                            nextIndex = Math.max(0, startIndex - 1);
                                        else if (mouse.x < width / 2 - batteryDrawer.modeSlotWidth / 2)
                                            nextIndex = Math.max(0, startIndex - 1);
                                        else if (mouse.x > width / 2 + batteryDrawer.modeSlotWidth / 2)
                                            nextIndex = Math.min(2, startIndex + 1);
                                        controlCenter.batteryModeSliderDragging = false;
                                        controlCenter.batteryModeDragOffset = 0;
                                        controlCenter.selectBatteryMode(nextIndex);
                                    }
                                    onCanceled: {
                                        controlCenter.batteryModeSliderDragging = false;
                                        controlCenter.batteryModeDragOffset = 0;
                                        controlCenter.setBatteryModeVisualIndex(controlCenter.batteryModeAppliedIndex, true);
                                    }
                                }
                            }
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: batteryDrawer.halfCardWidth
                            radius: 20
                            color: StyleTokens.connectivityCard

                            MouseArea {
                                anchors.fill: parent
                                z: 0
                                enabled: !controlCenter.nightLightBusy
                                onClicked: controlCenter.toggleNightLight()
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 14
                                anchors.top: parent.top
                                anchors.topMargin: 12
                                text: controlCenter.nightLightGlyph
                                color: controlCenter.nightLightEnabled ? StyleTokens.warning : StyleTokens.textDisabled
                                font.pixelSize: 16
                                font.family: controlCenter.iconFontFamily
                                z: 1
                            }
                            Rectangle {
                                id: nightLightSwitch
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.top: parent.top
                                anchors.topMargin: 12
                                width: 34
                                height: 20
                                radius: 10
                                color: controlCenter.nightLightEnabled ? StyleTokens.warning : StyleTokens.switchOff
                                opacity: controlCenter.nightLightBusy ? 0.5 : 1.0
                                z: 1
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 140
                                    }
                                }
                                Rectangle {
                                    width: 16
                                    height: 16
                                    radius: 8
                                    y: 2
                                    x: controlCenter.nightLightEnabled ? 16 : 2
                                    color: StyleTokens.white
                                    Behavior on x {
                                        NumberAnimation {
                                            duration: 140
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }
                            }
                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 14
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 20
                                text: "Night Light"
                                color: textPrimary
                                font.pixelSize: 12
                                font.family: textFontFamily
                                font.weight: Font.DemiBold
                                z: 1
                            }
                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 14
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 8
                                text: controlCenter.nightLightEnabled ? (controlCenter.nightLightTemperature + "K") : "Off"
                                color: StyleTokens.textMuted
                                font.pixelSize: 10
                                font.family: textFontFamily
                                font.weight: Font.Medium
                                z: 1
                            }
                        }
                    }

                    Rectangle {
                        id: focusCard
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        width: batteryDrawer.halfCardWidth
                        height: controlCenter.toggleCardHeight
                        radius: 20
                        color: StyleTokens.connectivityCard

                        MouseArea {
                            anchors.fill: parent
                            z: 0
                            enabled: !controlCenter.focusBusy
                            onClicked: controlCenter.toggleFocus()
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.top: parent.top
                            anchors.topMargin: 12
                            text: controlCenter.focusGlyph
                            color: controlCenter.focusEnabled ? StyleTokens.accent : StyleTokens.textDisabled
                            font.pixelSize: 16
                            font.family: controlCenter.iconFontFamily
                            z: 1
                        }

                        Rectangle {
                            id: focusSwitch
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.top: parent.top
                            anchors.topMargin: 12
                            width: 34
                            height: 20
                            radius: 10
                            color: controlCenter.focusEnabled ? StyleTokens.accent : StyleTokens.switchOff
                            opacity: controlCenter.focusBusy ? 0.5 : 1.0
                            z: 1
                            Behavior on color {
                                ColorAnimation {
                                    duration: 140
                                }
                            }
                            Rectangle {
                                width: 16
                                height: 16
                                radius: 8
                                y: 2
                                x: controlCenter.focusEnabled ? 16 : 2
                                color: StyleTokens.white
                                Behavior on x {
                                    NumberAnimation {
                                        duration: 140
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 20
                            text: "Focus"
                            color: textPrimary
                            font.pixelSize: 12
                            font.family: textFontFamily
                            font.weight: Font.DemiBold
                            z: 1
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 8
                            text: controlCenter.focusEnabled ? "Paused" : "Off"
                            color: StyleTokens.textMuted
                            font.pixelSize: 10
                            font.family: textFontFamily
                            font.weight: Font.Medium
                            z: 1
                        }
                    }
                }

                Rectangle {
                    id: batteryDrawerTunnelShade
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: Math.max(1, controlCenter.batteryDrawerContentGap * 0.35)
                    z: 6
                    opacity: Math.min(0.34, controlCenter.batteryDrawerProgress * 0.45)
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: "#9a000000"
                        }
                        GradientStop {
                            position: 1
                            color: StyleTokens.clearBlack
                        }
                    }
                }

                Item {
                    id: batteryDrawerHandle
                    anchors.left: parent.left
                    anchors.right: parent.right
                    y: controlCenter.batteryDrawerProgress * batteryDrawer.openDistance
                    height: controlCenter.batteryDrawerHandleHeight
                    z: 10

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 8
                        width: 48
                        height: 5
                        radius: 3
                        color: controlCenter.batteryDrawerOpen ? "#d4d6dc" : StyleTokens.textSubtle
                        opacity: 0.88
                    }

                    MouseArea {
                        id: batteryDrawerHandleArea
                        anchors.fill: parent
                        property real pointerGrabOffset: 0
                        property bool moved: false
                        property bool suppressClick: false
                        function pointerY(mouse) {
                            return batteryDrawerHandle.mapToItem(controlCenter, mouse.x, mouse.y).y;
                        }
                        function itemTop(item) {
                            return item.mapToItem(controlCenter, 0, 0).y;
                        }
                        onPressed: function (mouse) {
                            batteryDrawerSettleTimer.stop();
                            controlCenter.batteryDrawerSettling = false;
                            pointerGrabOffset = pointerY(mouse) - itemTop(batteryDrawerHandle);
                            moved = false;
                            suppressClick = false;
                            controlCenter.batteryDrawerDragging = true;
                        }
                        onPositionChanged: function (mouse) {
                            const nextHandleY = pointerY(mouse) - pointerGrabOffset - itemTop(batteryDrawer);
                            if (!moved && Math.abs(nextHandleY - batteryDrawerHandle.y) < 4)
                                return;
                            moved = true;
                            suppressClick = true;
                            controlCenter.batteryDrawerProgress = controlCenter.clamp01(nextHandleY / batteryDrawer.openDistance);
                        }
                        onReleased: {
                            controlCenter.batteryDrawerDragging = false;
                            if (moved)
                                controlCenter.setBatteryDrawerOpen(controlCenter.batteryDrawerProgress >= 0.55);
                        }
                        onCanceled: {
                            controlCenter.batteryDrawerDragging = false;
                            controlCenter.setBatteryDrawerOpen(controlCenter.batteryDrawerOpen);
                        }
                        onClicked: {
                            if (suppressClick) {
                                suppressClick = false;
                                return;
                            }
                            controlCenter.toggleBatteryDrawer();
                        }
                    }
                }
            }

            ControlSliderCard {
                id: brightnessCard
                width: parent.width
                height: 76
                title: "Display"
                iconText: controlCenter.brightnessIconGlyph
                iconFontFamily: controlCenter.iconFontFamily
                textFontFamily: controlCenter.textFontFamily
                value: controlCenter.displayedBrightness
                knobSize: controlCenter.sliderKnobSize
                moduleColor: controlCenter.moduleColor
                moduleHover: controlCenter.moduleHover
                trackColor: controlCenter.trackColor
                textPrimary: controlCenter.textPrimary
                textSecondary: controlCenter.textSecondary
                onInteractionStarted: {
                    if (controlCenter.sliderIntroPending) {
                        sliderIntroTimer.stop();
                        controlCenter.sliderIntroPending = false;
                        controlCenter.displayedBrightness = controlCenter.localBrightness;
                        controlCenter.displayedVolume = controlCenter.localVolume;
                    }
                }
                onValueMoved: function (value) {
                    controlCenter.queueBrightness(value);
                }
                onCommitRequested: {
                    brightnessApplyTimer.stop();
                    controlCenter.flushBrightness(true);
                }
                onCancelRequested: SystemServices.requestBrightness()
            }

            ControlSliderCard {
                id: volumeCard
                width: parent.width
                height: 76
                title: "Sound"
                iconText: controlCenter.volumeIconGlyph
                iconFontFamily: controlCenter.iconFontFamily
                textFontFamily: controlCenter.textFontFamily
                value: controlCenter.displayedVolume
                knobSize: controlCenter.sliderKnobSize
                moduleColor: controlCenter.moduleColor
                moduleHover: controlCenter.moduleHover
                trackColor: controlCenter.trackColor
                textPrimary: controlCenter.textPrimary
                textSecondary: controlCenter.textSecondary
                onInteractionStarted: {
                    if (controlCenter.sliderIntroPending) {
                        sliderIntroTimer.stop();
                        controlCenter.sliderIntroPending = false;
                        controlCenter.displayedBrightness = controlCenter.localBrightness;
                        controlCenter.displayedVolume = controlCenter.localVolume;
                    }
                }
                onValueMoved: function (value) {
                    controlCenter.queueVolume(value);
                }
                onCommitRequested: {
                    volumeApplyTimer.stop();
                    controlCenter.flushVolume(true);
                }
                onCancelRequested: SystemServices.requestVolume()
            }
        }

        Item {
            anchors.fill: parent
            visible: controlCenter.anyConnectivityPanelOpen
            opacity: controlCenter.anyConnectivityPanelOpen ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.InOutQuad
                }
            }

            Item {
                id: connectivityHeader
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 36

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    text: "←"
                    color: StyleTokens.textPrimary
                    font.pixelSize: 16
                    font.family: controlCenter.textFontFamily
                    font.weight: Font.DemiBold
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -8
                        onClicked: controlCenter.closeConnectivityPanels()
                    }
                }
                Text {
                    anchors.centerIn: parent
                    text: controlCenter.wifiPanelOpen ? "Wi-Fi" : "Bluetooth"
                    color: StyleTokens.textPrimary
                    font.pixelSize: 15
                    font.family: controlCenter.heroFontFamily
                    font.weight: Font.Bold
                }
                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    width: 34
                    height: 20
                    radius: 10
                    color: (controlCenter.wifiPanelOpen ? controlCenter.wifiEnabled : controlCenter.bluetoothEnabled) ? StyleTokens.success : StyleTokens.switchOff
                    Behavior on color {
                        ColorAnimation {
                            duration: 140
                        }
                    }
                    Rectangle {
                        width: 16
                        height: 16
                        radius: 8
                        y: 2
                        x: (controlCenter.wifiPanelOpen ? controlCenter.wifiEnabled : controlCenter.bluetoothEnabled) ? 16 : 2
                        color: StyleTokens.white
                        Behavior on x {
                            NumberAnimation {
                                duration: 140
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (controlCenter.wifiPanelOpen)
                                controlCenter.toggleWifiEnabled();
                            else
                                controlCenter.toggleBluetoothEnabled();
                        }
                    }
                }
            }

            ConnectivityDetailPanel {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: connectivityHeader.bottom
                anchors.bottom: parent.bottom
                provider: controlCenter
                panelKind: controlCenter.wifiPanelOpen ? "wifi" : "bluetooth"
                iconFontFamily: controlCenter.iconFontFamily
                textFontFamily: controlCenter.textFontFamily
                heroFontFamily: controlCenter.heroFontFamily
                presentationProgress: controlCenter.anyConnectivityPanelOpen ? 1 : 0
            }
        }
    }
}
