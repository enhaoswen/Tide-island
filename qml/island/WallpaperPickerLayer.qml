import QtCore
import QtQuick
import Quickshell.Io
import Quickshell.Widgets
import IslandBackend

Item {
    id: root

    signal closeRequested
    signal wallpaperApplied(string filePath)

    property bool showCondition: false
    property string iconFontFamily: ""
    property string textFontFamily: ""
    readonly property var userConfig: UserConfig

    property int transitionFps: 60
    property int transitionStep: 5
    property string wallpaperDir: userConfig.wallpaperLibraryPath
    property string targetWallpaperPath: userConfig.wallpaperPath
    property int thumbnailWidth: 640
    property int thumbnailHeight: 360
    property int thumbnailQuality: 80

    property bool wallpapersLoaded: false
    property string activeWallpaper: ""
    property string latestAppliedWallpaper: ""
    property bool acceptingScanResults: false
    property bool closeAfterApply: false
    property bool releasingResources: false
    property var wallpaperIndexByPath: ({})
    property var pendingThumbnails: []
    property var pendingThumbnailKeys: ({})
    property bool thumbnailInFlight: false
    property string inFlightThumbnailSourcePath: ""
    property string inFlightThumbnailCachePath: ""

    readonly property string effectiveActiveWallpaper: latestAppliedWallpaper !== "" ? latestAppliedWallpaper : activeWallpaper
    readonly property string cacheRoot: localPath(StandardPaths.writableLocation(StandardPaths.GenericCacheLocation))
        + "/quickshell/dynamic_island/wallpaper-picker"
    readonly property string scanScript: "import hashlib,json,os,sys\n"
        + "cache_dir=sys.argv[1]\n"
        + "wallpaper_dir=os.path.expanduser(sys.argv[2])\n"
        + "tw,th,quality=sys.argv[3],sys.argv[4],sys.argv[5]\n"
        + "exts={'.jpg','.jpeg','.png','.webp','.gif','.avif','.tiff','.bmp'}\n"
        + "index_path=os.path.join(cache_dir,'wallpapers.json')\n"
        + "os.makedirs(cache_dir,exist_ok=True)\n"
        + "def thumb_path(path,st):\n"
        + "    key='{}|{}|{}|{}x{}|q{}'.format(path,st.st_mtime_ns,st.st_size,tw,th,quality)\n"
        + "    return os.path.join(cache_dir,'wallpaper-'+hashlib.sha1(key.encode('utf-8','surrogateescape')).hexdigest()[:24]+'.jpg')\n"
        + "def record(path):\n"
        + "    st=os.stat(path)\n"
        + "    cache_path=thumb_path(path,st)\n"
        + "    return {'filePath':path,'fileName':os.path.basename(path),'cachePath':cache_path,'cacheAvailable':os.path.isfile(cache_path),'mtime':st.st_mtime_ns,'size':st.st_size}\n"
        + "def emit(phase,records):\n"
        + "    for rec in records:\n"
        + "        rec=dict(rec)\n"
        + "        rec['phase']=phase\n"
        + "        print(json.dumps(rec,separators=(',',':')),flush=True)\n"
        + "def valid_path(path):\n"
        + "    return os.path.splitext(path)[1].lower() in exts and os.path.isfile(path)\n"
        + "cached=[]\n"
        + "try:\n"
        + "    with open(index_path,'r',encoding='utf-8') as f:\n"
        + "        for item in json.load(f):\n"
        + "            path=item.get('filePath','')\n"
        + "            if valid_path(path):\n"
        + "                cached.append(record(path))\n"
        + "except Exception:\n"
        + "    pass\n"
        + "emit('index',cached)\n"
        + "fresh=[]\n"
        + "if os.path.isdir(wallpaper_dir):\n"
        + "    for entry in sorted(os.scandir(wallpaper_dir),key=lambda e:e.name.lower()):\n"
        + "        if entry.is_file() and os.path.splitext(entry.name)[1].lower() in exts:\n"
        + "            try:\n"
        + "                fresh.append(record(entry.path))\n"
        + "            except OSError:\n"
        + "                pass\n"
        + "emit('scan',fresh)\n"
        + "try:\n"
        + "    tmp=index_path+'.tmp'\n"
        + "    with open(tmp,'w',encoding='utf-8') as f:\n"
        + "        json.dump(fresh,f,separators=(',',':'))\n"
        + "    os.replace(tmp,index_path)\n"
        + "except Exception:\n"
        + "    pass\n"
    readonly property string applyScript: "import os,shutil,subprocess,sys\n"
        + "source,target,transition,step,fps=sys.argv[1:6]\n"
        + "if not source or not target:\n"
        + "    sys.exit(2)\n"
        + "os.makedirs(os.path.dirname(target) or '.',exist_ok=True)\n"
        + "shutil.copy2(source,target)\n"
        + "subprocess.run(['awww','img',target,'--transition-type',transition,'--transition-step',step,'--transition-fps',fps],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)\n"

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
                startScan();
            else
                syncCurrentIndex();
            root.forceActiveFocus();
            focusTimer.restart();
        } else {
            releaseResources();
        }
    }

    Component.onDestruction: releaseResources()

    function startScan() {
        releasingResources = false;
        acceptingScanResults = true;
        wallpapersLoaded = false;
        wallpaperIndexByPath = ({});
        pendingThumbnails = [];
        pendingThumbnailKeys = ({});
        thumbnailInFlight = false;
        inFlightThumbnailSourcePath = "";
        inFlightThumbnailCachePath = "";
        allWallpapers.clear();
        if (scanProcess.running)
            scanProcess.running = false;
        scanProcess.running = true;
    }

    function releaseResources() {
        if (releasingResources)
            return;
        releasingResources = true;
        acceptingScanResults = false;
        closeAfterApply = false;
        focusTimer.stop();
        if (scanProcess.running)
            scanProcess.running = false;
        if (applyProcess.running)
            applyProcess.running = false;
        pendingThumbnails = [];
        pendingThumbnailKeys = ({});
        thumbnailInFlight = false;
        inFlightThumbnailSourcePath = "";
        inFlightThumbnailCachePath = "";
        wallpapersLoaded = false;
        wallpaperIndexByPath = ({});
        allWallpapers.clear();
        releasingResources = false;
    }

    function localPath(value) {
        if (value === undefined || value === null)
            return "";
        if (value.toLocalFile)
            return value.toLocalFile();

        const text = String(value);
        return text.startsWith("file://") ? text.substring(7) : text;
    }

    function toFileUrl(localFile) {
        return localFile === "" ? "" : ("file://" + encodeURI(localFile));
    }

    function thumbnailUrl(cachePath, revision) {
        return cachePath === "" ? "" : (toFileUrl(cachePath) + "?v=" + revision);
    }

    function displayPath(path) {
        return path === "" ? "wallpaperLibraryPath" : path;
    }

    function enqueueThumbnail(sourcePath, cachePath) {
        if (!root.showCondition || sourcePath === "" || cachePath === "")
            return;
        if (cachePath === inFlightThumbnailCachePath)
            return;
        if (pendingThumbnailKeys[cachePath])
            return;
        pendingThumbnailKeys[cachePath] = true;
        pendingThumbnails.push({
            sourcePath: sourcePath,
            cachePath: cachePath
        });
        startNextThumbnail();
    }

    function startNextThumbnail() {
        if (!root.showCondition || thumbnailInFlight || pendingThumbnails.length === 0)
            return;

        const next = pendingThumbnails.shift();
        inFlightThumbnailSourcePath = next.sourcePath;
        inFlightThumbnailCachePath = next.cachePath;
        delete pendingThumbnailKeys[next.cachePath];
        thumbnailInFlight = true;
        SystemServices.generateWallpaperThumbnail(
            next.sourcePath,
            next.cachePath,
            root.cacheRoot,
            root.thumbnailWidth,
            root.thumbnailHeight,
            root.thumbnailQuality
        );
    }

    function upsertWallpaper(record) {
        if (!record || !record.filePath)
            return;

        const filePath = String(record.filePath);
        const cachePath = String(record.cachePath || "");
        const cacheRevision = Number(record.mtime || 0);
        const cacheAvailable = !!record.cacheAvailable;
        const existingIndex = wallpaperIndexByPath[filePath];
        const modelItem = {
            filePath: filePath,
            fileName: String(record.fileName || filePath),
            cachePath: cachePath,
            thumbnailSource: cacheAvailable ? thumbnailUrl(cachePath, cacheRevision) : "",
            thumbnailReady: cacheAvailable,
            thumbnailRequested: cacheAvailable,
            cacheRevision: cacheRevision
        };

        if (existingIndex === undefined) {
            wallpaperIndexByPath[filePath] = allWallpapers.count;
            allWallpapers.append(modelItem);
        } else {
            allWallpapers.set(existingIndex, modelItem);
        }

        if (!cacheAvailable)
            enqueueThumbnail(filePath, cachePath);
    }

    function syncCurrentIndex() {
        if (root.effectiveActiveWallpaper === "")
            return;
        for (let i = 0; i < allWallpapers.count; i++) {
            if (allWallpapers.get(i).filePath === root.effectiveActiveWallpaper) {
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
        const targetPath = root.targetWallpaperPath;
        if (filePath === "" || targetPath === "")
            return;
        latestAppliedWallpaper = filePath;
        wallpaperApplied(filePath);
        closeAfterApply = true;
        if (applyProcess.running)
            applyProcess.running = false;
        applyProcess.wallpaperPath = filePath;
        applyProcess.targetPath = targetPath;
        applyProcess.transitionType = transitionTypes[selectedTransitionIndex];
        applyProcess.running = true;
    }

    Process {
        id: scanProcess
        command: ["python3", "-c", root.scanScript, root.cacheRoot, root.wallpaperDir, String(root.thumbnailWidth), String(root.thumbnailHeight), String(root.thumbnailQuality)]
        stdout: SplitParser {
            onRead: data => {
                if (!root.acceptingScanResults)
                    return;
                try {
                    root.upsertWallpaper(JSON.parse(data));
                } catch (error) {
                }
            }
        }
        onExited: {
            if (!root.acceptingScanResults)
                return;
            root.acceptingScanResults = false;
            root.wallpapersLoaded = true;
            root.syncCurrentIndex();
            root.startNextThumbnail();
        }
    }

    Connections {
        target: SystemServices

        function onWallpaperThumbnailFinished(sourcePath, finishedCachePath, cacheAvailable, updated, errorString) {
            if (sourcePath !== root.inFlightThumbnailSourcePath || finishedCachePath !== root.inFlightThumbnailCachePath)
                return;

            root.thumbnailInFlight = false;
            root.inFlightThumbnailSourcePath = "";
            root.inFlightThumbnailCachePath = "";

            if (root.showCondition && cacheAvailable && errorString === "") {
                const modelIndex = root.wallpaperIndexByPath[sourcePath];
                if (modelIndex !== undefined && modelIndex >= 0 && modelIndex < allWallpapers.count) {
                    const revision = Date.now();
                    allWallpapers.setProperty(modelIndex, "thumbnailReady", true);
                    allWallpapers.setProperty(modelIndex, "thumbnailRequested", true);
                    allWallpapers.setProperty(modelIndex, "thumbnailSource", root.thumbnailUrl(finishedCachePath, revision));
                    allWallpapers.setProperty(modelIndex, "cacheRevision", revision);
                }
            }

            root.startNextThumbnail();
        }
    }

    Process {
        id: applyProcess
        property string wallpaperPath: ""
        property string targetPath: ""
        property string transitionType: "center"
        command: ["python3", "-c", root.applyScript, wallpaperPath, targetPath, transitionType, String(root.transitionStep), String(root.transitionFps)]
        onExited: {
            running = false;
            if (root.closeAfterApply) {
                root.closeAfterApply = false;
                root.closeRequested();
            }
        }
    }

    readonly property real topPad: 14
    readonly property real botPad: 8
    readonly property real hPad: 12
    readonly property real headerH: 24
    readonly property real headerGap: 4
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
                    text: "No wallpapers found\nin " + root.displayPath(root.wallpaperDir)
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
                model: root.showCondition ? allWallpapers : null
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
                            antialiasing: false

                            Image {
                                anchors.fill: parent
                                source: root.showCondition && model.thumbnailSource ? model.thumbnailSource : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: false
                                smooth: true
                                mipmap: false
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
                            border.width: (model.filePath === root.effectiveActiveWallpaper) ? 2.5 : 0
                            border.color: "#60a5fa"
                            Behavior on border.width {
                                NumberAnimation {
                                    duration: 150
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
