import QtQuick
import IslandBackend
import Quickshell.Services.Mpris

Item {
    id: root

    signal controlPressed()
    signal backgroundClicked()
    signal keyboardFocusRequested()
    signal keyboardFocusReleased()
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
        if (showCondition && currentPage === 1)
            keyboardFocusRequested();
        else
            keyboardFocusReleased();
    }

    function grabKeyboardFocus() {
        if (currentPage === 1 && timerPage.grabKeyboardFocus)
            timerPage.grabKeyboardFocus();
    }

    function openTimerPage() {
        showPage(1);
    }

    anchors.fill: parent
    opacity: showCondition ? 1 : 0

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
                    spacing: 14

                    Item {
                        width: parent.width
                        height: 60

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 16

                            Rectangle {
                                width: 60
                                height: 60
                                radius: 14
                                color: "#2c2c2e"
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    source: currentArtUrl
                                    fillMode: Image.PreserveAspectCrop
                                    visible: source.toString() !== ""
                                    sourceSize: Qt.size(120, 120)
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4

                                Text {
                                    text: currentTrack
                                    color: "white"
                                    font.pixelSize: userConfig.bodyFontSize
                                    font.family: textFontFamily
                                    font.weight: Font.DemiBold
                                    font.letterSpacing: -0.15
                                    width: 180
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: currentArtist
                                    color: "#8e8e93"
                                    font.pixelSize: userConfig.bodyFontSize - 2
                                    font.family: textFontFamily
                                    font.weight: Font.Medium
                                    width: 200
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        Item {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 44
                            height: 22

                            Row {
                                anchors.centerIn: parent
                                height: parent.height
                                spacing: 4

                                Repeater {
                                    model: 5

                                    delegate: Rectangle {
                                        width: 4
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
                        width: parent.width
                        height: 36

                        Row {
                            anchors.centerIn: parent
                            spacing: 50

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
                                        ctx.rect(3, 5, 3, 18);
                                        ctx.moveTo(14, 5);
                                        ctx.lineTo(6, 14);
                                        ctx.lineTo(14, 23);
                                        ctx.closePath();
                                        ctx.moveTo(23, 5);
                                        ctx.lineTo(15, 14);
                                        ctx.lineTo(23, 23);
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
                                    onClicked: if (activePlayer) activePlayer.previous()
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

                                    Rectangle { width: 6; height: 20; radius: 2; color: playArea.pressed ? "#888" : "white" }
                                    Rectangle { width: 6; height: 20; radius: 2; color: playArea.pressed ? "#888" : "white" }
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
                                        ctx.moveTo(5, 5);
                                        ctx.lineTo(13, 14);
                                        ctx.lineTo(5, 23);
                                        ctx.closePath();
                                        ctx.moveTo(14, 5);
                                        ctx.lineTo(22, 14);
                                        ctx.lineTo(14, 23);
                                        ctx.closePath();
                                        ctx.rect(22, 5, 3, 18);
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
                        ctx.strokeStyle = "#303036";
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
                width: parent.width - 134
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
                        label: timerRoot.timerRunning ? "停止" : (timerRoot.timerActive && timerRoot.timerRemainingSeconds < timerRoot.timerTotalSeconds && timerRoot.timerRemainingSeconds > 0 ? "继续" : "开始")
                        enabled: timerRoot.timerRunning || timerRoot.canStart
                        accent: true
                        textFontFamily: timerRoot.textFontFamily
                        onClicked: timerRoot.toggleTimer()
                        onPressed: timerRoot.controlPressed()
                    }

                    TimerButton {
                        width: (parent.width - 8) / 2
                        height: parent.height
                        label: "重置"
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

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: input.activeFocus ? "#242428" : "#1c1c1f"
            border.width: 1
            border.color: input.activeFocus ? "#ff9f0a" : "#34343a"

            Behavior on color {
                ColorAnimation {
                    duration: 140
                    easing.type: Easing.InOutQuad
                }
            }

            MouseArea {
                anchors.fill: parent
                z: 2
                acceptedButtons: Qt.LeftButton
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
                    color: "#ffffff"
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
                    color: "#8e8e93"
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

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: buttonRoot.accent ? (buttonArea.pressed ? "#d98500" : "#ff9f0a") : (buttonArea.pressed ? "#34343a" : "#242428")
        }

        Text {
            anchors.centerIn: parent
            text: buttonRoot.label
            color: buttonRoot.accent ? "#111111" : "#ffffff"
            font.pixelSize: UserConfig.bodyFontSize - 2
            font.family: buttonRoot.textFontFamily
            font.weight: Font.DemiBold
        }

        MouseArea {
            id: buttonArea

            anchors.fill: parent
            enabled: buttonRoot.enabled
            preventStealing: true
            onPressed: (mouse) => {
                buttonRoot.pressed();
                mouse.accepted = true;
            }
            onClicked: buttonRoot.clicked()
        }
    }
}
