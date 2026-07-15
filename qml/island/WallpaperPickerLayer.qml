import QtCore
import QtQuick
import Quickshell.Io
import Quickshell.Widgets
import IslandBackend

FocusScope {
    id: root

    signal closeRequested
    signal wallpaperApplied(string filePath)
    signal wallpaperApplySucceeded(string filePath)

    property bool showCondition: false
    property string iconFontFamily: ""
    property string textFontFamily: ""
    readonly property var userConfig: UserConfig

    property bool pywalEnabled: userConfig.wallpaperPywalEnabled
    property bool customCommandEnabled: userConfig.wallpaperCustomCommandEnabled === true
    property string customCommand: userConfig.wallpaperCustomCommand === undefined || userConfig.wallpaperCustomCommand === null ? "" : String(userConfig.wallpaperCustomCommand)
    property int transitionFps: boundedInt(userConfig.wallpaperTransitionFps, 60, 1, 240)
    property int transitionStep: boundedInt(userConfig.wallpaperTransitionStep, 5, 1, 255)
    property real transitionDuration: boundedReal(userConfig.wallpaperTransitionDuration, 3.0, 0, 120)
    property int transitionAngle: boundedInt(userConfig.wallpaperTransitionAngle, 45, 0, 360)
    property string transitionPosition: nonEmptyString(userConfig.wallpaperTransitionPosition, "center")
    property string transitionBezier: nonEmptyString(userConfig.wallpaperTransitionBezier, ".54,0,.34,.99")
    property string transitionWave: nonEmptyString(userConfig.wallpaperTransitionWave, "20,20")
    property bool transitionInvertY: userConfig.wallpaperTransitionInvertY
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
        + "source,target,transition,step,duration,fps,angle,pos,bezier,wave,invert_y,pywal_enabled=sys.argv[1:13]\n"
        + "if not source:\n"
        + "    sys.exit(2)\n"
        + "applied=source\n"
        + "if target:\n"
        + "    target=os.path.expanduser(target)\n"
        + "    if os.path.realpath(source) != os.path.realpath(target):\n"
        + "        os.makedirs(os.path.dirname(target) or '.',exist_ok=True)\n"
        + "        shutil.copy2(source,target)\n"
        + "    applied=target\n"
        + "cmd=['awww','img',applied,'--transition-type',transition,'--transition-step',step,'--transition-duration',duration,'--transition-fps',fps,'--transition-angle',angle,'--transition-pos',pos,'--transition-bezier',bezier,'--transition-wave',wave]\n"
        + "if invert_y == 'true':\n"
        + "    cmd.append('--invert-y')\n"
        + "result=subprocess.run(cmd,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)\n"
        + "if pywal_enabled == 'true' and result.returncode == 0:\n"
        + "    subprocess.run(['wal','-i',applied],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)\n"
        + "sys.exit(result.returncode)\n"

    readonly property var transitionTypes: ["none", "simple", "fade", "left", "right", "top", "bottom", "wipe", "wave", "grow", "center", "any", "outer", "random"]
    readonly property string configuredTransitionType: validTransitionType(userConfig.wallpaperTransitionType)

    focus: showCondition
    activeFocusOnTab: true
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
            root.grabKeyboardFocus();
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
        if (scanProcess.running)
            scanProcess.running = false;
        if (applyProcess.running)
            applyProcess.running = false;
        if (customApplyProcess.running)
            customApplyProcess.running = false;
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

    function boundedInt(value, fallback, minimumValue, maximumValue) {
        const number = Number(value);
        if (!isFinite(number))
            return fallback;
        return Math.max(minimumValue, Math.min(maximumValue, Math.round(number)));
    }

    function boundedReal(value, fallback, minimumValue, maximumValue) {
        const number = Number(value);
        if (!isFinite(number))
            return fallback;
        return Math.max(minimumValue, Math.min(maximumValue, number));
    }

    function nonEmptyString(value, fallback) {
        const text = String(value === undefined || value === null ? "" : value).trim();
        return text.length > 0 ? text : fallback;
    }

    function validTransitionType(value) {
        const text = nonEmptyString(value, "center");
        return transitionTypes.indexOf(text) >= 0 ? text : "center";
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

    function grabKeyboardFocus() {
        root.focus = true;
        root.forceActiveFocus();
    }

    function moveNext() {
        pathView.incrementCurrentIndex();
    }

    function movePrevious() {
        pathView.decrementCurrentIndex();
    }

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Escape:
            root.closeRequested();
            event.accepted = true;
            break;
        case Qt.Key_Right:
        case Qt.Key_L:
        case Qt.Key_Tab:
            root.moveNext();
            event.accepted = true;
            break;
        case Qt.Key_Left:
        case Qt.Key_H:
        case Qt.Key_Backtab:
            root.movePrevious();
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
        const commandText = root.customCommand.trim();
        const useCustomCommand = root.customCommandEnabled && commandText.length > 0;
        if (filePath === "")
            return;
        latestAppliedWallpaper = filePath;
        wallpaperApplied(filePath);
        closeAfterApply = true;
        if (applyProcess.running)
            applyProcess.running = false;
        if (customApplyProcess.running)
            customApplyProcess.running = false;
        if (useCustomCommand) {
            customApplyProcess.wallpaperPath = filePath;
            customApplyProcess.targetPath = targetPath;
            customApplyProcess.commandText = root.customCommand;
            customApplyProcess.running = true;
            return;
        }
        applyProcess.wallpaperPath = filePath;
        applyProcess.targetPath = targetPath;
        applyProcess.transitionType = configuredTransitionType;
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
        command: [
            "python3", "-c", root.applyScript,
            wallpaperPath,
            targetPath,
            transitionType,
            String(root.transitionStep),
            String(root.transitionDuration),
            String(root.transitionFps),
            String(root.transitionAngle),
            root.transitionPosition,
            root.transitionBezier,
            root.transitionWave,
            root.transitionInvertY ? "true" : "false",
            root.pywalEnabled ? "true" : "false"
        ]
        onExited: function(exitCode) {
            running = false;
            if (exitCode === 0)
                root.wallpaperApplySucceeded(wallpaperPath);
            if (root.closeAfterApply) {
                root.closeAfterApply = false;
                root.closeRequested();
            }
        }
    }

    Process {
        id: customApplyProcess
        property string wallpaperPath: ""
        property string targetPath: ""
        property string commandText: ""
        command: [
            "bash", "-c", commandText,
            "tide-island-wallpaper",
            wallpaperPath,
            targetPath
        ]
        onExited: function(exitCode) {
            running = false;
            if (exitCode === 0)
                root.wallpaperApplySucceeded(wallpaperPath);
            if (root.closeAfterApply) {
                root.closeAfterApply = false;
                root.closeRequested();
            }
        }
    }

    readonly property real topPad: 14
    readonly property real botPad: 8
    readonly property real hPad: 12
    readonly property real headerH: 0
    readonly property real headerGap: 0
    readonly property real labelH: 22
    readonly property real labelGap: 5

    readonly property real cardW: Math.round(slotW * 1.15)
    readonly property real cardH: Math.round(cardW * 0.58)
    readonly property real spacing: slotW * 1.20

    readonly property real sideScale: 0.78

    readonly property real slotW: (width - hPad * 2) / 5

    readonly property real cardAreaH: height - topPad - headerH - headerGap - botPad
    readonly property real cardPathY: cardAreaH / 2

    // ── UI ────────────────────────────────────────────────────────────────────
    Column {
        anchors.fill: parent
        anchors.topMargin: root.topPad
        anchors.leftMargin: root.hPad
        anchors.rightMargin: root.hPad
        anchors.bottomMargin: root.botPad
        spacing: 6

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
                    startY: root.cardPathY
                    PathLine {
                        x: pathView.width / 2 + root.spacing * 2
                        y: root.cardPathY
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
                        transformOrigin: Item.Center

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
