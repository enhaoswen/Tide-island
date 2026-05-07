import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Scope {
    id: shellRoot

    readonly property bool screenRecordingActive: recordingBridge.recordingActive
    property bool shuttingDown: false
    property bool setupLaunchRequested: false

    UserConfig {
        id: userConfig
    }

    function forEachWindow(callback) {
        const windows = panelVariants.instances ? panelVariants.instances : [];
        for (let index = 0; index < windows.length; index++) {
            const window = windows[index];
            if (window)
                callback(window);
        }
    }

    function showNotificationAll(appName, summary, body) {
        shellRoot.forEachWindow((window) => {
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
        shellRoot.forEachWindow((window) => window.prepareOverview());
    }

    function cancelPreparedOverviewAll() {
        shellRoot.forEachWindow((window) => window.cancelPreparedOverview());
    }

    function openOverviewAll() {
        shellRoot.forEachWindow((window) => window.openOverview());
    }

    function closeOverviewAll() {
        shellRoot.forEachWindow((window) => window.closeOverview());
    }

    function toggleOverviewAll() {
        if (shellRoot.anyOverviewOpen())
            shellRoot.closeOverviewAll();
        else
            shellRoot.openOverviewAll();
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
            shellRoot.forEachWindow((window) => {
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

    Process {
        id: setupCheck

        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0 || shellRoot.setupLaunchRequested)
                return;

            shellRoot.setupLaunchRequested = true;
            setupLauncher.exec([Quickshell.shellDir + "/bin/tide-island-setup", "--launch"]);
        }
    }

    Process {
        id: setupLauncher
    }

    QtObject {
        id: notificationBridge

        property bool captureActive: false
        property int captureStage: -1
        property string pendingAppName: ""
        property string pendingSummary: ""
        property string pendingBody: ""

        function resetCapture() {
            captureActive = false;
            captureStage = -1;
            pendingAppName = "";
            pendingSummary = "";
            pendingBody = "";
        }

        function beginCapture() {
            resetCapture();
            captureActive = true;
            captureStage = 0;
        }

        function decodeMonitorString(line) {
            const match = line.match(/^\s*string "(.*)"\s*$/);
            if (!match) return "";

            try {
                return JSON.parse("\"" + match[1] + "\"");
            } catch (error) {
                return match[1]
                    .replace(/\\"/g, "\"")
                    .replace(/\\\\/g, "\\");
            }
        }

        function commitCapture() {
            shellRoot.showNotificationAll(pendingAppName, pendingSummary, pendingBody);
            resetCapture();
        }

        function handleLine(rawLine) {
            const line = String(rawLine === undefined || rawLine === null ? "" : rawLine).trim();
            if (line === "") return;

            if (line.indexOf("member=Notify") !== -1) {
                beginCapture();
                return;
            }

            if (!captureActive) return;

            switch (captureStage) {
            case 0:
                if (!line.startsWith("string ")) return;
                pendingAppName = decodeMonitorString(line);
                captureStage = 1;
                return;
            case 1:
                if (!line.startsWith("uint32 ")) return;
                captureStage = 2;
                return;
            case 2:
                if (!line.startsWith("string ")) return;
                captureStage = 3;
                return;
            case 3:
                if (!line.startsWith("string ")) return;
                pendingSummary = decodeMonitorString(line);
                captureStage = 4;
                return;
            case 4:
                if (!line.startsWith("string ")) return;
                pendingBody = decodeMonitorString(line);
                commitCapture();
                return;
            default:
                resetCapture();
            }
        }
    }

    Timer {
        id: notificationMonitorRestartTimer
        interval: 1200
        repeat: false
        onTriggered: notificationMonitor.running = true
    }

    Process {
        id: notificationMonitor
        running: true
        command: [
            "dbus-monitor",
            "--session",
            "type='method_call',interface='org.freedesktop.Notifications',member='Notify'"
        ]
        stdout: SplitParser {
            splitMarker: "\n"

            onRead: function(data) {
                notificationBridge.handleLine(data);
            }
        }
        onExited: {
            if (!shellRoot.shuttingDown)
                notificationMonitorRestartTimer.restart();
        }
    }

    QtObject {
        id: recordingBridge

        property var activeSessions: ({})
        property int activeSessionCount: 0
        property string pendingScreenCastMember: ""
        property string pendingSessionCandidate: ""
        property bool portalPipeWireActive: false
        readonly property bool recordingActive: activeSessionCount > 0 || portalPipeWireActive

        function extractHeaderPath(line) {
            const match = line.match(/\bpath=([^;]+);/);
            return match ? match[1] : "";
        }

        function extractObjectPath(line) {
            const match = line.match(/^object path "?([^"\s]+)"?/);
            return match ? match[1] : "";
        }

        function addSession(path) {
            const normalizedPath = String(path || "");
            if (normalizedPath === "" || activeSessions[normalizedPath])
                return;

            const nextSessions = {};
            for (const sessionPath in activeSessions)
                nextSessions[sessionPath] = activeSessions[sessionPath];
            nextSessions[normalizedPath] = true;

            activeSessions = nextSessions;
            activeSessionCount += 1;
        }

        function removeSession(path) {
            const normalizedPath = String(path || "");
            if (normalizedPath === "" || !activeSessions[normalizedPath])
                return;

            const nextSessions = {};
            for (const sessionPath in activeSessions) {
                if (sessionPath !== normalizedPath)
                    nextSessions[sessionPath] = activeSessions[sessionPath];
            }

            activeSessions = nextSessions;
            activeSessionCount = Math.max(0, activeSessionCount - 1);
        }

        function screenCastMemberHasSessionArgument(memberName) {
            return memberName === "SelectSources"
                || memberName === "Start"
                || memberName === "OpenPipeWireRemote";
        }

        function updatePortalPipeWireActive(active) {
            portalPipeWireActive = !!active;
        }

        function requestSnapshot() {
            recordingPortalSnapshotDebounce.restart();
        }

        function handlePipeWireLine(rawLine) {
            const line = String(rawLine === undefined || rawLine === null ? "" : rawLine).trim();
            if (line === "")
                return;

            const lowerLine = line.toLowerCase();
            const relevantVideoLine = lowerLine.indexOf("media.class = \"video/source\"") !== -1
                || lowerLine.indexOf("media.class = \"stream/input/video\"") !== -1
                || lowerLine.indexOf("xdg-desktop-portal") !== -1
                || lowerLine.indexOf("screencast") !== -1
                || lowerLine.indexOf("screen-cast") !== -1
                || lowerLine.indexOf("screen_cast") !== -1
                || lowerLine.indexOf("xdpw") !== -1;
            const removalMayAffectActiveCapture = portalPipeWireActive
                && (lowerLine.indexOf("removed:") !== -1 || lowerLine.indexOf("destroyed:") !== -1);

            if (relevantVideoLine || removalMayAffectActiveCapture)
                requestSnapshot();
        }

        function pipeWireBlockLooksLikeScreenCast(blockText) {
            const block = String(blockText || "");
            if (block.indexOf("media.class = \"Video/Source\"") === -1)
                return false;

            const lowerBlock = block.toLowerCase();
            if (lowerBlock.indexOf("media.role = \"camera\"") !== -1)
                return false;
            if (lowerBlock.indexOf("v4l2") !== -1)
                return false;

            return lowerBlock.indexOf("xdg-desktop-portal") !== -1
                || lowerBlock.indexOf("screencast") !== -1
                || lowerBlock.indexOf("screen-cast") !== -1
                || lowerBlock.indexOf("screen_cast") !== -1
                || lowerBlock.indexOf("xdpw") !== -1;
        }

        function applyPipeWireSnapshot(text) {
            const source = String(text === undefined || text === null ? "" : text);
            const blocks = source.split(/\n(?=\s*id\s+\d+,)/);

            for (let index = 0; index < blocks.length; index++) {
                if (pipeWireBlockLooksLikeScreenCast(blocks[index])) {
                    updatePortalPipeWireActive(true);
                    return;
                }
            }

            updatePortalPipeWireActive(false);
        }

        function handleLine(rawLine) {
            const line = String(rawLine === undefined || rawLine === null ? "" : rawLine).trim();
            if (line === "")
                return;

            const closedMatch = line.match(/^signal\b.*interface=org\.freedesktop\.portal\.Session; member=Closed/);
            if (closedMatch) {
                removeSession(extractHeaderPath(line));
                pendingScreenCastMember = "";
                pendingSessionCandidate = "";
                requestSnapshot();
                return;
            }

            const methodMatch = line.match(/^method_call\b.*interface=org\.freedesktop\.portal\.ScreenCast; member=([A-Za-z0-9_]+)/);
            if (methodMatch) {
                pendingScreenCastMember = methodMatch[1];
                pendingSessionCandidate = "";
                return;
            }

            if (screenCastMemberHasSessionArgument(pendingScreenCastMember) && line.startsWith("object path ")) {
                const sessionPath = extractObjectPath(line);
                if (sessionPath.indexOf("/org/freedesktop/portal/desktop/session/") === 0) {
                    addSession(sessionPath);
                    pendingSessionCandidate = sessionPath;
                    if (pendingScreenCastMember === "OpenPipeWireRemote") {
                        pendingScreenCastMember = "";
                        pendingSessionCandidate = "";
                    }
                    requestSnapshot();
                }
                return;
            }

            if (pendingScreenCastMember === "Start" && line.startsWith("string ")) {
                pendingScreenCastMember = "";
                pendingSessionCandidate = "";
                return;
            }

            if (pendingScreenCastMember === "SelectSources" && line.indexOf("array [") !== -1) {
                pendingScreenCastMember = "";
                pendingSessionCandidate = "";
            }
        }
    }

    Timer {
        id: recordingPortalSnapshotDebounce
        interval: 250
        repeat: false
        onTriggered: {
            if (!recordingPortalSnapshot.running)
                recordingPortalSnapshot.exec(recordingPortalSnapshot.command);
        }
    }

    Process {
        id: recordingPortalSnapshot
        command: ["pw-cli", "ls", "Node"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: recordingBridge.applyPipeWireSnapshot(text)
        }
        onExited: function(exitCode) {
            if (exitCode !== 0)
                recordingBridge.updatePortalPipeWireActive(false);
        }
    }

    Timer {
        id: pipeWireMonitorRestartTimer
        interval: 1200
        repeat: false
        onTriggered: pipeWireMonitor.running = true
    }

    Process {
        id: pipeWireMonitor
        running: true
        command: ["pw-mon", "-p", "-a"]
        stdout: SplitParser {
            splitMarker: "\n"

            onRead: function(data) {
                recordingBridge.handlePipeWireLine(data);
            }
        }
        onExited: {
            if (!shellRoot.shuttingDown)
                pipeWireMonitorRestartTimer.restart();
        }
    }

    Timer {
        id: recordingPortalMonitorRestartTimer
        interval: 1200
        repeat: false
        onTriggered: recordingPortalMonitor.running = true
    }

    Process {
        id: recordingPortalMonitor
        running: true
        command: [
            "dbus-monitor",
            "--session",
            "type='method_call',interface='org.freedesktop.portal.ScreenCast'",
            "type='signal',sender='org.freedesktop.portal.Desktop',interface='org.freedesktop.portal.Session',member='Closed'"
        ]
        stdout: SplitParser {
            splitMarker: "\n"

            onRead: function(data) {
                recordingBridge.handleLine(data);
            }
        }
        onExited: {
            if (!shellRoot.shuttingDown)
                recordingPortalMonitorRestartTimer.restart();
        }
    }

    Component.onDestruction: {
        shuttingDown = true;
        notificationMonitorRestartTimer.stop();
        recordingPortalMonitorRestartTimer.stop();
        pipeWireMonitorRestartTimer.stop();
        recordingPortalSnapshotDebounce.stop();
        if (notificationMonitor.running)
            notificationMonitor.running = false;
        if (recordingPortalSnapshot.running)
            recordingPortalSnapshot.running = false;
        if (pipeWireMonitor.running)
            pipeWireMonitor.running = false;
        if (recordingPortalMonitor.running)
            recordingPortalMonitor.running = false;
    }

    Component.onCompleted: {
        setupCheck.exec([Quickshell.shellDir + "/bin/tide-island-setup", "--check"]);
        recordingBridge.requestSnapshot();
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
