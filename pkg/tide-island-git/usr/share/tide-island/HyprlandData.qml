import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Item {
    id: root

    visible: false

    property var windowList: []
    property var windowByAddress: ({})
    property var workspaces: []
    property var activeWorkspace: null
    property var monitors: []
    property bool clientsReady: false
    property bool monitorsReady: false
    property bool workspacesReady: false
    property bool activeWorkspaceReady: false
    property bool clientsRefreshPending: false
    property bool monitorsRefreshPending: false
    property bool workspacesRefreshPending: false
    property bool activeWorkspaceRefreshPending: false
    readonly property bool ready: clientsReady && monitorsReady && workspacesReady && activeWorkspaceReady

    function parseJson(text, fallback) {
        const source = (text || "").trim();
        if (!source)
            return fallback;

        try {
            return JSON.parse(source);
        } catch (error) {
            console.log("[HyprlandData] Failed to parse hyprctl output:", error);
            return fallback;
        }
    }

    function rebuildWindowIndex() {
        const byAddress = {};
        for (let index = 0; index < root.windowList.length; index++)
            byAddress[String(root.windowList[index].address || "").toLowerCase()] = root.windowList[index];
        root.windowByAddress = byAddress;
    }

    function requestRefresh(refreshClients, refreshMonitors, refreshWorkspaces, refreshActiveWorkspace, immediate) {
        clientsRefreshPending = clientsRefreshPending || refreshClients;
        monitorsRefreshPending = monitorsRefreshPending || refreshMonitors;
        workspacesRefreshPending = workspacesRefreshPending || refreshWorkspaces;
        activeWorkspaceRefreshPending = activeWorkspaceRefreshPending || refreshActiveWorkspace;

        if (immediate) {
            refreshTimer.stop();
            flushRefresh();
        } else {
            refreshTimer.restart();
        }
    }

    function queueRefresh(refreshClients, refreshMonitors, refreshWorkspaces, refreshActiveWorkspace) {
        requestRefresh(refreshClients, refreshMonitors, refreshWorkspaces, refreshActiveWorkspace, false);
    }

    function updateAll() {
        requestRefresh(true, true, true, true, true);
    }

    function flushRefresh() {
        if (clientsRefreshPending && !clientsProcess.running) {
            clientsRefreshPending = false;
            clientsProcess.running = true;
        }
        if (monitorsRefreshPending && !monitorsProcess.running) {
            monitorsRefreshPending = false;
            monitorsProcess.running = true;
        }
        if (workspacesRefreshPending && !workspacesProcess.running) {
            workspacesRefreshPending = false;
            workspacesProcess.running = true;
        }
        if (activeWorkspaceRefreshPending && !activeWorkspaceProcess.running) {
            activeWorkspaceRefreshPending = false;
            activeWorkspaceProcess.running = true;
        }
    }

    function queueRefreshForEvent(event) {
        if (!event || !event.name)
            return;

        const name = String(event.name);
        if (["openlayer", "closelayer", "screencast"].indexOf(name) !== -1)
            return;

        if (name === "configreloaded") {
            queueRefresh(true, true, true, true);
            return;
        }

        const affectsActiveWorkspace = name === "workspace"
            || name === "workspacev2"
            || name === "focusedmon"
            || name === "focusedmonv2";
        const affectsWorkspaces = affectsActiveWorkspace
            || name.indexOf("workspace") !== -1;
        const affectsMonitors = name.indexOf("monitor") !== -1
            || name === "focusedmon"
            || name === "focusedmonv2";
        const affectsClients = name.indexOf("window") !== -1
            || name === "changefloatingmode"
            || name === "fullscreen"
            || name === "pin"
            || name === "urgent"
            || name === "minimize"
            || name === "moveintogroup"
            || name === "moveoutofgroup"
            || name === "togglegroup";

        if (!affectsClients && !affectsMonitors && !affectsWorkspaces && !affectsActiveWorkspace)
            return;

        queueRefresh(affectsClients, affectsMonitors, affectsWorkspaces, affectsActiveWorkspace);
    }

    Component.onCompleted: updateAll()
    Component.onDestruction: {
        refreshTimer.stop();
        if (clientsProcess.running) clientsProcess.running = false;
        if (monitorsProcess.running) monitorsProcess.running = false;
        if (workspacesProcess.running) workspacesProcess.running = false;
        if (activeWorkspaceProcess.running) activeWorkspaceProcess.running = false;
    }

    Timer {
        id: refreshTimer

        interval: 90
        repeat: false

        onTriggered: root.flushRefresh()
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            root.queueRefreshForEvent(event);
        }
    }

    Process {
        id: clientsProcess

        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            id: clientsCollector

            onStreamFinished: {
                root.windowList = root.parseJson(clientsCollector.text, []);
                root.rebuildWindowIndex();
                root.clientsReady = true;
            }
        }
        onExited: root.flushRefresh()
    }

    Process {
        id: monitorsProcess

        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            id: monitorsCollector

            onStreamFinished: {
                root.monitors = root.parseJson(monitorsCollector.text, []);
                root.monitorsReady = true;
            }
        }
        onExited: root.flushRefresh()
    }

    Process {
        id: workspacesProcess

        command: ["hyprctl", "workspaces", "-j"]
        stdout: StdioCollector {
            id: workspacesCollector

            onStreamFinished: {
                const rawWorkspaces = root.parseJson(workspacesCollector.text, []);
                const filtered = rawWorkspaces.filter((workspace) => workspace.id >= 1 && workspace.id <= 100);
                root.workspaces = filtered;
                root.workspacesReady = true;
            }
        }
        onExited: root.flushRefresh()
    }

    Process {
        id: activeWorkspaceProcess

        command: ["hyprctl", "activeworkspace", "-j"]
        stdout: StdioCollector {
            id: activeWorkspaceCollector

            onStreamFinished: {
                root.activeWorkspace = root.parseJson(activeWorkspaceCollector.text, null);
                root.activeWorkspaceReady = true;
            }
        }
        onExited: root.flushRefresh()
    }
}
