pragma ComponentBehavior: Bound

import QtQuick
import IslandBackend
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import "../common"

Item {
    id: root

    readonly property var userConfig: UserConfig

    HyprlandDispatch {
        id: hyprDispatch
    }

    required property var screen
    required property var hyprlandData

    property bool showCondition: false
    property bool previewsEnabled: showCondition
    property string textFontFamily: userConfig.textFontFamily
    property string heroFontFamily: userConfig.heroFontFamily
    property string wallpaperPath: userConfig.wallpaperPath
    property real windowCornerRadius: 15
    property real scale: 0.18
    property int rows: 2
    property int columns: 5
    property bool orderRightLeft: false
    property bool orderBottomUp: false
    property bool centerIcons: true

    readonly property real wallpaperCacheScaleMultiplier: 1.75
    readonly property int cachedWallpaperWidth: Math.max(1, Math.round(workspaceImplicitWidth * wallpaperCacheScaleMultiplier))
    readonly property int cachedWallpaperHeight: Math.max(1, Math.round(workspaceImplicitHeight * wallpaperCacheScaleMultiplier))

    readonly property var monitor: screen ? Hyprland.monitorFor(screen) : Hyprland.focusedMonitor
    readonly property var monitorData: findMonitorData(monitor ? monitor.id : -1)
    readonly property int workspacesShown: rows * columns
    readonly property int effectiveActiveWorkspaceId: {
        const workspaceId = monitor && monitor.activeWorkspace
            ? monitor.activeWorkspace.id
            : (hyprlandData && hyprlandData.activeWorkspace ? hyprlandData.activeWorkspace.id : 1);
        return Math.max(1, Math.min(100, workspaceId || 1));
    }
    readonly property int workspaceGroup: Math.floor((effectiveActiveWorkspaceId - 1) / workspacesShown)
    readonly property real workspaceSpacing: 6
    readonly property real outerPadding: 14
    readonly property real largeWorkspaceRadius: 30
    readonly property real smallWorkspaceRadius: 16
    readonly property int workspaceOverviewCellAcceptedButtons: Qt.LeftButton
    readonly property int workspaceOverviewWindowAcceptedButtons: userConfig.mouseButtonsMask([
        userConfig.workspaceOverviewWindowDragButton,
        1,
        3
    ])
    readonly property color activeBorderColor: StyleTokens.workspaceActiveBorder
    readonly property color cardColor: StyleTokens.overviewCard
    readonly property color cardBorderColor: StyleTokens.overviewBorder
    readonly property color workspaceColor: StyleTokens.workspaceCell
    readonly property color workspaceHoverColor: StyleTokens.workspaceCellHover
    readonly property color workspaceBorderHoverColor: StyleTokens.workspaceCellBorderHover
    readonly property real workspaceImplicitWidth: {
        const reserved = monitorData && monitorData.reserved ? monitorData.reserved : [0, 0, 0, 0];
        const screenWidth = monitor ? monitor.width : (screen ? screen.width : 1920);
        const screenHeight = monitor ? monitor.height : (screen ? screen.height : 1080);
        const transform = monitorData && monitorData.transform !== undefined ? monitorData.transform : 0;
        const monitorScale = monitor && monitor.scale ? monitor.scale : 1;
        const baseWidth = transform % 2 === 1 ? screenHeight : screenWidth;
        return Math.max(180, (baseWidth - reserved[0] - reserved[2]) * scale / monitorScale);
    }
    readonly property real workspaceImplicitHeight: {
        const reserved = monitorData && monitorData.reserved ? monitorData.reserved : [0, 0, 0, 0];
        const screenWidth = monitor ? monitor.width : (screen ? screen.width : 1920);
        const screenHeight = monitor ? monitor.height : (screen ? screen.height : 1080);
        const transform = monitorData && monitorData.transform !== undefined ? monitorData.transform : 0;
        const monitorScale = monitor && monitor.scale ? monitor.scale : 1;
        const baseHeight = transform % 2 === 1 ? screenWidth : screenHeight;
        return Math.max(120, (baseHeight - reserved[1] - reserved[3]) * scale / monitorScale);
    }

    property int draggingFromWorkspace: -1
    property int draggingTargetWorkspace: -1
    property string draggingAddress: ""
    property string settlingAddress: ""
    property string hoveredAddress: ""
    property string pressedAddress: ""
    property var windowToplevels: []
    property var windowMoveHints: ({})
    property string _windowToplevelsSignature: ""
    readonly property var toplevelValues: ToplevelManager.toplevels && ToplevelManager.toplevels.values
        ? ToplevelManager.toplevels.values
        : []

    signal closeRequested()

    visible: opacity > 0
    opacity: showCondition ? 1 : 0
    width: implicitWidth
    height: implicitHeight
    implicitWidth: overviewCard.implicitWidth
    implicitHeight: overviewCard.implicitHeight

    function findMonitorData(monitorId) {
        const monitors = hyprlandData && hyprlandData.monitors ? hyprlandData.monitors : [];
        for (let index = 0; index < monitors.length; index++) {
            if (monitors[index].id === monitorId)
                return monitors[index];
        }
        return null;
    }

    function getWsRow(workspaceId) {
        const normalRow = Math.floor((workspaceId - 1) / columns) % rows;
        return orderBottomUp ? rows - normalRow - 1 : normalRow;
    }

    function getWsColumn(workspaceId) {
        const normalColumn = (workspaceId - 1) % columns;
        return orderRightLeft ? columns - normalColumn - 1 : normalColumn;
    }

    function getWsInCell(rowIndex, columnIndex) {
        const workspaceRow = orderBottomUp ? rows - rowIndex - 1 : rowIndex;
        const workspaceColumn = orderRightLeft ? columns - columnIndex - 1 : columnIndex;
        return workspaceRow * columns + workspaceColumn + 1;
    }

    function workspaceAtPoint(pointX, pointY) {
        const cellSpanX = workspaceImplicitWidth + workspaceSpacing;
        const cellSpanY = workspaceImplicitHeight + workspaceSpacing;
        const columnIndex = Math.floor(pointX / cellSpanX);
        const rowIndex = Math.floor(pointY / cellSpanY);
        const localX = pointX - columnIndex * cellSpanX;
        const localY = pointY - rowIndex * cellSpanY;

        if (columnIndex < 0 || columnIndex >= columns || rowIndex < 0 || rowIndex >= rows)
            return -1;
        if (localX < 0 || localY < 0 || localX > workspaceImplicitWidth || localY > workspaceImplicitHeight)
            return -1;

        return workspaceGroup * workspacesShown + getWsInCell(rowIndex, columnIndex);
    }

    function workspaceOffset(workspaceId) {
        const safeWorkspaceId = workspaceId > 0 ? workspaceId : 1;
        return {
            "x": (workspaceImplicitWidth + workspaceSpacing) * getWsColumn(safeWorkspaceId),
            "y": (workspaceImplicitHeight + workspaceSpacing) * getWsRow(safeWorkspaceId)
        };
    }

    function clampNumber(value, minimum, maximum) {
        const parsed = Number(value);
        if (!isFinite(parsed))
            return minimum;

        return Math.max(minimum, Math.min(maximum, parsed));
    }

    function transformedMonitorWidth(monitorData) {
        if (!monitorData)
            return monitor ? monitor.width : (screen ? screen.width : 1920);

        return (monitorData.transform & 1) ? monitorData.height : monitorData.width;
    }

    function transformedMonitorHeight(monitorData) {
        if (!monitorData)
            return monitor ? monitor.height : (screen ? screen.height : 1080);

        return (monitorData.transform & 1) ? monitorData.width : monitorData.height;
    }

    function floatingWindowPosition(windowTile, targetWorkspace) {
        const sourceMonitor = windowTile && windowTile.sourceMonitorData
            ? windowTile.sourceMonitorData
            : monitorData;
        const reserved = sourceMonitor && sourceMonitor.reserved
            ? sourceMonitor.reserved
            : [0, 0, 0, 0];
        const monitorX = sourceMonitor && sourceMonitor.x !== undefined ? sourceMonitor.x : 0;
        const monitorY = sourceMonitor && sourceMonitor.y !== undefined ? sourceMonitor.y : 0;
        const usableX = monitorX + reserved[0];
        const usableY = monitorY + reserved[1];
        const usableWidth = Math.max(1, transformedMonitorWidth(sourceMonitor) - reserved[0] - reserved[2]);
        const usableHeight = Math.max(1, transformedMonitorHeight(sourceMonitor) - reserved[1] - reserved[3]);
        const scaleX = Math.max(0.0001, windowTile.scale * windowTile.widthRatio);
        const scaleY = Math.max(0.0001, windowTile.scale * windowTile.heightRatio);
        const targetOffset = targetWorkspace > 0
            ? workspaceOffset(targetWorkspace)
            : {
                "x": windowTile.workspaceOffsetX,
                "y": windowTile.workspaceOffsetY
            };
        const localX = (windowTile.x - targetOffset.x) / scaleX;
        const localY = (windowTile.y - targetOffset.y) / scaleY;
        const windowWidth = windowTile.windowData && windowTile.windowData.size ? windowTile.windowData.size[0] : 0;
        const windowHeight = windowTile.windowData && windowTile.windowData.size ? windowTile.windowData.size[1] : 0;
        const maxX = usableX + Math.max(0, usableWidth - windowWidth);
        const maxY = usableY + Math.max(0, usableHeight - windowHeight);

        return {
            "x": Math.round(clampNumber(usableX + localX, usableX, maxX)),
            "y": Math.round(clampNumber(usableY + localY, usableY, maxY))
        };
    }

    function windowMoveHint(address) {
        const key = String(address || "").toLowerCase();
        return windowMoveHints && windowMoveHints[key] ? windowMoveHints[key] : null;
    }

    function setWindowMoveHint(address, workspaceId, x, y) {
        const key = String(address || "").toLowerCase();
        if (key === "")
            return;

        const nextHints = {};
        for (const existingKey in windowMoveHints)
            nextHints[existingKey] = windowMoveHints[existingKey];

        const hint = {};
        if (workspaceId > 0)
            hint.workspace = workspaceId;
        if (x !== undefined && y !== undefined) {
            hint.x = Math.round(x);
            hint.y = Math.round(y);
        }

        nextHints[key] = hint;
        windowMoveHints = nextHints;
    }

    function clearMatchedWindowMoveHints() {
        const hints = windowMoveHints ? windowMoveHints : {};
        const byAddress = hyprlandData && hyprlandData.windowByAddress
            ? hyprlandData.windowByAddress
            : {};
        const nextHints = {};
        let changed = false;

        for (const key in hints) {
            const hint = hints[key];
            const windowData = byAddress[key] || null;
            if (!windowData) {
                nextHints[key] = hint;
                continue;
            }

            const workspaceMatches = hint.workspace === undefined
                || (windowData.workspace && windowData.workspace.id === hint.workspace);
            const positionMatches = hint.x === undefined
                || (windowData.at
                    && Math.abs(windowData.at[0] - hint.x) <= 1
                    && Math.abs(windowData.at[1] - hint.y) <= 1);

            if (workspaceMatches && positionMatches) {
                changed = true;
                continue;
            }

            nextHints[key] = hint;
        }

        if (changed)
            windowMoveHints = nextHints;
    }

    function normalizeToplevelAddress(toplevel) {
        const rawAddress = toplevel && toplevel.HyprlandToplevel
            ? String(toplevel.HyprlandToplevel.address || "")
            : "";
        return rawAddress.startsWith("0x")
            ? rawAddress.toLowerCase()
            : ("0x" + rawAddress).toLowerCase();
    }

    function clearWindowToplevels() {
        windowModelRefreshTimer.stop();
        draggingFromWorkspace = -1;
        draggingTargetWorkspace = -1;
        draggingAddress = "";
        settlingAddress = "";
        hoveredAddress = "";
        pressedAddress = "";
        windowMoveHints = ({});
        _windowToplevelsSignature = "";
        if (windowToplevels.length > 0)
            windowToplevels = [];
    }

    function scheduleWindowToplevelRefresh() {
        if (!showCondition) {
            clearWindowToplevels();
            return;
        }

        windowModelRefreshTimer.restart();
    }

    function refreshWindowToplevels() {
        if (!showCondition) {
            clearWindowToplevels();
            return;
        }

        const startWorkspace = workspaceGroup * workspacesShown;
        const endWorkspace = (workspaceGroup + 1) * workspacesShown;
        const byAddress = hyprlandData && hyprlandData.windowByAddress
            ? hyprlandData.windowByAddress
            : {};
        const nextToplevels = [];
        let nextSignature = "";

        for (let index = 0; index < toplevelValues.length; index++) {
            const toplevel = toplevelValues[index];
            const address = normalizeToplevelAddress(toplevel);
            const windowData = byAddress[address] || null;
            const workspaceId = windowData && windowData.workspace ? windowData.workspace.id : -1;

            if (workspaceId > startWorkspace && workspaceId <= endWorkspace) {
                nextToplevels.push(toplevel);
                nextSignature += address + "\u001e";
            }
        }

        if (nextSignature === _windowToplevelsSignature)
            return;

        _windowToplevelsSignature = nextSignature;
        windowToplevels = nextToplevels;
    }

    onShowConditionChanged: {
        if (showCondition)
            scheduleWindowToplevelRefresh();
        else
            clearWindowToplevels();
    }
    onWorkspaceGroupChanged: scheduleWindowToplevelRefresh()
    onToplevelValuesChanged: scheduleWindowToplevelRefresh()

    Component.onCompleted: scheduleWindowToplevelRefresh()

    Timer {
        id: windowModelRefreshTimer
        interval: 80
        repeat: false
        onTriggered: root.refreshWindowToplevels()
    }

    Connections {
        target: root.hyprlandData

        function onWindowByAddressChanged() {
            root.clearMatchedWindowMoveHints();
            root.scheduleWindowToplevelRefresh();
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: showCondition ? 180 : 120
            easing.type: Easing.InOutQuad
        }
    }

    Rectangle {
        id: overviewCard

        anchors.centerIn: parent
        width: implicitWidth
        height: implicitHeight
        implicitWidth: workspaceStage.implicitWidth + root.outerPadding * 2
        implicitHeight: workspaceStage.implicitHeight + root.outerPadding * 2
        radius: root.largeWorkspaceRadius + root.outerPadding
        color: root.cardColor
        border.width: 1
        border.color: root.cardBorderColor

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius - 1
            color: StyleTokens.transparent
            border.width: 1
            border.color: StyleTokens.overviewInnerBorder
        }

        Item {
            id: workspaceStage

            anchors.centerIn: parent
            width: implicitWidth
            height: implicitHeight
            implicitWidth: workspaceColumnLayout.implicitWidth
            implicitHeight: workspaceColumnLayout.implicitHeight

            Column {
                id: workspaceColumnLayout

                width: implicitWidth
                height: implicitHeight
                spacing: root.workspaceSpacing

                Repeater {
                    model: root.rows

                    delegate: Row {
                        id: workspaceRow

                        required property int index

                        width: implicitWidth
                        height: implicitHeight
                        spacing: root.workspaceSpacing

                        Repeater {
                            model: root.columns

                            delegate: Rectangle {
                                id: workspaceCell

                                required property int index

                                property int columnIndex: index
                                property int workspaceValue: root.workspaceGroup * root.workspacesShown + root.getWsInCell(workspaceRow.index, columnIndex)
                                property bool hoveredWhileDragging: root.draggingTargetWorkspace === workspaceValue
                                    && root.draggingFromWorkspace !== workspaceValue
                                property bool workspaceAtLeft: columnIndex === 0
                                property bool workspaceAtRight: columnIndex === root.columns - 1
                                property bool workspaceAtTop: workspaceRow.index === 0
                                property bool workspaceAtBottom: workspaceRow.index === root.rows - 1

                                implicitWidth: root.workspaceImplicitWidth
                                implicitHeight: root.workspaceImplicitHeight
                                width: implicitWidth
                                height: implicitHeight
                                clip: true
                                color: hoveredWhileDragging ? root.workspaceHoverColor : root.workspaceColor
                                topLeftRadius: workspaceAtLeft && workspaceAtTop ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                                topRightRadius: workspaceAtRight && workspaceAtTop ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                                bottomLeftRadius: workspaceAtLeft && workspaceAtBottom ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                                bottomRightRadius: workspaceAtRight && workspaceAtBottom ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                                border.width: hoveredWhileDragging ? 2 : 1
                                border.color: hoveredWhileDragging ? root.workspaceBorderHoverColor : StyleTokens.workspaceCellBorder

                                ClippingRectangle {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    color: StyleTokens.transparent
                                    contentUnderBorder: true
                                    antialiasing: true
                                    topLeftRadius: Math.max(workspaceCell.topLeftRadius - 1, 0)
                                    topRightRadius: Math.max(workspaceCell.topRightRadius - 1, 0)
                                    bottomLeftRadius: Math.max(workspaceCell.bottomLeftRadius - 1, 0)
                                    bottomRightRadius: Math.max(workspaceCell.bottomRightRadius - 1, 0)

                                    Image {
                                        anchors.fill: parent
                                        source: root.wallpaperPath
                                        fillMode: Image.PreserveAspectCrop
                                        sourceSize.width: root.cachedWallpaperWidth
                                        sourceSize.height: root.cachedWallpaperHeight
                                        asynchronous: false
                                        cache: true
                                        opacity: 0.92
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        color: hoveredWhileDragging ? StyleTokens.workspaceOverlayHover : StyleTokens.workspaceOverlay
                                    }

                                    Item {
                                        anchors.fill: parent

                                        Repeater {
                                            model: root.windowToplevels

                                            delegate: WorkspaceOverviewWindow {
                                                id: clippedWindowTile

                                                required property var modelData

                                                readonly property string address: {
                                                    const rawAddress = modelData && modelData.HyprlandToplevel
                                                        ? String(modelData.HyprlandToplevel.address || "")
                                                        : "";
                                                    return rawAddress.startsWith("0x")
                                                        ? rawAddress.toLowerCase()
                                                        : ("0x" + rawAddress).toLowerCase();
                                                }
                                                readonly property var visualWindowData: root.hyprlandData && root.hyprlandData.windowByAddress
                                                    ? root.hyprlandData.windowByAddress[address]
                                                    : null
                                                readonly property var moveHint: root.windowMoveHint(address)
                                                readonly property int workspaceId: moveHint && moveHint.workspace !== undefined
                                                    ? moveHint.workspace
                                                    : (visualWindowData && visualWindowData.workspace ? visualWindowData.workspace.id : -1)
                                                readonly property var positionHint: moveHint && moveHint.x !== undefined && moveHint.y !== undefined
                                                    ? moveHint
                                                    : null
                                                property int monitorId: visualWindowData && visualWindowData.monitor !== undefined ? visualWindowData.monitor : -1
                                                property var sourceMonitorData: root.findMonitorData(monitorId)
                                                property real distanceFromLeftEdge: Math.max(initX, 0)
                                                property real distanceFromRightEdge: Math.max(root.workspaceImplicitWidth - (initX + targetWindowWidth), 0)
                                                property real distanceFromTopEdge: Math.max(initY, 0)
                                                property real distanceFromBottomEdge: Math.max(root.workspaceImplicitHeight - (initY + targetWindowHeight), 0)

                                                visible: workspaceId === workspaceCell.workspaceValue
                                                windowData: visualWindowData
                                                toplevel: modelData
                                                previewEnabled: root.previewsEnabled
                                                forcePreviewActive: root.previewsEnabled
                                                    && (address === root.draggingAddress || address === root.settlingAddress)
                                                positionOverride: positionHint
                                                scale: root.scale
                                                monitorData: sourceMonitorData ? sourceMonitorData : root.monitorData
                                                widgetMonitor: root.monitorData
                                                xOffset: 0
                                                yOffset: 0
                                                centerIcons: root.centerIcons
                                                visibilityOpacity: address === root.draggingAddress || address === root.settlingAddress ? 0 : 1
                                                hovered: root.hoveredAddress === address
                                                pressed: root.pressedAddress === address
                                                topLeftRadius: Math.max((workspaceCell.workspaceAtLeft && workspaceCell.workspaceAtTop ? root.largeWorkspaceRadius : root.smallWorkspaceRadius) - Math.max(distanceFromLeftEdge, distanceFromTopEdge), root.windowCornerRadius)
                                                topRightRadius: Math.max((workspaceCell.workspaceAtRight && workspaceCell.workspaceAtTop ? root.largeWorkspaceRadius : root.smallWorkspaceRadius) - Math.max(distanceFromRightEdge, distanceFromTopEdge), root.windowCornerRadius)
                                                bottomLeftRadius: Math.max((workspaceCell.workspaceAtLeft && workspaceCell.workspaceAtBottom ? root.largeWorkspaceRadius : root.smallWorkspaceRadius) - Math.max(distanceFromLeftEdge, distanceFromBottomEdge), root.windowCornerRadius)
                                                bottomRightRadius: Math.max((workspaceCell.workspaceAtRight && workspaceCell.workspaceAtBottom ? root.largeWorkspaceRadius : root.smallWorkspaceRadius) - Math.max(distanceFromRightEdge, distanceFromBottomEdge), root.windowCornerRadius)
                                                z: (visualWindowData && visualWindowData.fullscreen ? 30 : 20) + (visualWindowData && visualWindowData.floating ? 5 : 0)
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: root.workspaceOverviewCellAcceptedButtons

                                    onPressed: (mouse) => {
                                        if (mouse.button !== Qt.LeftButton)
                                            return;
                                        if (root.draggingFromWorkspace !== -1)
                                            return;

                                        root.closeRequested();
                                        hyprDispatch.focusWorkspace(workspaceCell.workspaceValue);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Item {
                id: windowSpace

                anchors.fill: workspaceColumnLayout

                Repeater {
                    model: root.windowToplevels

                    delegate: WorkspaceOverviewWindow {
                        id: windowTile

                        required property var modelData

                        readonly property string address: {
                            const rawAddress = modelData && modelData.HyprlandToplevel
                                ? String(modelData.HyprlandToplevel.address || "")
                                : "";
                            return rawAddress.startsWith("0x")
                                ? rawAddress.toLowerCase()
                                : ("0x" + rawAddress).toLowerCase();
                        }
                        readonly property var moveHint: root.windowMoveHint(address)
                        readonly property int workspaceId: moveHint && moveHint.workspace !== undefined
                            ? moveHint.workspace
                            : (windowData && windowData.workspace ? windowData.workspace.id : -1)
                        readonly property var positionHint: moveHint && moveHint.x !== undefined && moveHint.y !== undefined
                            ? moveHint
                            : null
                        property int monitorId: windowData && windowData.monitor !== undefined ? windowData.monitor : -1
                        property var sourceMonitorData: root.findMonitorData(monitorId)
                        property int workspaceRowIndex: root.getWsRow(workspaceId > 0 ? workspaceId : 1)
                        property int workspaceColumnIndex: root.getWsColumn(workspaceId > 0 ? workspaceId : 1)
                        property real workspaceOffsetX: (root.workspaceImplicitWidth + root.workspaceSpacing) * workspaceColumnIndex
                        property real workspaceOffsetY: (root.workspaceImplicitHeight + root.workspaceSpacing) * workspaceRowIndex
                        property real distanceFromLeftEdge: Math.max(initX - workspaceOffsetX, 0)
                        property real distanceFromRightEdge: Math.max(root.workspaceImplicitWidth - ((initX - workspaceOffsetX) + targetWindowWidth), 0)
                        property real distanceFromTopEdge: Math.max(initY - workspaceOffsetY, 0)
                        property real distanceFromBottomEdge: Math.max(root.workspaceImplicitHeight - ((initY - workspaceOffsetY) + targetWindowHeight), 0)
                        property bool workspaceAtLeft: workspaceColumnIndex === 0
                        property bool workspaceAtRight: workspaceColumnIndex === root.columns - 1
                        property bool workspaceAtTop: workspaceRowIndex === 0
                        property bool workspaceAtBottom: workspaceRowIndex === root.rows - 1
                        property bool settlingAfterDrop: false
                        property int settleTargetWorkspace: -1

                        windowData: root.hyprlandData && root.hyprlandData.windowByAddress
                            ? root.hyprlandData.windowByAddress[address]
                            : null
                        toplevel: modelData
                        previewEnabled: root.previewsEnabled
                        forcePreviewActive: root.previewsEnabled
                            && (dragArea.containsMouse || dragArea.pressed || Drag.active || settlingAfterDrop)
                        positionOverride: positionHint
                        visible: workspaceId > root.workspaceGroup * root.workspacesShown
                            && workspaceId <= (root.workspaceGroup + 1) * root.workspacesShown
                        scale: root.scale
                        monitorData: sourceMonitorData ? sourceMonitorData : root.monitorData
                        widgetMonitor: root.monitorData
                        xOffset: workspaceOffsetX
                        yOffset: workspaceOffsetY
                        centerIcons: root.centerIcons
                        draggingActive: Drag.active
                        visibilityOpacity: Drag.active || settlingAfterDrop ? 1 : 0
                        pressed: dragArea.pressed
                        hovered: dragArea.containsMouse
                        topLeftRadius: Math.max((workspaceAtLeft && workspaceAtTop ? root.largeWorkspaceRadius : root.smallWorkspaceRadius) - Math.max(distanceFromLeftEdge, distanceFromTopEdge), root.windowCornerRadius)
                        topRightRadius: Math.max((workspaceAtRight && workspaceAtTop ? root.largeWorkspaceRadius : root.smallWorkspaceRadius) - Math.max(distanceFromRightEdge, distanceFromTopEdge), root.windowCornerRadius)
                        bottomLeftRadius: Math.max((workspaceAtLeft && workspaceAtBottom ? root.largeWorkspaceRadius : root.smallWorkspaceRadius) - Math.max(distanceFromLeftEdge, distanceFromBottomEdge), root.windowCornerRadius)
                        bottomRightRadius: Math.max((workspaceAtRight && workspaceAtBottom ? root.largeWorkspaceRadius : root.smallWorkspaceRadius) - Math.max(distanceFromRightEdge, distanceFromBottomEdge), root.windowCornerRadius)
                        z: Drag.active ? 99999 : (windowData && windowData.fullscreen ? 30 : 20) + (windowData && windowData.floating ? 5 : 0)

                        Timer {
                            id: restoreTilePosition

                            interval: 80
                            repeat: false

                            onTriggered: {
                                windowTile.x = Math.round(windowTile.initX);
                                windowTile.y = Math.round(windowTile.initY);
                            }
                        }

                        Timer {
                            id: settleFallbackTimer

                            interval: 700
                            repeat: false

                            onTriggered: {
                                if (!windowTile.settlingAfterDrop || settleFinishTimer.running)
                                    return;

                                const offset = root.workspaceOffset(windowTile.settleTargetWorkspace);
                                const maxX = offset.x + Math.max(0, root.workspaceImplicitWidth - windowTile.width);
                                const maxY = offset.y + Math.max(0, root.workspaceImplicitHeight - windowTile.height);
                                windowTile.x = Math.round(root.clampNumber(windowTile.x, offset.x, maxX));
                                windowTile.y = Math.round(root.clampNumber(windowTile.y, offset.y, maxY));
                                settleFinishTimer.restart();
                            }
                        }

                        Timer {
                            id: settleFinishTimer

                            interval: 230
                            repeat: false

                            onTriggered: windowTile.finishSettle()
                        }

                        function beginSettle(targetWorkspace) {
                            restoreTilePosition.stop();
                            settleFallbackTimer.stop();
                            settleFinishTimer.stop();
                            settleTargetWorkspace = targetWorkspace;
                            settlingAfterDrop = true;
                            root.settlingAddress = address;
                            settleFallbackTimer.restart();
                        }

                        function maybeSettleToCurrentInit() {
                            if (!settlingAfterDrop || settleFinishTimer.running)
                                return;
                            if (workspaceId !== settleTargetWorkspace)
                                return;

                            settleFallbackTimer.stop();
                            x = Math.round(initX);
                            y = Math.round(initY);
                            settleFinishTimer.restart();
                        }

                        function finishSettle() {
                            settleFallbackTimer.stop();
                            settleFinishTimer.stop();
                            settlingAfterDrop = false;
                            settleTargetWorkspace = -1;
                            if (root.settlingAddress === address)
                                root.settlingAddress = "";
                            x = Math.round(initX);
                            y = Math.round(initY);
                        }

                        function pointInsideWorkspace(localX, localY) {
                            const pointX = x + localX;
                            const pointY = y + localY;
                            return pointX >= workspaceOffsetX
                                && pointX <= workspaceOffsetX + root.workspaceImplicitWidth
                                && pointY >= workspaceOffsetY
                                && pointY <= workspaceOffsetY + root.workspaceImplicitHeight;
                        }

                        onWorkspaceIdChanged: maybeSettleToCurrentInit()
                        onInitXChanged: maybeSettleToCurrentInit()
                        onInitYChanged: maybeSettleToCurrentInit()

                        Drag.hotSpot.x: width / 2
                        Drag.hotSpot.y: height / 2

                        MouseArea {
                            id: dragArea

                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: root.workspaceOverviewWindowAcceptedButtons
                            drag.target: draggingWindow ? parent : null

                            property bool movedWindow: false
                            property bool draggingWindow: false

                            onPressed: (mouse) => {
                                if (!windowTile.pointInsideWorkspace(mouse.x, mouse.y)) {
                                    mouse.accepted = false;
                                    return;
                                }

                                root.pressedAddress = windowTile.address;
                                if (mouse.button !== userConfig.mouseButton(userConfig.workspaceOverviewWindowDragButton))
                                    return;

                                movedWindow = false;
                                draggingWindow = true;
                                root.draggingAddress = windowTile.address;
                                if (root.settlingAddress === windowTile.address)
                                    root.settlingAddress = "";
                                root.draggingFromWorkspace = windowTile.windowData && windowTile.windowData.workspace
                                    ? windowTile.windowData.workspace.id
                                    : -1;
                                windowTile.Drag.active = true;
                                windowTile.Drag.source = windowTile;
                                windowTile.Drag.hotSpot.x = mouse.x;
                                windowTile.Drag.hotSpot.y = mouse.y;
                            }

                            onPositionChanged: {
                                syncHover();

                                if (!draggingWindow || !(pressedButtons & userConfig.mouseButton(userConfig.workspaceOverviewWindowDragButton)))
                                    return;

                                root.draggingTargetWorkspace = root.workspaceAtPoint(
                                    windowTile.x + windowTile.width / 2,
                                    windowTile.y + windowTile.height / 2
                                );

                                if (!movedWindow) {
                                    movedWindow = Math.abs(windowTile.x - windowTile.initX) > 4
                                        || Math.abs(windowTile.y - windowTile.initY) > 4;
                                }
                            }

                            onReleased: {
                                if (root.pressedAddress === windowTile.address)
                                    root.pressedAddress = "";
                                if (!draggingWindow)
                                    return;

                                draggingWindow = false;
                                const targetWorkspace = root.workspaceAtPoint(
                                    windowTile.x + windowTile.width / 2,
                                    windowTile.y + windowTile.height / 2
                                );
                                const movingToWorkspace = targetWorkspace !== -1
                                    && windowTile.windowData
                                    && windowTile.windowData.workspace
                                    && targetWorkspace !== windowTile.windowData.workspace.id;
                                const movingFloating = !movingToWorkspace
                                    && movedWindow
                                    && windowTile.windowData
                                    && windowTile.windowData.floating;
                                const dropPosition = movingToWorkspace || movingFloating
                                    ? root.floatingWindowPosition(windowTile, movingToWorkspace ? targetWorkspace : windowTile.workspaceId)
                                    : null;

                                if (movingToWorkspace) {
                                    root.setWindowMoveHint(windowTile.address, targetWorkspace, dropPosition.x, dropPosition.y);
                                    windowTile.beginSettle(targetWorkspace);
                                } else if (movingFloating) {
                                    root.setWindowMoveHint(windowTile.address, windowTile.workspaceId, dropPosition.x, dropPosition.y);
                                    windowTile.beginSettle(windowTile.workspaceId);
                                }

                                windowTile.Drag.active = false;
                                root.draggingFromWorkspace = -1;
                                root.draggingTargetWorkspace = -1;
                                if (root.draggingAddress === windowTile.address)
                                    root.draggingAddress = "";

                                if (movingToWorkspace) {
                                    hyprDispatch.moveWindowToWorkspace(windowTile.address, targetWorkspace, false);
                                    if (windowTile.windowData.floating)
                                        hyprDispatch.moveWindowToPosition(windowTile.address, dropPosition.x, dropPosition.y, false);
                                } else if (movingFloating) {
                                    hyprDispatch.moveWindowToPosition(windowTile.address, dropPosition.x, dropPosition.y, false);
                                } else {
                                    restoreTilePosition.restart();
                                }
                            }

                            onCanceled: {
                                draggingWindow = false;
                                windowTile.Drag.active = false;
                                root.draggingFromWorkspace = -1;
                                root.draggingTargetWorkspace = -1;
                                if (root.draggingAddress === windowTile.address)
                                    root.draggingAddress = "";
                                if (root.pressedAddress === windowTile.address)
                                    root.pressedAddress = "";
                                restoreTilePosition.restart();
                            }

                            onClicked: (mouse) => {
                                if (!windowTile.windowData)
                                    return;
                                if (!windowTile.pointInsideWorkspace(mouse.x, mouse.y)) {
                                    mouse.accepted = false;
                                    return;
                                }
                                if (movedWindow) {
                                    movedWindow = false;
                                    return;
                                }

                                if (mouse.button === Qt.LeftButton) {
                                    root.closeRequested();
                                    hyprDispatch.focusWindow(windowTile.address);
                                    mouse.accepted = true;
                                } else if (mouse.button === Qt.RightButton) {
                                    hyprDispatch.closeWindow(windowTile.address);
                                    mouse.accepted = true;
                                }
                            }

                            onContainsMouseChanged: {
                                syncHover();
                            }

                            function syncHover() {
                                if (containsMouse && windowTile.pointInsideWorkspace(mouseX, mouseY))
                                    root.hoveredAddress = windowTile.address;
                                else if (root.hoveredAddress === windowTile.address)
                                    root.hoveredAddress = "";
                            }
                        }
                    }
                }

                Rectangle {
                    id: focusedWorkspaceIndicator

                    property int rowIndex: root.getWsRow(root.effectiveActiveWorkspaceId)
                    property int columnIndex: root.getWsColumn(root.effectiveActiveWorkspaceId)
                    property bool workspaceAtLeft: columnIndex === 0
                    property bool workspaceAtRight: columnIndex === root.columns - 1
                    property bool workspaceAtTop: rowIndex === 0
                    property bool workspaceAtBottom: rowIndex === root.rows - 1

                    x: (root.workspaceImplicitWidth + root.workspaceSpacing) * columnIndex
                    y: (root.workspaceImplicitHeight + root.workspaceSpacing) * rowIndex
                    width: root.workspaceImplicitWidth
                    height: root.workspaceImplicitHeight
                    color: StyleTokens.transparent
                    border.width: 2
                    border.color: root.activeBorderColor
                    topLeftRadius: workspaceAtLeft && workspaceAtTop ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                    topRightRadius: workspaceAtRight && workspaceAtTop ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                    bottomLeftRadius: workspaceAtLeft && workspaceAtBottom ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                    bottomRightRadius: workspaceAtRight && workspaceAtBottom ? root.largeWorkspaceRadius : root.smallWorkspaceRadius

                    Behavior on x {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on y {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }
    }
}
