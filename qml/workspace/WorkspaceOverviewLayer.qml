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

    HyprlandDispatch { id: hyprDispatch }

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
        const id = monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id
            : (hyprlandData && hyprlandData.activeWorkspace ? hyprlandData.activeWorkspace.id : 1)
        return Math.max(1, Math.min(100, id || 1))
    }
    readonly property int workspaceGroup: Math.floor((effectiveActiveWorkspaceId - 1) / workspacesShown)
    readonly property real workspaceSpacing: 6
    readonly property real outerPadding: 14
    readonly property real largeWorkspaceRadius: 30
    readonly property real smallWorkspaceRadius: 16
    readonly property color activeBorderColor: StyleTokens.workspaceActiveBorder
    readonly property color cardColor: StyleTokens.overviewCard
    readonly property color cardBorderColor: StyleTokens.overviewBorder
    readonly property color workspaceColor: StyleTokens.workspaceCell
    readonly property color workspaceHoverColor: "#ff25272c"
    readonly property color workspaceBorderHoverColor: "#3dd9f6ff"
    readonly property real workspaceImplicitWidth: {
        const res = monitorData && monitorData.reserved ? monitorData.reserved : [0,0,0,0]
        const sw = monitor ? monitor.width : (screen ? screen.width : 1920)
        const sh = monitor ? monitor.height : (screen ? screen.height : 1080)
        const t = monitorData && monitorData.transform !== undefined ? monitorData.transform : 0
        const ms = monitor && monitor.scale ? monitor.scale : 1
        return Math.max(180, ((t % 2 === 1 ? sh : sw) - res[0] - res[2]) * scale / ms)
    }
    readonly property real workspaceImplicitHeight: {
        const res = monitorData && monitorData.reserved ? monitorData.reserved : [0,0,0,0]
        const sw = monitor ? monitor.width : (screen ? screen.width : 1920)
        const sh = monitor ? monitor.height : (screen ? screen.height : 1080)
        const t = monitorData && monitorData.transform !== undefined ? monitorData.transform : 0
        const ms = monitor && monitor.scale ? monitor.scale : 1
        return Math.max(120, ((t % 2 === 1 ? sw : sh) - res[1] - res[3]) * scale / ms)
    }

    property int draggingFromWorkspace: -1
    property int draggingTargetWorkspace: -1
    property string draggingAddress: ""
    property string settlingAddress: ""
    property string hoveredAddress: ""
    property string pressedAddress: ""
    property var windowToplevels: []
    property var windowMoveHints: ({})
    property string _toplevelSig: ""
    readonly property var toplevelValues: ToplevelManager.toplevels && ToplevelManager.toplevels.values ? ToplevelManager.toplevels.values : []

    signal closeRequested()

    visible: opacity > 0
    opacity: showCondition ? 1 : 0
    width: implicitWidth
    height: implicitHeight
    implicitWidth: overviewCard.implicitWidth
    implicitHeight: overviewCard.implicitHeight

    // ── helpers ──────────────────────────────────────────────

    function findMonitorData(monId) {
        const mons = hyprlandData && hyprlandData.monitors ? hyprlandData.monitors : []
        for (let i = 0; i < mons.length; i++)
            if (mons[i].id === monId) return mons[i]
        return null
    }
    function getWsRow(wsId) { const nr = Math.floor((wsId-1)/columns)%rows; return orderBottomUp ? rows-nr-1 : nr }
    function getWsColumn(wsId) { const nc = (wsId-1)%columns; return orderRightLeft ? columns-nc-1 : nc }
    function getWsInCell(r,c) { const wr = orderBottomUp?rows-r-1:r; const wc = orderRightLeft?columns-c-1:c; return wr*columns+wc+1 }
    function workspaceAtPoint(px, py) {
        const sx = workspaceImplicitWidth + workspaceSpacing
        const sy = workspaceImplicitHeight + workspaceSpacing
        const ci = Math.floor(px / sx), ri = Math.floor(py / sy)
        const lx = px - ci*sx, ly = py - ri*sy
        if (ci<0||ci>=columns||ri<0||ri>=rows||lx<0||ly<0||lx>workspaceImplicitWidth||ly>workspaceImplicitHeight) return -1
        return workspaceGroup*workspacesShown + getWsInCell(ri,ci)
    }
    function workspaceOffset(wsId) {
        const s = wsId>0?wsId:1
        return { x:(workspaceImplicitWidth+workspaceSpacing)*getWsColumn(s), y:(workspaceImplicitHeight+workspaceSpacing)*getWsRow(s) }
    }
    function clamp(v,lo,hi) { const n=Number(v); return isFinite(n)?Math.max(lo,Math.min(hi,n)):lo }
    function tWidth(md) { if(!md) return monitor?monitor.width:(screen?screen.width:1920); return (md.transform&1)?md.height:md.width }
    function tHeight(md) { if(!md) return monitor?monitor.height:(screen?screen.height:1080); return (md.transform&1)?md.width:md.height }

    function floatingWindowPosition(wt, targetWs) {
        const sm = wt && wt.sourceMonitorData ? wt.sourceMonitorData : monitorData
        const res = sm && sm.reserved ? sm.reserved : [0,0,0,0]
        const mx = sm && sm.x!==undefined ? sm.x : 0
        const my = sm && sm.y!==undefined ? sm.y : 0
        const ux = mx+res[0], uy = my+res[1]
        const uw = Math.max(1, tWidth(sm)-res[0]-res[2]), uh = Math.max(1, tHeight(sm)-res[1]-res[3])
        const sx = Math.max(0.0001, wt.scale*wt.widthRatio), sy = Math.max(0.0001, wt.scale*wt.heightRatio)
        const to = targetWs>0 ? workspaceOffset(targetWs) : { x:wt.workspaceOffsetX, y:wt.workspaceOffsetY }
        const lx = (wt.x-to.x)/sx, ly = (wt.y-to.y)/sy
        const ww = wt.windowData&&wt.windowData.size ? wt.windowData.size[0] : 0
        const wh = wt.windowData&&wt.windowData.size ? wt.windowData.size[1] : 0
        const mxX = ux+Math.max(0,uw-ww), mxY = uy+Math.max(0,uh-wh)
        return { x:Math.round(clamp(ux+lx,ux,mxX)), y:Math.round(clamp(uy+ly,uy,mxY)) }
    }

    // ── window-address-at-point (used by overlay) ────────────

    function windowAddressAtPoint(px, py) {
        const ba = hyprlandData && hyprlandData.windowByAddress ? hyprlandData.windowByAddress : {}
        const wm = monitorData
        for (let i = 0; i < windowToplevels.length; i++) {
            const tlv = windowToplevels[i]
            const addr = normalizeToplevelAddress(tlv)
            const wd = ba[addr] || null
            if (!wd || !wd.workspace || !wm) continue
            const hint = windowMoveHint(addr)
            const wsId = hint && hint.workspace !== undefined ? hint.workspace : wd.workspace.id
            const off = workspaceOffset(wsId > 0 ? wsId : 1)
            const sm = findMonitorData(wd.monitor !== undefined ? wd.monitor : -1)
            const em = sm || wm
            const res = em.reserved ? em.reserved : [0,0,0,0]
            const emx = em.x !== undefined ? em.x : 0
            const emy = em.y !== undefined ? em.y : 0
            const pos = wd.at ? wd.at : [emx, emy]
            const ww = wm.transform&1 ? wm.height : wm.width
            const wh = wm.transform&1 ? wm.width : wm.height
            const mw = em.transform&1 ? em.height : em.width
            const mh = em.transform&1 ? em.width : em.height
            const wr = mw>0 ? (ww*em.scale)/(mw*wm.scale) : 1
            const hr = mh>0 ? (wh*em.scale)/(mh*wm.scale) : 1
            const tx = Math.max((pos[0]-emx-res[0])*wr*scale, 0) + off.x
            const ty = Math.max((pos[1]-emy-res[1])*hr*scale, 0) + off.y
            const tw = Math.max(52, (wd.size?wd.size[0]:240)*scale*wr)
            const th = Math.max(38, (wd.size?wd.size[1]:140)*scale*hr)
            if (px >= tx && px <= tx+tw && py >= ty && py <= ty+th) return addr
        }
        return ""
    }

    // ── move-hint management ─────────────────────────────────

    function windowMoveHint(addr) {
        const k = String(addr||"").toLowerCase()
        return windowMoveHints && windowMoveHints[k] ? windowMoveHints[k] : null
    }
    function setWindowMoveHint(addr, wsId, x, y) {
        const k = String(addr||"").toLowerCase()
        if (k === "") return
        const nh = {}
        for (const ek in windowMoveHints) nh[ek] = windowMoveHints[ek]
        const h = {}
        if (wsId > 0) h.workspace = wsId
        if (x !== undefined && y !== undefined) { h.x = Math.round(x); h.y = Math.round(y) }
        nh[k] = h
        windowMoveHints = nh
    }
    function clearMatchedWindowMoveHints() {
        const hints = windowMoveHints || {}
        const ba = hyprlandData && hyprlandData.windowByAddress ? hyprlandData.windowByAddress : {}
        const nh = {}
        let changed = false
        for (const k in hints) {
            const h = hints[k]
            const wd = ba[k] || null
            if (!wd) { nh[k]=h; continue }
            const wm = h.workspace === undefined || (wd.workspace && wd.workspace.id === h.workspace)
            const pm = h.x === undefined || (wd.at && Math.abs(wd.at[0]-h.x)<=1 && Math.abs(wd.at[1]-h.y)<=1)
            if (wm && pm) { changed = true; continue }
            nh[k] = h
        }
        if (changed) windowMoveHints = nh
    }

    // ── toplevel management ──────────────────────────────────

    function normalizeToplevelAddress(tlv) {
        const ra = tlv && tlv.HyprlandToplevel ? String(tlv.HyprlandToplevel.address||"") : ""
        return ra.startsWith("0x") ? ra.toLowerCase() : ("0x"+ra).toLowerCase()
    }
    function clearToplevels() {
        refreshTimer.stop()
        draggingFromWorkspace = -1; draggingTargetWorkspace = -1; draggingAddress = ""
        settlingAddress = ""; hoveredAddress = ""; pressedAddress = ""
        windowMoveHints = ({}); _toplevelSig = ""
        if (windowToplevels.length > 0) windowToplevels = []
    }
    function scheduleRefresh() {
        if (!showCondition) { clearToplevels(); return }
        refreshTimer.restart()
    }
    function refreshToplevels() {
        if (!showCondition) { clearToplevels(); return }
        const start = workspaceGroup*workspacesShown, end = (workspaceGroup+1)*workspacesShown
        const ba = hyprlandData && hyprlandData.windowByAddress ? hyprlandData.windowByAddress : {}
        const next = []; let sig = ""
        for (let i = 0; i < toplevelValues.length; i++) {
            const tlv = toplevelValues[i]
            const addr = normalizeToplevelAddress(tlv)
            const wd = ba[addr] || null
            const wsId = wd && wd.workspace ? wd.workspace.id : -1
            if (wsId > start && wsId <= end) { next.push(tlv); sig += addr+"\x1e" }
        }
        if (sig === _toplevelSig) return
        _toplevelSig = sig
        windowToplevels = next
    }

    onShowConditionChanged: showCondition ? scheduleRefresh() : clearToplevels()
    onWorkspaceGroupChanged: scheduleRefresh()
    onToplevelValuesChanged: scheduleRefresh()
    Component.onCompleted: scheduleRefresh()

    Timer { id: refreshTimer; interval: 80; repeat: false; onTriggered: root.refreshToplevels() }

    Connections {
        target: root.hyprlandData
        function onWindowByAddressChanged() { root.clearMatchedWindowMoveHints(); root.scheduleRefresh() }
    }

    // ── visual ───────────────────────────────────────────────

    Behavior on opacity { NumberAnimation { duration: showCondition?180:120; easing.type: Easing.InOutQuad } }

    Rectangle {
        id: overviewCard
        anchors.centerIn: parent
        width: implicitWidth; height: implicitHeight
        implicitWidth: workspaceStage.implicitWidth + root.outerPadding*2
        implicitHeight: workspaceStage.implicitHeight + root.outerPadding*2
        radius: root.largeWorkspaceRadius + root.outerPadding
        color: root.cardColor
        border.width: 1; border.color: root.cardBorderColor

        Rectangle {
            anchors.fill: parent; anchors.margins: 1
            radius: parent.radius-1; color: StyleTokens.transparent
            border.width: 1; border.color: StyleTokens.overviewInnerBorder
        }

        Item {
            id: workspaceStage
            anchors.centerIn: parent
            width: implicitWidth; height: implicitHeight
            implicitWidth: workspaceColumnLayout.implicitWidth
            implicitHeight: workspaceColumnLayout.implicitHeight

            // ── workspace cells (rendering only, no interaction) ──

            Column {
                id: workspaceColumnLayout
                spacing: root.workspaceSpacing

                Repeater {
                    model: root.rows
                    delegate: Row {
                        id: wsRow
                        required property int index
                        spacing: root.workspaceSpacing
                        Repeater {
                            model: root.columns
                            delegate: Rectangle {
                                id: wsCell
                                required property int index
                                property int col: index
                                property int wsValue: root.workspaceGroup*root.workspacesShown + root.getWsInCell(wsRow.index, col)
                                property bool hoveredDrag: root.draggingTargetWorkspace === wsValue && root.draggingFromWorkspace !== wsValue
                                property bool atLeft: col === 0
                                property bool atRight: col === root.columns-1
                                property bool atTop: wsRow.index === 0
                                property bool atBottom: wsRow.index === root.rows-1

                                implicitWidth: root.workspaceImplicitWidth
                                implicitHeight: root.workspaceImplicitHeight
                                color: hoveredDrag ? root.workspaceHoverColor : root.workspaceColor
                                topLeftRadius: atLeft&&atTop ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                                topRightRadius: atRight&&atTop ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                                bottomLeftRadius: atLeft&&atBottom ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                                bottomRightRadius: atRight&&atBottom ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                                border.width: 1
                                border.color: hoveredDrag ? root.workspaceBorderHoverColor : StyleTokens.workspaceCellBorder
                                clip: true

                                ClippingRectangle {
                                    anchors.fill: parent; anchors.margins: 1
                                    color: StyleTokens.transparent; antialiasing: true
                                    contentUnderBorder: true
                                    topLeftRadius: Math.max(wsCell.topLeftRadius-1,0)
                                    topRightRadius: Math.max(wsCell.topRightRadius-1,0)
                                    bottomLeftRadius: Math.max(wsCell.bottomLeftRadius-1,0)
                                    bottomRightRadius: Math.max(wsCell.bottomRightRadius-1,0)

                                    Image {
                                        anchors.fill: parent
                                        source: root.wallpaperPath
                                        fillMode: Image.PreserveAspectCrop
                                        sourceSize.width: root.cachedWallpaperWidth
                                        sourceSize.height: root.cachedWallpaperHeight
                                        asynchronous: false; cache: true; opacity: 0.92
                                    }
                                    Rectangle {
                                        anchors.fill: parent
                                        color: hoveredDrag ? "#360d131a" : StyleTokens.workspaceOverlay
                                    }

                                    Item {
                                        anchors.fill: parent
                                        Repeater {
                                            model: root.windowToplevels
                                            delegate: WorkspaceOverviewWindow {
                                                id: clippedTile
                                                required property var modelData
                                                readonly property string addr: {
                                                    const ra = modelData&&modelData.HyprlandToplevel ? String(modelData.HyprlandToplevel.address||"") : ""
                                                    return ra.startsWith("0x") ? ra.toLowerCase() : ("0x"+ra).toLowerCase()
                                                }
                                                readonly property var vwd: root.hyprlandData&&root.hyprlandData.windowByAddress ? root.hyprlandData.windowByAddress[addr] : null
                                                readonly property var mh: root.windowMoveHint(addr)
                                                readonly property int wsId: mh&&mh.workspace!==undefined ? mh.workspace : (vwd&&vwd.workspace ? vwd.workspace.id : -1)
                                                readonly property var ph: mh&&mh.x!==undefined&&mh.y!==undefined ? mh : null
                                                property int monId: vwd&&vwd.monitor!==undefined ? vwd.monitor : -1
                                                property var srcMon: root.findMonitorData(monId)
                                                property real distL: Math.max(initX,0)
                                                property real distR: Math.max(root.workspaceImplicitWidth-(initX+targetWindowWidth),0)
                                                property real distT: Math.max(initY,0)
                                                property real distB: Math.max(root.workspaceImplicitHeight-(initY+targetWindowHeight),0)
                                                visible: wsId === wsCell.wsValue
                                                windowData: vwd; toplevel: modelData
                                                previewEnabled: root.previewsEnabled
                                                forcePreviewActive: root.previewsEnabled && (addr===root.draggingAddress||addr===root.settlingAddress)
                                                positionOverride: ph; scale: root.scale
                                                monitorData: srcMon||root.monitorData; widgetMonitor: root.monitorData
                                                xOffset: 0; yOffset: 0; centerIcons: root.centerIcons
                                                visibilityOpacity: addr===root.draggingAddress||addr===root.settlingAddress ? 0 : 1
                                                hovered: root.hoveredAddress===addr
                                                pressed: root.pressedAddress===addr
                                                topLeftRadius: Math.max((wsCell.atLeft&&wsCell.atTop?root.largeWorkspaceRadius:root.smallWorkspaceRadius)-Math.max(distL,distT), root.windowCornerRadius)
                                                topRightRadius: Math.max((wsCell.atRight&&wsCell.atTop?root.largeWorkspaceRadius:root.smallWorkspaceRadius)-Math.max(distR,distT), root.windowCornerRadius)
                                                bottomLeftRadius: Math.max((wsCell.atLeft&&wsCell.atBottom?root.largeWorkspaceRadius:root.smallWorkspaceRadius)-Math.max(distL,distB), root.windowCornerRadius)
                                                bottomRightRadius: Math.max((wsCell.atRight&&wsCell.atBottom?root.largeWorkspaceRadius:root.smallWorkspaceRadius)-Math.max(distR,distB), root.windowCornerRadius)
                                                z: (vwd&&vwd.fullscreen?30:20)+(vwd&&vwd.floating?5:0)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── windowSpace: draggable tiles + overlay ────────

            Item {
                id: windowSpace
                anchors.fill: workspaceColumnLayout

                // ── overlay: single entry-point for all clicks ──

                MouseArea {
                    id: overlay
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    hoverEnabled: true

                    onPressed: (mouse) => {
                        const dragBtn = userConfig.mouseButton(userConfig.workspaceOverviewWindowDragButton)
                        const addr = root.windowAddressAtPoint(mouse.x, mouse.y)
                        if (mouse.button === dragBtn && addr !== "") {
                            mouse.accepted = false
                            return
                        }
                        if (root.draggingFromWorkspace !== -1) return

                        if (mouse.button === Qt.LeftButton && addr !== "") {
                            root.closeRequested()
                            hyprDispatch.focusWindow(addr)
                        } else if (mouse.button === Qt.RightButton && addr !== "") {
                            hyprDispatch.closeWindow(addr)
                        } else if (mouse.button === Qt.LeftButton) {
                            const ws = root.workspaceAtPoint(mouse.x, mouse.y)
                            if (ws !== -1) { root.closeRequested(); hyprDispatch.focusWorkspace(ws) }
                        }
                    }
                    onPositionChanged: {
                        root.hoveredAddress = containsMouse ? root.windowAddressAtPoint(mouseX, mouseY) : ""
                    }
                    onContainsMouseChanged: { if (!containsMouse) root.hoveredAddress = "" }
                }

                // ── draggable window tiles (drag only) ─────────

                Repeater {
                    model: root.windowToplevels
                    delegate: WorkspaceOverviewWindow {
                        id: dragTile
                        required property var modelData
                        readonly property string addr: {
                            const ra = modelData&&modelData.HyprlandToplevel ? String(modelData.HyprlandToplevel.address||"") : ""
                            return ra.startsWith("0x") ? ra.toLowerCase() : ("0x"+ra).toLowerCase()
                        }
                        readonly property var mh: root.windowMoveHint(addr)
                        readonly property int wsId: mh&&mh.workspace!==undefined ? mh.workspace : (windowData&&windowData.workspace ? windowData.workspace.id : -1)
                        readonly property var ph: mh&&mh.x!==undefined&&mh.y!==undefined ? mh : null
                        property int monId: windowData&&windowData.monitor!==undefined ? windowData.monitor : -1
                        property var srcMon: root.findMonitorData(monId)
                        property int wsRow: root.getWsRow(wsId>0?wsId:1)
                        property int wsCol: root.getWsColumn(wsId>0?wsId:1)
                        property real offX: (root.workspaceImplicitWidth+root.workspaceSpacing)*wsCol
                        property real offY: (root.workspaceImplicitHeight+root.workspaceSpacing)*wsRow
                        property real distL: Math.max(initX-offX,0)
                        property real distR: Math.max(root.workspaceImplicitWidth-((initX-offX)+targetWindowWidth),0)
                        property real distT: Math.max(initY-offY,0)
                        property real distB: Math.max(root.workspaceImplicitHeight-((initY-offY)+targetWindowHeight),0)
                        property bool atL: wsCol===0; property bool atR: wsCol===root.columns-1
                        property bool atT: wsRow===0; property bool atB: wsRow===root.rows-1
                        property bool settling: false
                        property int settleTarget: -1
                        property real lastMouseX: 0
                        property real lastMouseY: 0

                        windowData: root.hyprlandData&&root.hyprlandData.windowByAddress ? root.hyprlandData.windowByAddress[addr] : null
                        toplevel: modelData
                        previewEnabled: root.previewsEnabled
                        forcePreviewActive: root.previewsEnabled && (drag.containsMouse||drag.pressed||Drag.active||settling)
                        positionOverride: ph
                        visible: wsId>root.workspaceGroup*root.workspacesShown && wsId<=(root.workspaceGroup+1)*root.workspacesShown
                        scale: root.scale
                        monitorData: srcMon||root.monitorData; widgetMonitor: root.monitorData
                        xOffset: offX; yOffset: offY; centerIcons: root.centerIcons
                        draggingActive: Drag.active
                        visibilityOpacity: Drag.active||settling ? 1 : 0
                        pressed: drag.pressed; hovered: drag.containsMouse
                        topLeftRadius: Math.max((atL&&atT?root.largeWorkspaceRadius:root.smallWorkspaceRadius)-Math.max(distL,distT), root.windowCornerRadius)
                        topRightRadius: Math.max((atR&&atT?root.largeWorkspaceRadius:root.smallWorkspaceRadius)-Math.max(distR,distT), root.windowCornerRadius)
                        bottomLeftRadius: Math.max((atL&&atB?root.largeWorkspaceRadius:root.smallWorkspaceRadius)-Math.max(distL,distB), root.windowCornerRadius)
                        bottomRightRadius: Math.max((atR&&atB?root.largeWorkspaceRadius:root.smallWorkspaceRadius)-Math.max(distR,distB), root.windowCornerRadius)
                        z: Drag.active?99999:(windowData&&windowData.fullscreen?30:20)+(windowData&&windowData.floating?5:0)

                        // ── settle helpers ──

                        Timer { id: restoreTimer; interval:80; repeat:false; onTriggered:{ dragTile.x=Math.round(dragTile.initX); dragTile.y=Math.round(dragTile.initY) } }
                        Timer { id: settleTimer; interval:700; repeat:false
                            onTriggered: {
                                if (!dragTile.settling||finishTimer.running) return
                                const o = root.workspaceOffset(dragTile.settleTarget)
                                const mx = o.x+Math.max(0,root.workspaceImplicitWidth-dragTile.width)
                                const my = o.y+Math.max(0,root.workspaceImplicitHeight-dragTile.height)
                                dragTile.x = Math.round(root.clamp(dragTile.x,o.x,mx))
                                dragTile.y = Math.round(root.clamp(dragTile.y,o.y,my))
                                finishTimer.restart()
                            }
                        }
                        Timer { id: finishTimer; interval:230; repeat:false; onTriggered: finishSettle() }

                        function beginSettle(ws) { restoreTimer.stop(); settleTimer.stop(); finishTimer.stop(); settleTarget=ws; settling=true; root.settlingAddress=addr; settleTimer.restart() }
                        function maybeSettle() {
                            if (!settling||finishTimer.running||wsId!==settleTarget) return
                            settleTimer.stop(); x=Math.round(initX); y=Math.round(initY); finishTimer.restart()
                        }
                        function finishSettle() { settleTimer.stop(); finishTimer.stop(); settling=false; settleTarget=-1; if(root.settlingAddress===addr) root.settlingAddress=""; x=Math.round(initX); y=Math.round(initY) }
                        function inWorkspace(lx,ly) {
                            const px=x+lx, py=y+ly
                            return px>=offX&&px<=offX+root.workspaceImplicitWidth&&py>=offY&&py<=offY+root.workspaceImplicitHeight
                        }
                        onWsIdChanged: maybeSettle(); onInitXChanged: maybeSettle(); onInitYChanged: maybeSettle()

                        Drag.hotSpot.x: width/2
                        Drag.hotSpot.y: height/2

                        MouseArea {
                            id: drag
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: userConfig.mouseButtonsMask([userConfig.workspaceOverviewWindowDragButton])
                            drag.target: draggingWindow ? parent : null
                            property bool moved: false
                            property bool draggingWindow: false

                            onPressed: (mouse) => {
                                if (!dragTile.inWorkspace(mouse.x,mouse.y)) return
                                root.pressedAddress = dragTile.addr
                                if (mouse.button !== userConfig.mouseButton(userConfig.workspaceOverviewWindowDragButton)) return
                                moved = false; draggingWindow = true
                                dragTile.lastMouseX = dragTile.x + mouse.x
                                dragTile.lastMouseY = dragTile.y + mouse.y
                                root.draggingAddress = dragTile.addr
                                if (root.settlingAddress===dragTile.addr) root.settlingAddress=""
                                root.draggingFromWorkspace = dragTile.windowData&&dragTile.windowData.workspace ? dragTile.windowData.workspace.id : -1
                                dragTile.Drag.active = true; dragTile.Drag.source = dragTile
                                dragTile.Drag.hotSpot.x = mouse.x; dragTile.Drag.hotSpot.y = mouse.y
                            }
                            onPositionChanged: {
                                if (!draggingWindow) return
                                dragTile.lastMouseX = dragTile.x + mouseX
                                dragTile.lastMouseY = dragTile.y + mouseY
                                if (dragTile.windowData && !dragTile.windowData.floating)
                                    root.draggingTargetWorkspace = root.workspaceAtPoint(dragTile.lastMouseX, dragTile.lastMouseY)
                                else
                                    root.draggingTargetWorkspace = root.workspaceAtPoint(dragTile.x+dragTile.width/2, dragTile.y+dragTile.height/2)
                                if (!moved) moved = Math.abs(dragTile.x-dragTile.initX)>4||Math.abs(dragTile.y-dragTile.initY)>4
                            }
                            onReleased: {
                                if (root.pressedAddress===dragTile.addr) root.pressedAddress=""
                                if (!draggingWindow) return
                                draggingWindow = false
                                const isFloating = dragTile.windowData && dragTile.windowData.floating
                                let targetWs
                                if (isFloating) targetWs = root.workspaceAtPoint(dragTile.x+dragTile.width/2, dragTile.y+dragTile.height/2)
                                else { targetWs = root.workspaceAtPoint(dragTile.lastMouseX, dragTile.lastMouseY); if (targetWs===-1) targetWs = root.workspaceAtPoint(dragTile.x+dragTile.width/2, dragTile.y+dragTile.height/2) }
                                const moveWs = targetWs!==-1 && dragTile.windowData && dragTile.windowData.workspace && targetWs!==dragTile.windowData.workspace.id
                                const moveFl = !moveWs && moved && isFloating

                                dragTile.Drag.active = false

                                if (moveWs) {
                                    if (isFloating) { const dp = root.floatingWindowPosition(dragTile, targetWs); root.setWindowMoveHint(dragTile.addr, targetWs, dp.x, dp.y) }
                                    else root.setWindowMoveHint(dragTile.addr, targetWs)
                                    dragTile.beginSettle(targetWs)
                                } else if (moveFl) {
                                    const dp = root.floatingWindowPosition(dragTile, dragTile.wsId)
                                    root.setWindowMoveHint(dragTile.addr, dragTile.wsId, dp.x, dp.y)
                                    dragTile.beginSettle(dragTile.wsId)
                                }

                                if (moveWs && !isFloating) {
                                    const to = root.workspaceOffset(targetWs)
                                    const vx = root.clamp(dragTile.x, to.x, to.x+Math.max(0,root.workspaceImplicitWidth-dragTile.width))
                                    const vy = root.clamp(dragTile.y, to.y, to.y+Math.max(0,root.workspaceImplicitHeight-dragTile.height))
                                    dragTile.x = vx; dragTile.y = vy
                                }

                                root.draggingFromWorkspace = -1; root.draggingTargetWorkspace = -1
                                if (root.draggingAddress===dragTile.addr) root.draggingAddress=""
                                if (moveWs) {
                                    hyprDispatch.moveWindowToWorkspace(dragTile.addr, targetWs, false)
                                    if (isFloating) { const dp = root.floatingWindowPosition(dragTile, targetWs); hyprDispatch.moveWindowToPosition(dragTile.addr, dp.x, dp.y, false) }
                                } else if (moveFl) {
                                    const dp = root.floatingWindowPosition(dragTile, dragTile.wsId)
                                    hyprDispatch.moveWindowToPosition(dragTile.addr, dp.x, dp.y, false)
                                } else if (!moved) {
                                    root.closeRequested()
                                    hyprDispatch.focusWindow(dragTile.addr)
                                    restoreTimer.restart()
                                } else restoreTimer.restart()
                            }
                            onCanceled: {
                                draggingWindow = false; dragTile.Drag.active = false
                                root.draggingFromWorkspace = -1; root.draggingTargetWorkspace = -1
                                if (root.draggingAddress===dragTile.addr) root.draggingAddress=""
                                if (root.pressedAddress===dragTile.addr) root.pressedAddress=""
                                restoreTimer.restart()
                            }
                        }
                    }
                }

                // ── focused workspace indicator ─────────────────

                Rectangle {
                    id: focusInd
                    property int ri: root.getWsRow(root.effectiveActiveWorkspaceId)
                    property int ci: root.getWsColumn(root.effectiveActiveWorkspaceId)
                    x: (root.workspaceImplicitWidth+root.workspaceSpacing)*ci
                    y: (root.workspaceImplicitHeight+root.workspaceSpacing)*ri
                    width: root.workspaceImplicitWidth; height: root.workspaceImplicitHeight
                    color: StyleTokens.transparent
                    border.width: 2; border.color: root.activeBorderColor
                    topLeftRadius: ci===0&&ri===0?root.largeWorkspaceRadius:root.smallWorkspaceRadius
                    topRightRadius: ci===root.columns-1&&ri===0?root.largeWorkspaceRadius:root.smallWorkspaceRadius
                    bottomLeftRadius: ci===0&&ri===root.rows-1?root.largeWorkspaceRadius:root.smallWorkspaceRadius
                    bottomRightRadius: ci===root.columns-1&&ri===root.rows-1?root.largeWorkspaceRadius:root.smallWorkspaceRadius
                    Behavior on x { NumberAnimation { duration:180; easing.type:Easing.OutCubic } }
                    Behavior on y { NumberAnimation { duration:180; easing.type:Easing.OutCubic } }
                }
            }
        }
    }
}
