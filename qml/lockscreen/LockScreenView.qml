pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Effects

Item {
    id: root
    clip: true
    // This view has no session or authentication authority; the settings app uses it too.
    property var settings: ({})
    property var styleTokens: null
    property bool preview: false
    property bool interactive: true
    property real entrance: 1
    property real departure: 0
    property bool unlocking: false
    property bool layoutEditing: false
    property real editingUiScale: 1
    property string movingWidget: ""
    property var pendingPositions: ({})
    property point dragOffset: Qt.point(0, 0)
    property size movingSize: Qt.size(0, 0)
    readonly property real backgroundReveal: 1 - Math.pow(1 - Math.max(0, Math.min(1, entrance)), 3)
    readonly property real chromeOpacity: backgroundReveal * (1 - departure)
    property string userName: "User"
    property string homePath: ""
    property string wallpaperPath: ""
    property string textFont: "Sans Serif"
    property string timeFont: textFont
    property date now: new Date()
    property bool busy: false
    property bool retryBlocked: false
    property string authMessage: ""
    property bool authError: false
    property string prompt: "Password"
    property bool responseVisible: false
    property bool capsLock: false
    property string trackTitle: ""
    property string trackArtist: ""
    property string albumArt: ""
    property bool playing: false
    property bool canPlay: false
    property bool canPrevious: false
    property bool canNext: false
    property bool canFavorite: false
    property bool favorite: false
    property string favoriteHint: "Favorite · available for connected Spotify"
    property real progress: 0
    property string elapsed: "0:00"
    property string duration: "0:00"
    property bool weatherReady: false
    property bool weatherStale: false
    property string temperature: "--"
    property string weatherCondition: "Weather unavailable"
    property string weatherLocation: "Local weather"
    property string weatherRange: ""
    property string weatherType: "sunny"
    property string feelsLike: "--"
    property string humidity: "--"
    property bool hasBattery: false
    property int batteryPercent: 0
    property bool charging: false

    // The shell and settings preview both supply the project's existing tokens.
    // Matching fallbacks keep the view usable on its own for visual review.
    readonly property color accent: styleValue("accent", "#0a84ff")
    readonly property color secondary: styleValue("textSecondary", "#b6b6bf")
    readonly property color foreground: styleValue("textPrimary", "#f5f5f7")
    readonly property color muted: styleValue("textMuted", "#acadb6")
    readonly property color surface: styleValue("panel", "#202125")
    readonly property color surfaceHigh: styleValue("module", "#303136")
    readonly property color errorColor: styleValue("error", "#ff7c72")
    readonly property real cardAlpha: option("cardOpacity", 82) / 100
    readonly property real corner: option("radius", styleValue("radiusPanel", 28))
    readonly property string displayName: option("displayName", "").trim() || userName

    // One uniform scale keeps the composition intact on small or scaled outputs.
    readonly property real sceneScale: Math.max(0.4, Math.min(1, width / 1280, height / 860))
    readonly property real stageWidth: width / sceneScale
    readonly property real stageHeight: height / sceneScale

    readonly property bool showClock: option("showClock", true)
    readonly property bool showDate: option("showDate", true)
    readonly property bool showAvatar: option("showAvatar", true)
    readonly property bool showName: option("showName", true)
    readonly property real clockHeight: (showClock ? 164 : 0) + (showDate ? 30 : 0)
    readonly property real profileHeight: (showAvatar ? 88 : 0) + (showName ? 30 : 0) + (showAvatar && showName ? 12 : 0)
    readonly property real passwordHeight: 46
    readonly property real topLine: Math.max(56, stageHeight * 0.1)
    readonly property real weatherY: clockHeight > 0 ? topLine + clockHeight + 2 : topLine
    readonly property real musicY: (option("showWeather", true) ? weatherY + weatherCard.height : weatherY) + 26
    readonly property real passwordY: stageHeight - Math.max(118, stageHeight * 0.15) - passwordHeight

    // Idle dimming leaves only the time on screen; any input restores the rest.
    property bool idle: false
    readonly property bool quiet: idle && option("idleDim", true) && !preview && !layoutEditing && !unlocking && !busy
                                  && password.text.length === 0 && powerArmed === ""
    property real quietness: quiet ? 1 : 0
    Behavior on quietness {
        NumberAnimation {
            duration: root.quiet ? 900 : 260
            easing.type: Easing.InOutCubic
        }
    }
    readonly property real chromeFade: 1 - quietness
    // While idle the time settles toward the optical center, unless the user placed it.
    readonly property real quietClockShift: option("customLayoutEnabled", false) && option("positions", {}).clock
                                            ? 0 : Math.max(0, stageHeight * 0.4 - (topLine + clockHeight / 2))
    property string powerArmed: ""

    signal submitted(string response)
    signal cancelAuthentication
    signal previousRequested
    signal playPauseRequested
    signal nextRequested
    signal favoriteRequested
    signal powerRequested(string action)
    signal inputActivity
    signal positionEdited(string widgetKey, real x, real y)

    function option(key, fallback) {
        return settings[key] === undefined ? fallback : settings[key];
    }
    function styleValue(key, fallback) {
        return styleTokens ? styleTokens[key] : fallback;
    }
    function boundedCenter(value, extent, cardExtent) {
        const margin = Math.min(24, extent * 0.03);
        return Math.max(margin + cardExtent / 2, Math.min(extent - margin - cardExtent / 2, value));
    }
    function positionFor(key, defaultX, defaultY, cardWidth, cardHeight) {
        const positions = option("positions", {});
        const point = pendingPositions[key] || positions[key];
        if (!(option("customLayoutEnabled", false) || layoutEditing) || !point || !isFinite(point.x) || !isFinite(point.y))
            return Qt.point(defaultX, defaultY);
        const factor = body.scale;
        const centerX = boundedCenter(point.x * width, width, cardWidth * factor);
        const centerY = boundedCenter(point.y * height, height, cardHeight * factor);
        return Qt.point((centerX - body.x) / factor - cardWidth / 2, (centerY - body.y) / factor - cardHeight / 2);
    }
    function widgetPosition(key) {
        const cards = {profile: profileCard, clock: clockCard, password: passwordCard, weather: weatherCard, music: musicCard};
        const card = cards[key];
        if (!card)
            return Qt.point(0.5, 0.5);
        return Qt.point((body.x + (card.x + card.width / 2) * body.scale) / Math.max(1, width),
                        (body.y + (card.y + card.height / 2) * body.scale) / Math.max(1, height));
    }
    function beginMove(key, card, pointer) {
        if (!layoutEditing || unlocking)
            return;
        const origin = card.parent.mapToItem(root, card.x, card.y);
        movingWidget = key;
        movingSize = Qt.size(card.width, card.height);
        dragOffset = Qt.point(pointer.x - origin.x, pointer.y - origin.y);
    }
    function moveWidget(pointer) {
        if (movingWidget === "" || !layoutEditing)
            return;
        const cardWidth = movingSize.width * body.scale;
        const cardHeight = movingSize.height * body.scale;
        const centerX = boundedCenter(pointer.x - dragOffset.x + cardWidth / 2, width, cardWidth);
        const centerY = boundedCenter(pointer.y - dragOffset.y + cardHeight / 2, height, cardHeight);
        const next = Object.assign({}, pendingPositions);
        next[movingWidget] = {
            x: centerX / width,
            y: centerY / height
        };
        pendingPositions = next;
    }
    function finishMove() {
        const point = pendingPositions[movingWidget];
        if (movingWidget !== "" && point)
            positionEdited(movingWidget, point.x, point.y);
        movingWidget = "";
        pendingPositions = ({});
    }
    function cancelMove() {
        movingWidget = "";
        pendingPositions = ({});
    }
    onLayoutEditingChanged: if (!layoutEditing)
        cancelMove()
    function imageUrl(path) {
        if (!path)
            return "";
        if (path.startsWith("~/"))
            path = homePath + path.substring(1);
        return path.startsWith("/") ? "file://" + path.split("/").map(encodeURIComponent).join("/") : path;
    }
    function clearInput() {
        password.clear();
        revealPassword = false;
    }
    function pad(value) {
        return ("0" + value).slice(-2);
    }
    function clockHours() {
        return option("use24Hour", true) ? pad(now.getHours()) : String(now.getHours() % 12 || 12);
    }
    function formattedTime() {
        return clockHours() + ":" + pad(now.getMinutes()) + (option("showSeconds", false) ? ":" + pad(now.getSeconds()) : "")
            + (option("use24Hour", true) ? "" : " " + (now.getHours() < 12 ? "AM" : "PM"));
    }
    function weatherGlyph(type) {
        switch (type) {
        case "sunny":
            return "sun";
        case "partly_cloudy":
            return "partly";
        case "fog":
            return "fog";
        case "rain":
            return "rain";
        case "thunder":
            return "thunder";
        case "snow":
            return "snow";
        default:
            return "cloud";
        }
    }
    function initials(name) {
        const parts = String(name).trim().split(/\s+/).filter(part => part.length > 0);
        if (parts.length === 0)
            return "";
        return String(parts[0].charAt(0) + (parts.length > 1 ? parts[parts.length - 1].charAt(0) : "")).toUpperCase();
    }
    function focusInput() {
        if (interactive && !unlocking)
            password.forceActiveFocus();
    }
    function wake() {
        idle = false;
        if (!preview)
            idleTimer.restart();
    }
    function submit() {
        if (!interactive || preview || unlocking || busy || retryBlocked || password.text.length === 0)
            return;
        const response = password.text;
        password.clear();
        revealPassword = false;
        submitted(response);
    }
    function requestPower(action) {
        wake();
        if (powerArmed === action) {
            powerArmed = "";
            disarmTimer.stop();
            if (!preview && interactive)
                powerRequested(action);
            return;
        }
        powerArmed = action;
        disarmTimer.restart();
    }
    property bool revealPassword: false
    onBusyChanged: if (!busy)
        focusInput()
    onInteractiveChanged: if (interactive)
        focusInput()
    onAuthErrorChanged: if (authError && !preview)
        shake.restart()
    onUnlockingChanged: if (unlocking)
        idle = false
    Component.onCompleted: if (!preview) {
        focusInput();
        idleTimer.start();
    }

    Timer {
        id: idleTimer
        interval: 14000
        onTriggered: root.idle = true
    }
    Timer {
        id: disarmTimer
        interval: 3500
        onTriggered: root.powerArmed = ""
    }

    // Any pointer movement or click wakes the screen and returns focus to the field.
    HoverHandler {
        // Qt re-delivers hover when items move under a still cursor; only real motion counts.
        property point lastPosition: Qt.point(-1, -1)
        enabled: !root.preview
        onPointChanged: {
            const position = point.position;
            if (Math.abs(position.x - lastPosition.x) + Math.abs(position.y - lastPosition.y) > 4) {
                lastPosition = position;
                root.wake();
            }
        }
    }
    MouseArea {
        anchors.fill: parent
        enabled: !root.preview && !root.layoutEditing
        onPressed: mouse => {
            root.wake();
            root.focusInput();
            mouse.accepted = false;
        }
    }

    Item {
        id: backdrop
        anchors.fill: parent
        scale: 1.04 - 0.04 * root.backgroundReveal + 0.025 * root.departure
        opacity: 0.12 + 0.88 * root.backgroundReveal

        // Used when no wallpaper is available: a deep, quiet tide palette.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: "#0d1620"
                }
                GradientStop {
                    position: 0.55
                    color: "#1b2c38"
                }
                GradientStop {
                    position: 1
                    color: "#0a0e13"
                }
            }
        }
        Image {
            anchors.fill: parent
            visible: backgroundImage.status !== Image.Ready
            sourceSize: Qt.size(320, 200)
            smooth: true
            source: "data:image/svg+xml;utf8," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 320 200" preserveAspectRatio="none">'
                + '<defs><radialGradient id="a" cx="50%" cy="108%" r="72%"><stop offset="0" stop-color="#3a7f8f" stop-opacity="0.55"/>'
                + '<stop offset="1" stop-color="#3a7f8f" stop-opacity="0"/></radialGradient>'
                + '<radialGradient id="b" cx="12%" cy="-10%" r="60%"><stop offset="0" stop-color="#6b5a8e" stop-opacity="0.28"/>'
                + '<stop offset="1" stop-color="#6b5a8e" stop-opacity="0"/></radialGradient></defs>'
                + '<rect width="320" height="200" fill="url(#a)"/><rect width="320" height="200" fill="url(#b)"/></svg>')
        }
        Image {
            id: backgroundImage
            objectName: "lockWallpaper"
            anchors.fill: parent
            source: root.imageUrl(root.option("wallpaperPath", "") || root.wallpaperPath)
            sourceSize.width: Math.min(2560, root.width * 1.5)
            sourceSize.height: Math.min(1600, root.height * 1.5)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: !backgroundEffect.visible
        }
        MultiEffect {
            id: backgroundEffect
            anchors.fill: parent
            source: backgroundImage
            visible: backgroundImage.status === Image.Ready
            opacity: visible ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                }
            }
            blurEnabled: root.option("blur", 48) > 0
            blur: Math.min(1, root.option("blur", 48) / 100 + (1 - root.backgroundReveal) * 0.2) * (1 - root.departure)
            blurMax: 64
            saturation: 0.08 * (1 - root.departure)
            autoPaddingEnabled: false
        }
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0.02, 0.03, 0.035, Math.min(0.9, root.option("dim", 32) / 100 + 0.28 * root.quietness) * (1 - root.departure))
        }
        // Soft scrims behind the clock and the sign-in area keep text legible on bright wallpapers.
        Rectangle {
            anchors.fill: parent
            opacity: 1 - root.departure
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.rgba(0, 0, 0, 0.22)
                }
                GradientStop {
                    position: 0.38
                    color: Qt.rgba(0, 0, 0, 0)
                }
                GradientStop {
                    position: 0.66
                    color: Qt.rgba(0, 0, 0, 0)
                }
                GradientStop {
                    position: 1
                    color: Qt.rgba(0, 0, 0, 0.32)
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 24
        visible: root.layoutEditing
        color: "transparent"
        border.width: 1
        border.color: Qt.alpha(root.accent, 0.3)
        radius: 12
    }
    Rectangle {
        visible: root.layoutEditing
        anchors.horizontalCenter: parent.horizontalCenter
        y: 24
        width: 1
        height: parent.height - 48
        color: Qt.alpha(root.accent, 0.18)
    }
    Rectangle {
        visible: root.layoutEditing
        anchors.verticalCenter: parent.verticalCenter
        x: 24
        width: parent.width - 48
        height: 1
        color: Qt.alpha(root.accent, 0.18)
    }

    Item {
        id: body
        width: root.stageWidth
        height: root.stageHeight
        scale: root.sceneScale
        transformOrigin: Item.TopLeft

        // ── Time and date ───────────────────────────────────────────────
        LockCard {
            id: clockCard
            styleTokens: root.styleTokens
            objectName: "clockCard"
            z: root.movingWidget === "clock" ? 10 : 0
            readonly property point layoutPosition: root.positionFor("clock", (body.width - width) / 2, root.topLine, width, height)
            x: layoutPosition.x
            y: layoutPosition.y
            LockLayoutHandle {
                editor: root
                widgetKey: "clock"
                label: "Time and date"
            }
            entrance: root.entrance
            departure: root.departure
            offsetY: root.quietness * root.quietClockShift
            width: 640
            height: root.clockHeight
            visible: root.clockHeight > 0 && opacity > 0.001
            radius: root.corner
            surfaceOpacity: 0

            Column {
                id: clockColumn
                width: parent.width
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: "#000000"
                    shadowOpacity: 0.32
                    shadowBlur: 0.9
                    shadowVerticalOffset: 2
                }

                Text {
                    objectName: "clockDate"
                    width: parent.width
                    height: 30
                    visible: root.showDate
                    text: Qt.formatDate(root.now, "dddd, d MMMM")
                    color: root.foreground
                    opacity: 0.92
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.family: root.textFont
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.2
                }
                Item {
                    objectName: "clockText"
                    width: parent.width
                    height: 164
                    visible: root.showClock
                    Accessible.name: root.formattedTime()

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: -4
                        spacing: 6

                        Text {
                            id: mainTime
                            text: root.clockHours() + ":" + root.pad(root.now.getMinutes())
                            color: root.foreground
                            font.family: root.timeFont
                            font.pixelSize: 164
                            font.weight: Font.DemiBold
                            font.letterSpacing: -5
                            font.features: {
                                "tnum": 1
                            }
                        }
                        Column {
                            // Align with the top of the digits rather than the line box.
                            y: mainTime.y + mainTime.baselineOffset - mainTime.font.pixelSize * 0.715
                            visible: root.option("showSeconds", false) || !root.option("use24Hour", true)
                            spacing: 2
                            Text {
                                visible: !root.option("use24Hour", true)
                                text: root.now.getHours() < 12 ? "AM" : "PM"
                                color: root.foreground
                                opacity: 0.78
                                font.family: root.textFont
                                font.pixelSize: 22
                                font.weight: Font.DemiBold
                                font.letterSpacing: 1
                            }
                            Text {
                                visible: root.option("showSeconds", false)
                                text: root.pad(root.now.getSeconds())
                                color: root.foreground
                                opacity: 0.6
                                font.family: root.timeFont
                                font.pixelSize: 30
                                font.weight: Font.Medium
                                font.features: {
                                    "tnum": 1
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Weather ─────────────────────────────────────────────────────
        LockCard {
            id: weatherCard
            styleTokens: root.styleTokens
            objectName: "weatherCard"
            z: root.movingWidget === "weather" ? 10 : 0
            readonly property point layoutPosition: root.positionFor("weather", (body.width - width) / 2, root.weatherY, width, height)
            x: layoutPosition.x
            y: layoutPosition.y
            LockLayoutHandle {
                editor: root
                widgetKey: "weather"
                label: "Weather"
            }
            entrance: root.entrance
            departure: root.departure
            fade: root.chromeFade
            stagger: 0.06
            width: Math.min(560, weatherRow.implicitWidth + 32)
            height: 40
            visible: root.option("showWeather", true) && opacity > 0.001
            radius: height / 2
            surfaceOpacity: 0

            Row {
                id: weatherRow
                anchors.centerIn: parent
                spacing: 10
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: "#000000"
                    shadowOpacity: 0.3
                    shadowBlur: 0.7
                    shadowVerticalOffset: 1
                }

                LockGlyph {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    height: 22
                    name: root.weatherGlyph(root.weatherType)
                    ink: root.foreground
                    opacity: root.weatherReady ? 1 : 0.6
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.weatherReady
                    text: root.temperature
                    color: root.foreground
                    font.family: root.textFont
                    font.pixelSize: 19
                    font.weight: Font.DemiBold
                    font.features: {
                        "tnum": 1
                    }
                }
                Text {
                    id: weatherDetail
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, 440)
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    text: {
                        if (!root.weatherReady)
                            return root.weatherCondition;
                        const parts = [root.weatherCondition];
                        if (root.weatherRange)
                            parts.push(root.weatherRange);
                        if (root.weatherStale)
                            parts.push("cached");
                        return parts.filter(part => part).join("   ·   ");
                    }
                    color: root.foreground
                    opacity: 0.78
                    font.family: root.textFont
                    font.pixelSize: 16
                    font.weight: Font.Medium
                }
            }
            HoverHandler {
                id: weatherHover
            }
            ToolTip.visible: weatherHover.hovered && root.weatherReady && !root.layoutEditing
            ToolTip.delay: 500
            ToolTip.text: root.weatherLocation + " · Feels like " + root.feelsLike + " · " + root.humidity + " humidity"
        }

        // ── Now playing ─────────────────────────────────────────────────
        LockCard {
            id: musicCard
            styleTokens: root.styleTokens
            objectName: "musicCard"
            z: root.movingWidget === "music" ? 10 : 0
            readonly property point layoutPosition: root.positionFor("music", (body.width - width) / 2, root.musicY, width, height)
            x: layoutPosition.x
            y: layoutPosition.y
            LockLayoutHandle {
                editor: root
                widgetKey: "music"
                label: "Music player"
            }
            entrance: root.entrance
            departure: root.departure
            fade: root.chromeFade
            stagger: 0.12
            readonly property bool showArt: root.option("showAlbumArt", true)
            readonly property bool showInfo: root.option("showTrackInfo", true)
            readonly property real contentX: showArt ? 86 : 20
            width: 440
            height: 96
            visible: root.option("showMusic", true) && opacity > 0.001
            radius: Math.min(root.corner, 26)
            surfaceColor: root.surface
            surfaceOpacity: root.cardAlpha

            Rectangle {
                id: coverFrame
                x: 16
                y: 16
                width: 56
                height: 56
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.08)
                visible: musicCard.showArt
                Image {
                    id: cover
                    anchors.fill: parent
                    source: musicCard.visible && musicCard.showArt ? root.albumArt : ""
                    asynchronous: true
                    sourceSize: Qt.size(112, 112)
                    fillMode: Image.PreserveAspectCrop
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: coverMask
                    }
                }
                Rectangle {
                    id: coverMask
                    anchors.fill: parent
                    radius: 12
                    visible: false
                    layer.enabled: true
                }
                LockGlyph {
                    anchors.centerIn: parent
                    width: 24
                    height: 24
                    name: "music"
                    ink: root.foreground
                    opacity: 0.7
                    visible: cover.status !== Image.Ready
                }
            }
            Column {
                objectName: "trackInfo"
                visible: musicCard.showInfo
                x: musicCard.contentX
                y: 20
                width: musicControls.x - x - 12
                spacing: 3
                Text {
                    width: parent.width
                    text: root.trackTitle || "Nothing playing"
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: root.foreground
                    font.family: root.textFont
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }
                Text {
                    width: parent.width
                    text: root.trackArtist || "No active player"
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: root.foreground
                    opacity: 0.62
                    font.family: root.textFont
                    font.pixelSize: 13
                }
            }
            Row {
                id: musicControls
                anchors.right: parent.right
                anchors.rightMargin: 12
                y: musicCard.showInfo ? 16 : 26
                spacing: 2
                LockAction {
                    styleTokens: root.styleTokens
                    glyph: "heart"
                    transport: true
                    text: root.favoriteHint
                    selected: root.favorite
                    visible: root.canFavorite || root.favorite
                    enabled: root.canFavorite && (root.interactive || root.preview)
                    onClicked: root.favoriteRequested()
                }
                LockAction {
                    styleTokens: root.styleTokens
                    glyph: "previous"
                    transport: true
                    text: "Previous track"
                    enabled: root.canPrevious && (root.interactive || root.preview)
                    onClicked: root.previousRequested()
                }
                LockAction {
                    styleTokens: root.styleTokens
                    glyph: root.playing ? "pause" : "play"
                    text: root.playing ? "Pause" : "Play"
                    transport: true
                    enabled: root.canPlay && (root.interactive || root.preview)
                    onClicked: root.playPauseRequested()
                }
                LockAction {
                    styleTokens: root.styleTokens
                    glyph: "next"
                    transport: true
                    text: "Next track"
                    enabled: root.canNext && (root.interactive || root.preview)
                    onClicked: root.nextRequested()
                }
            }
            Item {
                x: musicCard.contentX
                y: 70
                width: parent.width - x - 20
                height: 14
                Text {
                    id: elapsedText
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.elapsed
                    color: root.foreground
                    opacity: 0.55
                    font.family: root.textFont
                    font.pixelSize: 11
                    font.features: {
                        "tnum": 1
                    }
                }
                Rectangle {
                    anchors.left: elapsedText.right
                    anchors.leftMargin: 10
                    anchors.right: durationText.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    height: 4
                    radius: 2
                    color: Qt.rgba(1, 1, 1, 0.16)
                    Rectangle {
                        width: Math.max(height, parent.width * Math.max(0, Math.min(1, root.progress)))
                        height: parent.height
                        radius: 2
                        color: root.foreground
                        opacity: 0.9
                        Behavior on width {
                            NumberAnimation {
                                duration: 400
                            }
                        }
                    }
                }
                Text {
                    id: durationText
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.duration
                    color: root.foreground
                    opacity: 0.55
                    font.family: root.textFont
                    font.pixelSize: 11
                    font.features: {
                        "tnum": 1
                    }
                }
            }
        }

        // ── Who is signing in ───────────────────────────────────────────
        LockCard {
            id: profileCard
            styleTokens: root.styleTokens
            objectName: "profileCard"
            z: root.movingWidget === "profile" ? 10 : 0
            readonly property point layoutPosition: root.positionFor("profile", (body.width - width) / 2, root.passwordY - 22 - height, width, height)
            x: layoutPosition.x
            y: layoutPosition.y
            LockLayoutHandle {
                editor: root
                widgetKey: "profile"
                label: "User information"
            }
            entrance: root.entrance
            departure: root.departure
            fade: root.chromeFade
            stagger: 0.16
            width: 320
            height: Math.max(1, root.profileHeight)
            visible: root.profileHeight > 0 && opacity > 0.001
            radius: root.corner
            surfaceOpacity: 0

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: "#000000"
                    shadowOpacity: 0.28
                    shadowBlur: 0.8
                    shadowVerticalOffset: 2
                }

                Rectangle {
                    id: avatarFrame
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 88
                    height: 88
                    radius: 44
                    visible: root.showAvatar
                    color: Qt.rgba(1, 1, 1, 0.14)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.22)
                    Text {
                        anchors.centerIn: parent
                        visible: avatar.status !== Image.Ready && text.length > 0
                        text: root.initials(root.displayName)
                        color: root.foreground
                        font.family: root.textFont
                        font.pixelSize: 32
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1
                    }
                    LockGlyph {
                        anchors.centerIn: parent
                        width: 34
                        height: 34
                        name: "user"
                        ink: root.foreground
                        visible: avatar.status !== Image.Ready && root.initials(root.displayName).length === 0
                    }
                    Image {
                        id: avatar
                        anchors.fill: parent
                        anchors.margins: 1
                        source: root.showAvatar ? root.imageUrl(root.option("avatarPath", "")) : ""
                        sourceSize: Qt.size(176, 176)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: status === Image.Ready
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: avatarMask
                        }
                    }
                    Rectangle {
                        id: avatarMask
                        anchors.fill: avatar
                        radius: width / 2
                        visible: false
                        layer.enabled: true
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(implicitWidth, 320)
                    height: 30
                    visible: root.showName
                    text: root.displayName
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: root.foreground
                    font.family: root.textFont
                    font.pixelSize: 21
                    font.weight: Font.DemiBold
                }
            }
        }

        // ── Password ────────────────────────────────────────────────────
        LockCard {
            id: passwordCard
            styleTokens: root.styleTokens
            objectName: "passwordCard"
            z: root.movingWidget === "password" ? 10 : 1
            readonly property point layoutPosition: root.positionFor("password", (body.width - width) / 2, root.passwordY, width, height)
            x: layoutPosition.x
            y: layoutPosition.y
            LockLayoutHandle {
                editor: root
                widgetKey: "password"
                label: "Password"
            }
            entrance: root.entrance
            departure: root.departure
            fade: root.chromeFade
            stagger: 0.2
            // Never hide the field: invisible items drop keyboard focus, and typing must
            // reach it during the entrance animation and while the screen is idle.
            visible: true
            width: 320
            height: root.passwordHeight
            radius: height / 2
            surfaceColor: root.surface
            surfaceOpacity: root.cardAlpha
            border.width: password.activeFocus || root.authError ? 1.5 : 1
            outlineColor: root.authError ? root.errorColor : password.activeFocus ? Qt.rgba(1, 1, 1, 0.34) : Qt.rgba(1, 1, 1, 0.16)
            Behavior on outlineColor {
                ColorAnimation {
                    duration: 180
                }
            }

            SequentialAnimation {
                id: shake
                NumberAnimation {
                    target: passwordCard
                    property: "offsetX"
                    to: -14
                    duration: 55
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    target: passwordCard
                    property: "offsetX"
                    to: 11
                    duration: 75
                    easing.type: Easing.InOutQuad
                }
                NumberAnimation {
                    target: passwordCard
                    property: "offsetX"
                    to: -7
                    duration: 70
                    easing.type: Easing.InOutQuad
                }
                NumberAnimation {
                    target: passwordCard
                    property: "offsetX"
                    to: 3
                    duration: 65
                    easing.type: Easing.InOutQuad
                }
                NumberAnimation {
                    target: passwordCard
                    property: "offsetX"
                    to: 0
                    duration: 60
                    easing.type: Easing.OutQuad
                }
            }

            TextField {
                id: password
                objectName: "passwordInput"
                x: 20
                width: (revealButton.visible ? revealButton.x : submitButton.x) - x - 4
                height: parent.height
                enabled: root.interactive && !root.unlocking && !root.busy && !root.retryBlocked && !root.preview
                background: null
                leftPadding: 0
                rightPadding: 0
                echoMode: root.responseVisible || root.revealPassword ? TextInput.Normal : TextInput.Password
                passwordCharacter: "•"
                passwordMaskDelay: 0
                placeholderText: root.preview ? "Enter password" : root.prompt === "Password" ? "Enter password" : root.prompt
                placeholderTextColor: Qt.rgba(1, 1, 1, 0.5)
                color: root.foreground
                font.family: root.textFont
                font.pixelSize: echoMode === TextInput.Password && text.length > 0 ? 18 : 15
                font.letterSpacing: echoMode === TextInput.Password && text.length > 0 ? 2 : 0
                verticalAlignment: TextInput.AlignVCenter
                selectionColor: Qt.alpha(root.accent, 0.35)
                maximumLength: 1024
                inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                selectByMouse: false
                onAccepted: root.submit()
                onTextChanged: if (text.length === 0)
                    root.revealPassword = false
                Keys.onPressed: event => {
                    root.wake();
                    // Re-check Caps Lock when it is toggled or a new attempt starts.
                    if (event.key === Qt.Key_CapsLock || text.length === 0)
                        root.inputActivity();
                    event.accepted = false;
                }
                Keys.onReleased: event => {
                    if (event.key === Qt.Key_CapsLock)
                        root.inputActivity();
                    event.accepted = false;
                }
                Keys.onEscapePressed: {
                    root.wake();
                    clear();
                    root.revealPassword = false;
                    root.powerArmed = "";
                    root.cancelAuthentication();
                }
            }
            LockAction {
                id: revealButton
                styleTokens: root.styleTokens
                x: submitButton.x - width - 2
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 32
                glyphSize: 17
                glyph: root.revealPassword ? "eyeOff" : "eye"
                text: root.revealPassword ? "Hide password" : "Show password"
                visible: !root.responseVisible && password.text.length > 0
                enabled: root.interactive && !root.unlocking && !root.busy
                opacity: enabled ? 0.8 : 0.35
                onClicked: {
                    root.revealPassword = !root.revealPassword;
                    root.focusInput();
                }
            }
            LockAction {
                id: submitButton
                objectName: "unlockButton"
                styleTokens: root.styleTokens
                x: parent.width - width - 7
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 32
                glyphSize: 16
                prominent: true
                glyph: root.unlocking ? "check" : "arrow"
                spinning: root.busy
                text: "Unlock"
                enabled: root.busy || (root.interactive && !root.unlocking && !root.preview && !root.retryBlocked && password.text.length > 0)
                onClicked: root.submit()
            }

            Item {
                id: feedback
                objectName: "passwordFeedback"
                // Keep feedback visible when the input is dragged to the bottom edge.
                readonly property bool below: body.y + (passwordCard.y + passwordCard.height + 14 + height) * body.scale <= root.height - 12
                y: below ? passwordCard.height + 14 : -height - 14
                width: parent.width
                height: 20
                readonly property string message: {
                    if (root.unlocking)
                        return "Welcome back";
                    if (root.busy)
                        return "Verifying…";
                    if (root.authMessage)
                        return root.authMessage;
                    if (root.capsLock)
                        return "Caps Lock is on";
                    return "";
                }
                opacity: message ? 1 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 160
                    }
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 6
                    LockGlyph {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 14
                        height: 14
                        visible: !root.unlocking && !root.busy && !root.authMessage && root.capsLock
                        name: "capslock"
                        ink: root.foreground
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, passwordCard.width + 120)
                        text: feedback.message
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: root.authError ? root.errorColor : root.foreground
                        opacity: root.authError ? 1 : 0.82
                        font.family: root.textFont
                        font.pixelSize: 13
                        font.weight: Font.Medium
                    }
                }
            }
        }
    }

    // ── Chrome: status, power and message ───────────────────────────────
    LockGlyph {
        objectName: "lockState"
        anchors.horizontalCenter: parent.horizontalCenter
        y: 22 * root.sceneScale
        width: 18 * root.sceneScale
        height: width
        name: root.unlocking ? "unlock" : "lock"
        ink: root.foreground
        stroke: 1.9
        opacity: 0.85 * root.chromeOpacity
    }

    Row {
        id: statusRow
        objectName: "profileBattery"
        anchors.right: parent.right
        anchors.rightMargin: 26 * root.sceneScale
        y: 18 * root.sceneScale
        height: 26 * root.sceneScale
        spacing: 8 * root.sceneScale
        visible: root.option("showBattery", true)
        opacity: root.chromeOpacity * (0.4 + 0.6 * root.chromeFade)

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.hasBattery ? root.batteryPercent + "%" : "AC"
            color: root.foreground
            font.family: root.textFont
            font.pixelSize: 13 * root.sceneScale
            font.weight: Font.DemiBold
            font.features: {
                "tnum": 1
            }
            Accessible.name: root.hasBattery ? (root.charging ? "Charging, " : "Battery, ") + root.batteryPercent + " percent" : "Connected to power"
        }
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 27 * root.sceneScale
            height: 13 * root.sceneScale
            visible: root.hasBattery
            Rectangle {
                id: batteryShell
                width: parent.width - 2.5 * root.sceneScale
                height: parent.height
                radius: 3.5 * root.sceneScale
                color: "transparent"
                border.width: Math.max(1, 1.2 * root.sceneScale)
                border.color: Qt.rgba(1, 1, 1, 0.55)
                Rectangle {
                    x: 2 * root.sceneScale
                    y: 2 * root.sceneScale
                    height: parent.height - 4 * root.sceneScale
                    width: Math.max(1.5, (parent.width - 4 * root.sceneScale) * Math.max(0, Math.min(100, root.batteryPercent)) / 100)
                    radius: 1.8 * root.sceneScale
                    color: !root.charging && root.batteryPercent <= 15 ? root.errorColor : root.charging ? "#5fd38d" : root.foreground
                }
            }
            Rectangle {
                anchors.left: batteryShell.right
                anchors.leftMargin: 1 * root.sceneScale
                anchors.verticalCenter: parent.verticalCenter
                width: 1.5 * root.sceneScale
                height: 4.5 * root.sceneScale
                radius: 1
                color: Qt.rgba(1, 1, 1, 0.55)
            }
        }
        LockGlyph {
            anchors.verticalCenter: parent.verticalCenter
            width: 14 * root.sceneScale
            height: width
            visible: root.charging || !root.hasBattery
            name: "bolt"
            filled: true
            ink: root.foreground
        }
    }

    Row {
        id: powerRow
        objectName: "powerActions"
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 24 * root.sceneScale
        anchors.bottomMargin: 24 * root.sceneScale
        spacing: 10
        scale: root.sceneScale
        transformOrigin: Item.BottomRight
        visible: root.option("showPowerActions", true) && opacity > 0.001
        opacity: root.chromeOpacity * root.chromeFade
        layoutDirection: Qt.RightToLeft

        Repeater {
            model: [
                {action: "poweroff", glyph: "power", label: "Shut down", confirm: "Click again to shut down"},
                {action: "reboot", glyph: "restart", label: "Restart", confirm: "Click again to restart"},
                {action: "suspend", glyph: "sleep", label: "Sleep", confirm: "Click again to sleep"}
            ]
            LockAction {
                required property var modelData
                styleTokens: root.styleTokens
                glass: true
                glyph: modelData.glyph
                text: modelData.label
                armed: root.powerArmed === modelData.action
                enabled: (root.interactive || root.preview) && !root.unlocking
                onClicked: root.requestPower(modelData.action)
            }
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            height: 32
            width: powerConfirm.implicitWidth + 28
            radius: 16
            color: Qt.rgba(0, 0, 0, 0.32)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.12)
            opacity: root.powerArmed !== "" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity {
                NumberAnimation {
                    duration: 160
                }
            }
            Text {
                id: powerConfirm
                anchors.centerIn: parent
                text: root.powerArmed === "poweroff" ? "Click again to shut down" : root.powerArmed === "reboot" ? "Click again to restart" : root.powerArmed === "suspend" ? "Click again to sleep" : ""
                color: root.foreground
                font.family: root.textFont
                font.pixelSize: 13
                font.weight: Font.Medium
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 30 * root.sceneScale
        width: Math.min(parent.width - 360 * root.sceneScale, 720 * root.sceneScale)
        opacity: root.chromeOpacity * (0.85 - 0.35 * root.quietness)
        text: root.option("message", "")
        visible: text.length > 0
        textFormat: Text.PlainText
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        color: root.foreground
        font.family: root.textFont
        font.pixelSize: 14 * root.sceneScale
        font.weight: Font.Medium
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#000000"
            shadowOpacity: 0.3
            shadowBlur: 0.6
        }
    }
}
