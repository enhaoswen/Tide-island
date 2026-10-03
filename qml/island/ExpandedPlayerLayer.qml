import QtQuick
import IslandBackend
import Quickshell.Services.Mpris
import Quickshell.Widgets
import "../controlcenter"
import "../common/SpotifyTrack.js" as SpotifyTrack

Item {
    id: root

    signal controlPressed()
    signal backgroundClicked()
    signal closeRequested()
    signal keyboardFocusRequested()
    signal keyboardFocusReleased()
    signal previousRequested()
    signal timerToggleRequested(int hours, int minutes)
    signal timerResetRequested()
    signal timerDurationRequested(int hours, int minutes)

    readonly property var userConfig: UserConfig

    property bool showCondition: false
    property string currentArtUrl: ""
    property string currentTrack: ""
    property string currentArtist: ""
    property string timePlayed: "0:00"
    property string timeTotal: "0:00"
    property real trackProgress: 0
    property var activePlayer: null
    property var spotifyFavorites: null
    readonly property bool spotifyPlayer: SpotifyTrack.isSpotifyPlayer(activePlayer)
    readonly property string spotifyTrackUri: SpotifyTrack.currentUri(activePlayer)
    readonly property bool favoriteAvailable: spotifyFavorites && spotifyPlayer
        && spotifyTrackUri !== "" && spotifyFavorites.connected
        && spotifyFavorites.stateKnown && spotifyFavorites.trackUri === spotifyTrackUri
    readonly property bool favoriteLiked: favoriteAvailable && spotifyFavorites.liked
    readonly property bool favoriteBusy: spotifyFavorites && spotifyFavorites.busy
    property string iconFontFamily: userConfig.iconFontFamily
    property string textFontFamily: userConfig.textFontFamily
    property int timerSelectedHours: 0
    property int timerSelectedMinutes: 5
    property int timerTotalSeconds: 300
    property int timerRemainingSeconds: 0
    property bool timerRunning: false
    property bool timerActive: false
    property real visualizerPhase: 0
    property int currentPage: 0
    property int pendingPage: -1
    readonly property int pageCount: 2
    property real pageProgress: 0
    readonly property real clampedPageProgress: Math.max(0, Math.min(1, pageProgress))
    readonly property real pageSlideDistance: Math.max(1, viewport.width + 24)

    readonly property bool isPlaying: activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing

    function visualizerLevel(index) {
        const phase = visualizerPhase + index * 0.78;
        const primary = (Math.sin(phase) + 1) * 0.5;
        const secondary = (Math.sin(phase * 2 + index * 0.95) + 1) * 0.5;
        return 0.22 + primary * 0.42 + secondary * 0.24;
    }

    function pausedVisualizerLevel(index) {
        const levels = [0.34, 0.58, 0.82, 0.58, 0.34];
        return levels[index] || 0.4;
    }

    function togglePlayback() {
        if (!activePlayer || !activePlayer.canControl) return;

        if (activePlayer.canTogglePlaying) {
            activePlayer.togglePlaying();
            return;
        }

        if (activePlayer.playbackState === MprisPlaybackState.Playing) {
            if (activePlayer.canPause) activePlayer.pause();
            return;
        }

        if (activePlayer.canPlay) activePlayer.play();
    }

    function showPage(page) {
        settlePage(page);
    }

    function settlePage(page) {
        const targetPage = Math.max(0, Math.min(pageCount - 1, page));
        pendingPage = -1;
        pageSettleAnimation.stop();
        pageStrip.interactive = false;
        pendingPage = targetPage;
        pageSettleAnimation.startProgress = clampedPageProgress;
        pageSettleAnimation.endProgress = targetPage;

        if (Math.abs(clampedPageProgress - targetPage) < 0.001) {
            pageProgress = targetPage;
            finishPageSettle();
            return;
        }

        pageSettleAnimation.restart();
    }

    function finishPageSettle() {
        if (pendingPage < 0)
            return;

        currentPage = pendingPage;
        pendingPage = -1;
        pageProgress = currentPage;
        updateKeyboardFocusForPage();
    }

    function updateKeyboardFocusForPage() {
        if (showCondition)
            keyboardFocusRequested();
        else
            keyboardFocusReleased();
    }

    function grabKeyboardFocus() {
        root.focus = true;
        root.forceActiveFocus();
        if (currentPage === 1 && timerPage.grabKeyboardFocus)
            timerPage.grabKeyboardFocus();
    }

    function openTimerPage() {
        showPage(1);
    }

    anchors.fill: parent
    focus: showCondition
    opacity: showCondition ? 1 : 0

    Keys.onEscapePressed: event => {
        root.closeRequested();
        event.accepted = true;
    }

    onShowConditionChanged: {
        if (!showCondition) {
            pendingPage = -1;
            pageSettleAnimation.stop();
            currentPage = 0;
            pageProgress = 0;
        }
        updateKeyboardFocusForPage();
    }

    Behavior on opacity {
        NumberAnimation {
            duration: showCondition ? 300 : 100
            easing.type: Easing.InOutQuad
        }
    }

    SequentialAnimation {
        id: pageSettleAnimation

        property real startProgress: 0
        property real endProgress: 0

        NumberAnimation {
            target: root
            property: "pageProgress"
            from: pageSettleAnimation.startProgress
            to: pageSettleAnimation.endProgress
            duration: 220
            easing.type: Easing.OutCubic
        }

        ScriptAction {
            script: root.finishPageSettle()
        }
    }

    Timer {
        interval: 64
        repeat: true
        running: showCondition && isPlaying && currentPage === 0
        onTriggered: {
            visualizerPhase += 0.18;
            if (visualizerPhase > Math.PI * 2) visualizerPhase -= Math.PI * 2;
        }
    }

    Item {
        id: viewport

        anchors.fill: parent
        clip: true

        MouseArea {
            id: pageSwipeArea

            anchors.fill: parent
            z: 0
            acceptedButtons: Qt.LeftButton
            preventStealing: false

            property real startX: 0
            property int startPage: 0
            property real startProgress: 0
            property bool moved: false

            onPressed: (mouse) => {
                root.pendingPage = -1;
                pageSettleAnimation.stop();
                startX = mouse.x;
                startPage = root.currentPage;
                startProgress = root.clampedPageProgress;
                moved = false;
                pageStrip.interactive = true;
                root.pageProgress = startProgress;
                mouse.accepted = true;
            }

            onPositionChanged: (mouse) => {
                if (!pressed || viewport.width <= 0)
                    return;

                const deltaX = mouse.x - startX;
                root.pageProgress = Math.max(0, Math.min(1, startProgress + deltaX / root.pageSlideDistance));
                moved = moved || Math.abs(deltaX) > 8;
            }

            onReleased: {
                if (!moved || viewport.width <= 0) {
                    root.settlePage(startPage);
                    return;
                }

                const progress = root.clampedPageProgress;
                let targetPage = startPage;

                if (startPage === 0 && progress > 0.22)
                    targetPage = 1;
                else if (startPage === 1 && progress < 0.78)
                    targetPage = 0;

                root.settlePage(targetPage);
            }

            onCanceled: root.settlePage(startPage)
            onClicked: if (!moved) root.backgroundClicked()
        }

        Item {
            id: pageStrip

            z: 1
            property bool interactive: false

            width: viewport.width
            height: viewport.height
            x: 0

            onWidthChanged: {
                if (!interactive && !pageSettleAnimation.running)
                    root.pageProgress = root.currentPage;
            }

            Item {
                id: musicPage

                width: viewport.width
                height: viewport.height
                x: root.clampedPageProgress * root.pageSlideDistance
                opacity: 1 - root.clampedPageProgress
                enabled: opacity > 0.001

                Column {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 10

                    Item {
                        width: parent.width
                        height: 60

                        Row {
                            id: trackHeader
                            anchors.left: parent.left
                            anchors.right: trackVisualizer.left
                            anchors.rightMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 16

                            ClippingRectangle {
                                width: 60
                                height: 60
                                radius: 10
                                color: "#2c2c2e"
                                antialiasing: true

                                Image {
                                    anchors.fill: parent
                                    source: currentArtUrl
                                    fillMode: Image.PreserveAspectCrop
                                    visible: source.toString() !== ""
                                    sourceSize: Qt.size(120, 120)
                                    smooth: true
                                }
                            }

                            Column {
                                width: Math.max(0, trackHeader.width - 60 - trackHeader.spacing)
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4

                                Text {
                                    text: currentTrack
                                    color: "white"
                                    font.pixelSize: userConfig.bodyFontSize
                                    font.family: textFontFamily
                                    font.weight: Font.DemiBold
                                    font.letterSpacing: -0.15
                                    width: parent.width
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: currentArtist
                                    color: "#8e8e93"
                                    font.pixelSize: userConfig.bodyFontSize - 2
                                    font.family: textFontFamily
                                    font.weight: Font.Medium
                                    width: parent.width
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        Item {
                            id: trackVisualizer
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 32
                            height: 22

                            Row {
                                anchors.centerIn: parent
                                height: parent.height
                                spacing: 3

                                Repeater {
                                    model: 5

                                    delegate: Rectangle {
                                        width: 3
                                        height: isPlaying
                                            ? 6 + (parent.height - 6) * visualizerLevel(index)
                                            : 6 + (parent.height - 6) * pausedVisualizerLevel(index)
                                        radius: 2
                                        color: isPlaying ? "#b56cff" : "#5f4b72"
                                        anchors.verticalCenter: parent.verticalCenter

                                        Behavior on height {
                                            NumberAnimation {
                                                duration: isPlaying ? 120 : 260
                                                easing.type: Easing.InOutQuad
                                            }
                                        }

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: isPlaying ? 140 : 280
                                                easing.type: Easing.InOutQuad
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: 16

                        Text {
                            id: timeL
                            anchors.left: parent.left
                            text: timePlayed
                            color: "#8e8e93"
                            font.pixelSize: userConfig.bodyFontSize - 4
                            font.family: textFontFamily
                            font.weight: Font.Medium
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: timeL.right
                            anchors.right: timeR.left
                            anchors.margins: 12
                            height: 6
                            radius: 3
                            color: "#333333"

                            Rectangle {
                                height: parent.height
                                radius: 3
                                color: "white"
                                width: parent.width * trackProgress

                                Behavior on width {
                                    NumberAnimation {
                                        duration: 500
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                        }

                        Text {
                            id: timeR
                            anchors.right: parent.right
                            text: timeTotal
                            color: "#8e8e93"
                            font.pixelSize: userConfig.bodyFontSize - 4
                            font.family: textFontFamily
                            font.weight: Font.Medium
                        }
                    }

                    Item {
                        id: playbackControls
                        width: parent.width
                        height: 36

                        // Reference layout: transport buttons shifted slightly left,
                        // with the heart occupying the fourth evenly spaced position.
                        Item {
                            x: parent.width * 0.9175 - width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            width: 32
                            height: 32
                            visible: root.spotifyPlayer
                            opacity: root.favoriteAvailable && !root.favoriteBusy ? 1 : 0.45
                            scale: favoriteArea.pressed && root.favoriteAvailable && !root.favoriteBusy ? 0.9 : 1

                            Behavior on scale { NumberAnimation { duration: 100 } }

                            FavoriteHeart {
                                anchors.centerIn: parent
                                width: 24
                                height: 24
                                active: root.favoriteLiked
                                animateChanges: root.favoriteAvailable
                                stateKey: root.spotifyTrackUri
                            }

                            MouseArea {
                                id: favoriteArea
                                anchors.fill: parent
                                hoverEnabled: true
                                preventStealing: true
                                cursorShape: root.favoriteAvailable && !root.favoriteBusy ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onPressed: mouse => {
                                    root.controlPressed();
                                    mouse.accepted = true;
                                }
                                onClicked: {
                                    if (root.favoriteAvailable && !root.favoriteBusy)
                                        root.spotifyFavorites.setFavorite(root.spotifyTrackUri, !root.favoriteLiked);
                                }
                            }
                        }

                        Row {
                            x: parent.width * 0.4675 - width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Math.max(12, parent.width * 0.225 - 28)

                            Item {
                                width: 28
                                height: 28
                                scale: prevArea.pressed ? 0.8 : 1.0

                                Behavior on scale {
                                    NumberAnimation { duration: 100 }
                                }

                                Canvas {
                                    anchors.fill: parent
                                    property color fillColor: prevArea.pressed ? "#888" : "white"

                                    onFillColorChanged: requestPaint()
                                    onPaint: {
                                        var ctx = getContext("2d");
                                        ctx.clearRect(0, 0, width, height);
                                        ctx.fillStyle = fillColor;
                                        ctx.strokeStyle = fillColor;
                                        ctx.lineJoin = "round";
                                        ctx.lineWidth = 2;
                                        ctx.beginPath();
                                        ctx.moveTo(13, 5);
                                        ctx.lineTo(1, 14);
                                        ctx.lineTo(13, 23);
                                        ctx.closePath();
                                        ctx.moveTo(26, 5);
                                        ctx.lineTo(14, 14);
                                        ctx.lineTo(26, 23);
                                        ctx.closePath();
                                        ctx.fill();
                                        ctx.stroke();
                                    }
                                }

                                MouseArea {
                                    id: prevArea
                                    anchors.fill: parent
                                    anchors.margins: -15
                                    preventStealing: true
                                    onPressed: (mouse) => {
                                        controlPressed();
                                        mouse.accepted = true;
                                    }
                                    onClicked: root.previousRequested()
                                }
                            }

                            Item {
                                width: 28
                                height: 28
                                scale: playArea.pressed ? 0.8 : 1.0

                                Behavior on scale {
                                    NumberAnimation { duration: 100 }
                                }

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    visible: activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing

                                    Rectangle { width: 6; height: 24; radius: 1; color: playArea.pressed ? "#888" : "white" }
                                    Rectangle { width: 6; height: 24; radius: 1; color: playArea.pressed ? "#888" : "white" }
                                }

                                Canvas {
                                    anchors.fill: parent
                                    visible: !activePlayer || activePlayer.playbackState !== MprisPlaybackState.Playing
                                    property color fillColor: playArea.pressed ? "#888" : "white"

                                    onFillColorChanged: requestPaint()
                                    onPaint: {
                                        var ctx = getContext("2d");
                                        ctx.clearRect(0, 0, width, height);
                                        ctx.fillStyle = fillColor;
                                        ctx.strokeStyle = fillColor;
                                        ctx.lineJoin = "round";
                                        ctx.lineWidth = 2;
                                        ctx.beginPath();
                                        ctx.moveTo(8, 4);
                                        ctx.lineTo(24, 14);
                                        ctx.lineTo(8, 24);
                                        ctx.closePath();
                                        ctx.fill();
                                        ctx.stroke();
                                    }
                                }

                                MouseArea {
                                    id: playArea
                                    anchors.fill: parent
                                    anchors.margins: -15
                                    preventStealing: true
                                    onPressed: (mouse) => {
                                        controlPressed();
                                        mouse.accepted = true;
                                    }
                                    onClicked: togglePlayback()
                                }
                            }

                            Item {
                                width: 28
                                height: 28
                                scale: nextArea.pressed ? 0.8 : 1.0

                                Behavior on scale {
                                    NumberAnimation { duration: 100 }
                                }

                                Canvas {
                                    anchors.fill: parent
                                    property color fillColor: nextArea.pressed ? "#888" : "white"

                                    onFillColorChanged: requestPaint()
                                    onPaint: {
                                        var ctx = getContext("2d");
                                        ctx.clearRect(0, 0, width, height);
                                        ctx.fillStyle = fillColor;
                                        ctx.strokeStyle = fillColor;
                                        ctx.lineJoin = "round";
                                        ctx.lineWidth = 2;
                                        ctx.beginPath();
                                        ctx.moveTo(2, 5);
                                        ctx.lineTo(14, 14);
                                        ctx.lineTo(2, 23);
                                        ctx.closePath();
                                        ctx.moveTo(15, 5);
                                        ctx.lineTo(27, 14);
                                        ctx.lineTo(15, 23);
                                        ctx.closePath();
                                        ctx.fill();
                                        ctx.stroke();
                                    }
                                }

                                MouseArea {
                                    id: nextArea
                                    anchors.fill: parent
                                    anchors.margins: -15
                                    preventStealing: true
                                    onPressed: (mouse) => {
                                        controlPressed();
                                        mouse.accepted = true;
                                    }
                                    onClicked: if (activePlayer) activePlayer.next()
                                }
                            }
                        }
                    }
                }
            }

            TimerPage {
                id: timerPage

                x: -(1 - root.clampedPageProgress) * root.pageSlideDistance
                width: viewport.width
                height: viewport.height
                opacity: root.clampedPageProgress
                enabled: opacity > 0.001
                textFontFamily: root.textFontFamily
                timerSelectedHours: root.timerSelectedHours
                timerSelectedMinutes: root.timerSelectedMinutes
                timerTotalSeconds: root.timerTotalSeconds
                timerRemainingSeconds: root.timerRemainingSeconds
                timerRunning: root.timerRunning
                timerActive: root.timerActive
                onControlPressed: root.controlPressed()
                onKeyboardFocusRequested: root.keyboardFocusRequested()
                onTimerToggleRequested: function(hours, minutes) {
                    root.timerToggleRequested(hours, minutes);
                }
                onTimerResetRequested: root.timerResetRequested()
                onTimerDurationRequested: function(hours, minutes) {
                    root.timerDurationRequested(hours, minutes);
                }
            }
        }
    }

    component TimerPage: Item {
        id: timerRoot

        signal controlPressed()
        signal keyboardFocusRequested()
        signal timerToggleRequested(int hours, int minutes)
        signal timerResetRequested()
        signal timerDurationRequested(int hours, int minutes)

        readonly property var userConfig: UserConfig

        property string textFontFamily: userConfig.textFontFamily
        property int timerSelectedHours: 0
        property int timerSelectedMinutes: 5
        property int timerTotalSeconds: 300
        property int timerRemainingSeconds: 0
        property bool timerRunning: false
        property bool timerActive: false
        property real animatedProgress: 0
        property string focusTarget: "hour"

        readonly property int displaySeconds: timerActive ? timerRemainingSeconds : 0
        readonly property real targetProgress: timerActive && timerTotalSeconds > 0 ? timerRemainingSeconds / timerTotalSeconds : 0
        readonly property bool canStart: inputTotalSeconds() > 0 && (!timerActive || timerRemainingSeconds > 0)
        readonly property string timeText: {
            const hours = Math.floor(displaySeconds / 3600);
            const minutes = Math.floor((displaySeconds % 3600) / 60);
            const seconds = displaySeconds % 60;
            const minuteText = minutes < 10 ? "0" + minutes : "" + minutes;
            const secondText = seconds < 10 ? "0" + seconds : "" + seconds;

            if (hours > 0)
                return hours + ":" + minuteText + ":" + secondText;
            return minuteText + ":" + secondText;
        }

        function clampInt(value, minValue, maxValue) {
            const parsed = parseInt(value, 10);
            if (isNaN(parsed)) return minValue;
            return Math.max(minValue, Math.min(maxValue, parsed));
        }

        function inputHours() {
            return clampInt(hourInput.text, 0, 23);
        }

        function inputMinutes() {
            return clampInt(minuteInput.text, 0, 59);
        }

        function inputTotalSeconds() {
            return inputHours() * 3600 + inputMinutes() * 60;
        }

        function syncDurationFromInputs() {
            timerDurationRequested(inputHours(), inputMinutes());
            progressRing.requestPaint();
        }

        function normalizeInputs() {
            hourInput.text = "" + timerSelectedHours;
            minuteInput.text = timerSelectedMinutes < 10 ? "0" + timerSelectedMinutes : "" + timerSelectedMinutes;
        }

        function resetTimer() {
            timerResetRequested();
            progressRing.requestPaint();
        }

        function toggleTimer() {
            timerToggleRequested(inputHours(), inputMinutes());
        }

        function grabKeyboardFocus() {
            if (focusTarget === "minute")
                minuteInput.grabKeyboardFocus();
            else
                hourInput.grabKeyboardFocus();
        }

        onTargetProgressChanged: animatedProgress = targetProgress
        onAnimatedProgressChanged: progressRing.requestPaint()
        onTimerSelectedHoursChanged: normalizeInputs()
        onTimerSelectedMinutesChanged: normalizeInputs()
        Component.onCompleted: normalizeInputs()

        Behavior on animatedProgress {
            NumberAnimation {
                duration: 700
                easing.type: Easing.InOutCubic
            }
        }

        Row {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 18

            Item {
                width: 116
                height: parent.height

                Canvas {
                    id: progressRing

                    anchors.centerIn: parent
                    width: 104
                    height: 104

                    onPaint: {
                        const ctx = getContext("2d");
                        const centerX = width / 2;
                        const centerY = height / 2;
                        const lineWidth = 5;
                        const radius = Math.min(width, height) / 2 - lineWidth / 2;
                        const startAngle = -Math.PI / 2;
                        const progress = Math.max(0, Math.min(1, timerRoot.animatedProgress));
                        const endAngle = startAngle - Math.PI * 2 * progress;

                        ctx.clearRect(0, 0, width, height);
                        ctx.lineCap = "round";
                        ctx.lineWidth = lineWidth;

                        ctx.beginPath();
                        ctx.strokeStyle = "#2b2e35";
                        ctx.arc(centerX, centerY, radius, 0, Math.PI * 2);
                        ctx.stroke();

                        if (progress > 0) {
                            ctx.beginPath();
                            ctx.strokeStyle = "#ff9f0a";
                            ctx.arc(centerX, centerY, radius, startAngle, endAngle, true);
                            ctx.stroke();
                        }
                    }
                }

                Text {
                    anchors.centerIn: progressRing
                    text: timerRoot.timeText
                    color: "#ffffff"
                    font.pixelSize: timerRoot.displaySeconds >= 3600 ? timerRoot.userConfig.bodyFontSize + 2 : timerRoot.userConfig.bodyFontSize + 8
                    font.family: timerRoot.textFontFamily
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Column {
                width: parent.width - 173
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Row {
                    width: parent.width
                    height: 42
                    spacing: 8

                    TimerInput {
                        id: hourInput

                        width: (parent.width - 8) / 2
                        height: parent.height
                        label: "时"
                        text: "0"
                        textFontFamily: timerRoot.textFontFamily
                        onKeyboardFocusRequested: {
                            timerRoot.focusTarget = "hour";
                            timerRoot.keyboardFocusRequested();
                        }
                        onEditingFinished: {
                            timerRoot.syncDurationFromInputs();
                            timerRoot.normalizeInputs();
                        }
                    }

                    TimerInput {
                        id: minuteInput

                        width: (parent.width - 8) / 2
                        height: parent.height
                        label: "分"
                        text: "05"
                        textFontFamily: timerRoot.textFontFamily
                        onKeyboardFocusRequested: {
                            timerRoot.focusTarget = "minute";
                            timerRoot.keyboardFocusRequested();
                        }
                        onEditingFinished: {
                            timerRoot.syncDurationFromInputs();
                            timerRoot.normalizeInputs();
                        }
                    }
                }

                Row {
                    width: parent.width
                    height: 34
                    spacing: 8

                    TimerButton {
                        width: (parent.width - 8) / 2
                        height: parent.height
                        label: timerRoot.timerRunning ? "Stop" : (timerRoot.timerActive && timerRoot.timerRemainingSeconds < timerRoot.timerTotalSeconds && timerRoot.timerRemainingSeconds > 0 ? "Continue" : "Start")
                        enabled: timerRoot.timerRunning || timerRoot.canStart
                        accent: true
                        textFontFamily: timerRoot.textFontFamily
                        onClicked: timerRoot.toggleTimer()
                        onPressed: timerRoot.controlPressed()
                    }

                    TimerButton {
                        width: (parent.width - 8) / 2
                        height: parent.height
                        label: "Reset"
                        textFontFamily: timerRoot.textFontFamily
                        onClicked: timerRoot.resetTimer()
                        onPressed: timerRoot.controlPressed()
                    }
                }
            }
        }
    }

    component TimerInput: Item {
        id: inputRoot

        signal editingFinished()
        signal keyboardFocusRequested()

        property alias text: input.text
        property string label: ""
        property string textFontFamily: ""
        property int focusAttempts: 0

        function grabKeyboardFocus() {
            inputRoot.keyboardFocusRequested();
            focusAttempts = 4;
            input.forceActiveFocus();
            input.selectAll();
            focusRetryTimer.restart();
        }

        Timer {
            id: focusRetryTimer

            interval: 16
            repeat: true
            onTriggered: {
                input.forceActiveFocus();
                input.selectAll();
                inputRoot.focusAttempts -= 1;
                if (inputRoot.focusAttempts <= 0)
                    stop();
            }
        }

        Item {
            anchors.fill: parent

            MatteSurface {
                anchors.fill: parent
                radius: 10
                hovered: input.activeFocus || inputMouseArea.containsMouse
                pressed: inputMouseArea.pressed
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: 9
                color: StyleTokens.transparent
                border.width: 1
                border.color: input.activeFocus ? "#ff9f0a" : "#2b2e35"
            }

            MouseArea {
                id: inputMouseArea

                anchors.fill: parent
                z: 2
                acceptedButtons: Qt.LeftButton
                hoverEnabled: true
                preventStealing: true
                onPressed: (mouse) => {
                    inputRoot.grabKeyboardFocus();
                    mouse.accepted = true;
                }
                onClicked: (mouse) => {
                    mouse.accepted = true;
                }
            }

            Row {
                z: 1
                anchors.centerIn: parent
                spacing: 4

                TextInput {
                    id: input

                    width: 42
                    property bool sanitizing: false
                    color: "#f5f5f7"
                    selectionColor: "#ff9f0a"
                    selectedTextColor: "#111111"
                    font.pixelSize: UserConfig.bodyFontSize + 2
                    font.family: inputRoot.textFontFamily
                    font.weight: Font.DemiBold
                    horizontalAlignment: TextInput.AlignRight
                    validator: IntValidator {
                        bottom: 0
                        top: 99
                    }
                    inputMethodHints: Qt.ImhDigitsOnly
                    cursorVisible: activeFocus
                    onActiveFocusChanged: if (activeFocus) inputRoot.keyboardFocusRequested()
                    onTextChanged: {
                        if (sanitizing)
                            return;

                        const digits = text.replace(/[^0-9]/g, "").slice(0, 2);
                        if (digits !== text) {
                            sanitizing = true;
                            text = digits;
                            sanitizing = false;
                        }
                    }
                    onEditingFinished: inputRoot.editingFinished()
                    Keys.onReturnPressed: inputRoot.editingFinished()
                    Keys.onEnterPressed: inputRoot.editingFinished()
                }

                Text {
                    text: inputRoot.label
                    color: "#9b9da4"
                    font.pixelSize: UserConfig.bodyFontSize - 3
                    font.family: inputRoot.textFontFamily
                    font.weight: Font.Medium
                }
            }
        }
    }

    component TimerButton: Item {
        id: buttonRoot

        signal pressed()
        signal clicked()

        property string label: ""
        property bool accent: false
        property string textFontFamily: ""

        opacity: enabled ? 1.0 : 0.45
        scale: buttonArea.pressed ? 0.96 : 1.0

        Behavior on scale {
            NumberAnimation {
                duration: 90
                easing.type: Easing.OutCubic
            }
        }

        Item {
            anchors.fill: parent

            MatteSurface {
                anchors.fill: parent
                radius: 10
                hovered: buttonArea.containsMouse
                pressed: buttonArea.pressed
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: 9
                color: buttonRoot.accent
                    ? (buttonArea.pressed ? "#d98500" : "#ff9f0a")
                    : StyleTokens.transparent
                border.width: 1
                border.color: buttonRoot.accent ? "#ff9f0a" : "#2b2e35"
            }
        }

        Text {
            anchors.centerIn: parent
            text: buttonRoot.label
            color: buttonRoot.accent ? "#111111" : "#f5f5f7"
            font.pixelSize: UserConfig.bodyFontSize - 2
            font.family: buttonRoot.textFontFamily
            font.weight: Font.DemiBold
        }

        MouseArea {
            id: buttonArea

            anchors.fill: parent
            enabled: buttonRoot.enabled
            hoverEnabled: true
            preventStealing: true
            onPressed: (mouse) => {
                buttonRoot.pressed();
                mouse.accepted = true;
            }
            onClicked: buttonRoot.clicked()
        }
    }
}
