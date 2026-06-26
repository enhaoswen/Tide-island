import QtQuick
import Quickshell.Io
import Quickshell.Widgets

Item {
    id: root

    signal closeRequested

    property bool showCondition: false
    property string iconFontFamily: ""
    property string textFontFamily: ""

    property int transitionFps: 60
    property int transitionStep: 5

    property bool wallpapersLoaded: false
    property string activeWallpaper: ""

    readonly property var transitionTypes: ["center", "simple", "left", "right", "top", "bottom", "any", "random"]
    property int selectedTransitionIndex: 0

    focus: true
    anchors.fill: parent
    opacity: showCondition ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: showCondition ? 240 : 120
            easing.type: Easing.InOutQuad
        }
    }

    onShowConditionChanged: {
        if (showCondition) {
            if (!wallpapersLoaded)
                scanProcess.running = true;
            else
                syncCurrentIndex();
            focusTimer.restart();
        }
    }

    function syncCurrentIndex() {
        if (root.activeWallpaper === "")
            return;
        for (let i = 0; i < allWallpapers.count; i++) {
            if (allWallpapers.get(i).filePath === root.activeWallpaper) {
                pathView.currentIndex = i;
                return;
            }
        }
    }

    Timer {
        id: focusTimer
        interval: 80
        repeat: false
        onTriggered: root.forceActiveFocus()
    }

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Escape:
            root.closeRequested();
            event.accepted = true;
            break;
        case Qt.Key_Right:
        case Qt.Key_Tab:
            pathView.incrementCurrentIndex();
            event.accepted = true;
            break;
        case Qt.Key_Left:
        case Qt.Key_Backtab:
            pathView.decrementCurrentIndex();
            event.accepted = true;
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (allWallpapers.count > 0)
                root.applyWallpaper(allWallpapers.get(pathView.currentIndex).filePath);
            event.accepted = true;
            break;
        }
    }

    ListModel {
        id: allWallpapers
    }

    function applyWallpaper(filePath) {
        applyProcess.wallpaperPath = filePath;
        applyProcess.transitionType = transitionTypes[selectedTransitionIndex];
        applyProcess.running = true;
        root.activeWallpaper = filePath;
        root.closeRequested();
    }

    Process {
        id: scanProcess
        command: ["python3", "-c", "import os, sys\n" + "exts = {'.jpg','.jpeg','.png','.webp','.gif','.avif','.tiff','.bmp'}\n" + "d = os.path.expanduser('~/Pictures/Wallpapers')\n" + "if not os.path.isdir(d):\n" + "    sys.exit(0)\n" + "files = []\n" + "for f in sorted(os.listdir(d)):\n" + "    if os.path.splitext(f)[1].lower() in exts:\n" + "        files.append(os.path.join(d, f) + '\\t' + f)\n" + "for line in files:\n" + "    print(line)\n"]
        stdout: SplitParser {
            onRead: data => {
                const parts = data.split('\t');
                if (parts.length >= 2)
                    allWallpapers.append({
                        filePath: parts[0].trim(),
                        fileName: parts[1].trim()
                    });
            }
        }
        onExited: {
            root.wallpapersLoaded = true;
            root.syncCurrentIndex();
        }
    }

    Process {
        id: applyProcess
        property string wallpaperPath: ""
        property string transitionType: "center"
        command: ["bash", "-c", "awww img '" + wallpaperPath.replace(/'/g, "'\\''") + "'" + " --transition-type " + transitionType + " --transition-step " + root.transitionStep + " --transition-fps " + root.transitionFps + " 2>/dev/null || true"]
        onExited: running = false
    }

    readonly property real topPad: 14
    readonly property real botPad: 8
    readonly property real hPad: 12
    readonly property real headerH: 30
    readonly property real headerGap: 8
    readonly property real labelH: 22
    readonly property real labelGap: 5

    readonly property real cardW: Math.round(slotW * 1.15)
    readonly property real cardH: Math.round(cardW * 0.58)
    readonly property real spacing: slotW * 1.20

    readonly property real sideScale: 0.78

    readonly property real slotW: (width - hPad * 2) / 5

    readonly property real cardAreaH: height - topPad - headerH - headerGap - botPad

    // ── UI ────────────────────────────────────────────────────────────────────
    Column {
        anchors.fill: parent
        anchors.topMargin: 10
        anchors.leftMargin: root.hPad
        anchors.rightMargin: root.hPad
        anchors.bottomMargin: 6
        spacing: 6

        // ── Header ─────────────────────────────────────────────────────────
        Item {
            width: parent.width
            height: 30

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Wallpapers"
                color: "white"
                font.pixelSize: 14
                font.family: root.textFontFamily
                font.weight: Font.DemiBold
                opacity: 0.88
            }

            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: pillLabel.implicitWidth + 20
                height: 24
                radius: 50
                color: pillMouse.pressed ? Qt.rgba(1, 1, 1, 0.16) : pillMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.06)
                Behavior on color {
                    ColorAnimation {
                        duration: 100
                    }
                }

                Text {
                    id: pillLabel
                    anchors.centerIn: parent
                    text: root.transitionTypes[root.selectedTransitionIndex]
                    color: pillMouse.containsMouse ? "white" : Qt.rgba(1, 1, 1, 0.50)
                    font.pixelSize: 11
                    font.family: root.textFontFamily
                    font.weight: Font.Medium
                    Behavior on color {
                        ColorAnimation {
                            duration: 100
                        }
                    }
                }

                MouseArea {
                    id: pillMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.selectedTransitionIndex = (root.selectedTransitionIndex + 1) % root.transitionTypes.length
                }
            }
        }

        // ── Carousel ───────────────────────────────────────────────────────
        Item {
            width: parent.width
            height: root.cardAreaH

            // Empty state
            Column {
                anchors.centerIn: parent
                spacing: 8
                visible: !root.wallpapersLoaded || allWallpapers.count === 0

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: !root.wallpapersLoaded ? "Scanning…" : "\uf03e"
                    font.pixelSize: !root.wallpapersLoaded ? 12 : 26
                    font.family: !root.wallpapersLoaded ? root.textFontFamily : root.iconFontFamily
                    color: Qt.rgba(1, 1, 1, 0.22)
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.wallpapersLoaded && allWallpapers.count === 0
                    text: "No wallpapers found\nin ~/Pictures/Wallpapers"
                    horizontalAlignment: Text.AlignHCenter
                    color: Qt.rgba(1, 1, 1, 0.22)
                    font.pixelSize: 11
                    font.family: root.textFontFamily
                    lineHeight: 1.5
                }
            }

            PathView {
                id: pathView
                anchors.fill: parent
                model: allWallpapers
                visible: allWallpapers.count > 0
                clip: false

                pathItemCount: Math.min(allWallpapers.count, 5)
                cacheItemCount: 4
                snapMode: PathView.SnapToItem
                preferredHighlightBegin: 0.5
                preferredHighlightEnd: 0.5
                highlightRangeMode: PathView.StrictlyEnforceRange
                highlightMoveDuration: 200

                path: Path {
                    startX: pathView.width / 2 - root.spacing * 2
                    startY: root.cardH / 2
                    PathLine {
                        x: pathView.width / 2 + root.spacing * 2
                        y: root.cardH / 2
                    }
                }

                delegate: Item {
                    id: del
                    readonly property bool isCurrent: PathView.isCurrentItem
                    readonly property bool onPath: PathView.onPath

                    width: root.cardW
                    height: root.cardH + root.labelGap + root.labelH
                    z: isCurrent ? 3 : 1

                    property real sc: isCurrent ? 1.0 : onPath ? root.sideScale : 0.0
                    Behavior on sc {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutCubic
                        }
                    }

                    property real op: isCurrent ? 1.0 : onPath ? 0.65 : 0.0
                    Behavior on op {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.OutCubic
                        }
                    }

                    Item {
                        id: inner
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        width: root.cardW
                        height: root.cardH + root.labelGap + root.labelH
                        scale: del.sc
                        opacity: del.op
                        transformOrigin: Item.Bottom

                        // Clipped image
                        ClippingRectangle {
                            id: thumb
                            anchors.top: parent.top
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: root.cardW
                            height: root.cardH
                            radius: 14
                            color: "#1a1a1a"

                            Image {
                                anchors.fill: parent
                                source: "file://" + model.filePath
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                smooth: true
                                mipmap: true
                                sourceSize: Qt.size(root.cardW * 2, root.cardH * 2)

                                Rectangle {
                                    anchors.fill: parent
                                    color: "#282828"
                                    opacity: parent.status === Image.Ready ? 0 : 1
                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 200
                                        }
                                    }
                                }
                            }
                        }

                        // Border overlay
                        Rectangle {
                            anchors.top: parent.top
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: root.cardW
                            height: root.cardH
                            radius: 14
                            color: "transparent"
                            border.width: (model.filePath === root.activeWallpaper) ? 2.5 : 0
                            border.color: "#60a5fa"
                            Behavior on border.width {
                                NumberAnimation {
                                    duration: 150
                                }
                            }

                            // Active badge
                            Rectangle {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 7
                                width: 20
                                height: 20
                                radius: 10
                                color: "#60a5fa"
                                visible: model.filePath === root.activeWallpaper

                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf00c"
                                    font.family: root.iconFontFamily
                                    font.pixelSize: 10
                                    color: "white"
                                }
                            }
                        }

                        // Click area
                        MouseArea {
                            anchors.top: parent.top
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: root.cardW
                            height: root.cardH
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (del.isCurrent)
                                    root.applyWallpaper(model.filePath);
                                else
                                    pathView.currentIndex = index;
                            }
                        }

                        // Filename label
                        Text {
                            anchors.top: thumb.bottom
                            anchors.topMargin: root.labelGap
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: root.cardW - 4
                            text: model.fileName
                            color: del.isCurrent ? "white" : Qt.rgba(1, 1, 1, 0.50)
                            font.pixelSize: del.isCurrent ? 11 : 10
                            font.family: root.textFontFamily
                            font.weight: del.isCurrent ? Font.Medium : Font.Normal
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideMiddle
                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
