pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

Item {
    id: root

    property var toplevel: null
    property var windowData: null
    property var monitorData: null
    property var widgetMonitor: null
    property real scale: 0.18
    property real xOffset: 0
    property real yOffset: 0
    property bool centerIcons: true
    property bool previewEnabled: true
    property bool hovered: false
    property bool pressed: false
    property bool draggingActive: false
    property bool forcePreviewActive: false
    property var positionOverride: null
    property real visibilityOpacity: 1
    property real topLeftRadius: 18
    property real topRightRadius: 18
    property real bottomLeftRadius: 18
    property real bottomRightRadius: 18

    readonly property real widthRatio: {
        if (!widgetMonitor || !monitorData)
            return 1;

        const widgetWidth = widgetMonitor.transform & 1 ? widgetMonitor.height : widgetMonitor.width;
        const monitorWidth = monitorData.transform & 1 ? monitorData.height : monitorData.width;
        return monitorWidth > 0 ? (widgetWidth * monitorData.scale) / (monitorWidth * widgetMonitor.scale) : 1;
    }
    readonly property real heightRatio: {
        if (!widgetMonitor || !monitorData)
            return 1;

        const widgetHeight = widgetMonitor.transform & 1 ? widgetMonitor.width : widgetMonitor.height;
        const monitorHeight = monitorData.transform & 1 ? monitorData.width : monitorData.height;
        return monitorHeight > 0 ? (widgetHeight * monitorData.scale) / (monitorHeight * widgetMonitor.scale) : 1;
    }
    readonly property real targetWindowWidth: Math.max(52, (windowData && windowData.size ? windowData.size[0] : 240) * scale * widthRatio)
    readonly property real targetWindowHeight: Math.max(38, (windowData && windowData.size ? windowData.size[1] : 140) * scale * heightRatio)
    readonly property real initX: {
        if (!windowData || !monitorData)
            return xOffset;

        const reserved = monitorData.reserved ? monitorData.reserved : [0, 0, 0, 0];
        const position = positionOverride
            ? [positionOverride.x, positionOverride.y]
            : (windowData.at ? windowData.at : [monitorData.x, monitorData.y]);
        return Math.max((position[0] - monitorData.x - reserved[0]) * widthRatio * scale, 0) + xOffset;
    }
    readonly property real initY: {
        if (!windowData || !monitorData)
            return yOffset;

        const reserved = monitorData.reserved ? monitorData.reserved : [0, 0, 0, 0];
        const position = positionOverride
            ? [positionOverride.x, positionOverride.y]
            : (windowData.at ? windowData.at : [monitorData.x, monitorData.y]);
        return Math.max((position[1] - monitorData.y - reserved[1]) * heightRatio * scale, 0) + yOffset;
    }
    readonly property string iconLookupName: {
        if (!windowData)
            return "";

        return windowData.class || windowData.initialClass || windowData.app_id || windowData.initialTitle || windowData.title || "";
    }
    readonly property bool compactMode: Math.min(targetWindowWidth, targetWindowHeight) < 120
    readonly property string iconThemeName: resolveIconThemeName(iconLookupName)
    readonly property string iconPath: compactMode
        ? Quickshell.iconPath(iconThemeName, "image-missing")
        : ""
    readonly property real baseOpacity: !windowData ? 0 : (widgetMonitor && windowData.monitor === widgetMonitor.id ? 1 : 0.46)
    readonly property bool previewActive: previewEnabled && !!toplevel && (forcePreviewActive || (visible && opacity > 0))

    function resolveIconThemeName(rawName) {
        const name = String(rawName === undefined || rawName === null ? "" : rawName).trim();
        if (name === "")
            return "application-x-executable";

        const lowerName = name.toLowerCase();
        switch (lowerName) {
        case "code":
        case "code-url-handler":
            return "application-x-executable";
        case "spotify":
            return "spotify";
        default:
            return lowerName.indexOf("xingchenproj") !== -1
                ? "application-x-executable"
                : name;
        }
    }
    x: initX
    y: initY
    width: targetWindowWidth
    height: targetWindowHeight
    opacity: baseOpacity * visibilityOpacity

    Behavior on x {
        enabled: !root.draggingActive

        NumberAnimation {
            duration: 160
            easing.type: Easing.OutCubic
        }
    }

    Behavior on y {
        enabled: !root.draggingActive

        NumberAnimation {
            duration: 160
            easing.type: Easing.OutCubic
        }
    }

    Behavior on width {
        NumberAnimation {
            duration: 160
            easing.type: Easing.OutCubic
        }
    }

    Behavior on height {
        NumberAnimation {
            duration: 160
            easing.type: Easing.OutCubic
        }
    }

    ClippingRectangle {
        anchors.fill: parent
        color: "transparent"
        contentUnderBorder: true
        antialiasing: true
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius
        border.width: 1
        border.color: root.hovered ? "#77ffffff" : "#33ffffff"

        ScreencopyView {
            anchors.fill: parent
            captureSource: root.previewActive ? root.toplevel : null
            constraintSize: Qt.size(Math.max(1, Math.round(root.width)), Math.max(1, Math.round(root.height)))
            live: root.previewActive
        }

        Rectangle {
            anchors.fill: parent
            color: root.draggingActive
                ? "#14ffffff"
                : (root.pressed
                    ? "#26000000"
                    : (root.hovered ? "#10ffffff" : "transparent"))
        }

        Image {
            id: appIcon

            readonly property real iconSize: Math.max(18, Math.min(root.width, root.height) * (root.compactMode ? 0.52 : 0.32))
            property bool iconLoadFailed: false

            anchors.centerIn: parent
            visible: root.compactMode && source !== ""
            source: root.compactMode && !iconLoadFailed ? root.iconPath : ""
            width: iconSize
            height: iconSize
            sourceSize: Qt.size(width, height)
            mipmap: true
            smooth: true
            opacity: 0.96

            onStatusChanged: {
                if (status === Image.Error)
                    iconLoadFailed = true;
            }

            Connections {
                target: root

                function onIconPathChanged() {
                    appIcon.iconLoadFailed = false;
                }
            }
        }
    }
}
