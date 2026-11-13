import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Effects
import TideIsland 1.0

PagePanel {
    id: root
    objectName: "lockScreenSettings"
    property var values: backend.lockScreenSettings()

    function update(key, value) {
        const next = Object.assign({}, values);
        next[key] = value;
        values = next;
        ConfigStore.setValue("lockScreen", next);
        saveTimer.restart();
    }
    function flush() {
        if (saveTimer.running) {
            saveTimer.stop();
            ConfigStore.save();
        }
    }
    function savePosition(key, x, y) {
        const positions = Object.assign({}, values.positions);
        positions[key] = {
            x: x,
            y: y
        };
        update("positions", positions);
    }
    function saveCoordinate(key, axis, value) {
        const point = preview.widgetPosition(key);
        const coordinate = Math.max(0, Math.min(100, value)) / 100;
        savePosition(key, axis === "x" ? coordinate : point.x, axis === "y" ? coordinate : point.y);
    }
    function resetPosition(key) {
        const positions = Object.assign({}, values.positions);
        delete positions[key];
        update("positions", positions);
    }
    onVisibleChanged: if (!visible)
        flush()
    Component.onDestruction: flush()
    Timer {
        id: saveTimer
        interval: 200
        onTriggered: ConfigStore.save()
    }
    Timer {
        interval: 1000
        running: root.visible
        repeat: true
        onTriggered: preview.now = new Date()
    }
    LockScreenTransition {
        id: previewTransition
        active: root.visible && !root.values.customLayoutEnabled
        onExitFinished: enter()
    }

    FileDialog {
        id: imageDialog
        property string settingKey: "wallpaperPath"
        title: settingKey === "avatarPath" ? "Choose an avatar" : "Choose a lock screen wallpaper"
        nameFilters: ["Images (*.png *.jpg *.jpeg *.webp *.bmp)"]
        onAccepted: root.update(settingKey, selectedFile.toString())
    }

    Flickable {
        id: scroller
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: content.implicitHeight + 100
        boundsBehavior: Flickable.StopAtBounds
        boundsMovement: Flickable.StopAtBounds
        interactive: false

        WheelHandler {
            target: null
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

            onWheel: function (event) {
                const rawDelta = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y / 120 * 80;
                const maxY = Math.max(0, scroller.contentHeight - scroller.height);
                scroller.contentY = Math.max(0, Math.min(maxY, scroller.contentY - rawDelta));
                event.accepted = true;
            }
        }

        Column {
            id: content
            x: 30
            y: 50
            width: scroller.width - 70
            spacing: 34

            Item {
                width: parent.width
                height: pageTitle.implicitHeight
                Text {
                    id: pageTitle
                    x: 30
                    text: "Lock screen"
                    color: Theme.textColor
                    font.family: Theme.titleFontFamily
                    font.pixelSize: 30
                }
                SettingButton {
                    anchors.right: parent.right
                    width: 114
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Lock now"
                    primary: true
                    font.family: Theme.textFontFamily
                    onClicked: {
                        root.flush();
                        backend.lockScreen();
                    }
                }
            }

            Section {
                title: "Layout"
                width: parent.width
                ToggleRow {
                    title: "Custom positions"
                    hint: "Drag cards in the preview or enter their positions below. Changes save automatically."
                    settingKey: "customLayoutEnabled"
                }

                SplitLine {
                    width: parent.width
                }

                Rectangle {
                    id: previewFrame
                    width: parent.width
                    height: width * 0.59
                    radius: 12
                    color: Theme.componentBgColor
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: previewMask
                    }
                    Rectangle {
                        id: previewMask
                        anchors.fill: parent
                        radius: 12
                        visible: false
                        layer.enabled: true
                    }
                    // The exact production view, scaled down. All example data is preview-only.
                    LockScreenView {
                        id: preview
                        objectName: "lockScreenPreview"
                        width: 1440
                        height: 850
                        scale: parent.width / 1440
                        transformOrigin: Item.TopLeft
                        settings: root.values
                        styleTokens: StyleTokens
                        preview: true
                        interactive: false
                        layoutEditing: root.values.customLayoutEnabled
                        editingUiScale: width / previewFrame.width / Math.max(0.1, sceneScale)
                        entrance: layoutEditing ? 1 : previewTransition.entrance
                        departure: layoutEditing ? 0 : previewTransition.departure
                        unlocking: !layoutEditing && previewTransition.exiting
                        onPositionEdited: (key, x, y) => root.savePosition(key, x, y)
                        userName: "Your name"
                        wallpaperPath: String(ConfigStore.value("wallpaperPath", ""))
                        textFont: String(ConfigStore.value("textFontFamily", "Sans Serif"))
                        timeFont: String(ConfigStore.value("timeFontFamily", "Sans Serif"))
                        trackTitle: "Midnight City"
                        trackArtist: "M83"
                        playing: true
                        canPlay: true
                        canPrevious: true
                        canNext: true
                        canFavorite: true
                        favorite: true
                        progress: 0.38
                        elapsed: "1:24"
                        duration: "3:42"
                        weatherReady: true
                        temperature: "23°"
                        weatherCondition: "Partly cloudy"
                        weatherLocation: "Local weather"
                        weatherRange: "26° / 19°"
                        weatherType: "partly_cloudy"
                        feelsLike: "24°"
                        humidity: "64%"
                        hasBattery: true
                        batteryPercent: 86
                    }
                }

                Item {
                    width: parent.width
                    height: Math.max(49, previewHint.implicitHeight, previewActions.implicitHeight)

                    Text {
                        id: previewHint
                        anchors.left: parent.left
                        anchors.right: previewActions.left
                        anchors.rightMargin: 28
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Music and weather use example data."
                        wrapMode: Text.Wrap
                        color: Theme.subtleTextColor
                        font.family: Theme.textFontFamily
                        font.pixelSize: 14
                    }

                    Row {
                        id: previewActions
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        SettingButton {
                            text: "Reset positions"
                            enabled: Object.keys(root.values.positions).length > 0
                            onClicked: root.update("positions", {})
                        }
                        SettingButton {
                            text: "Replay"
                            enabled: !root.values.customLayoutEnabled && !previewTransition.exiting
                            onClicked: previewTransition.beginExit()
                        }
                    }
                }
            }

            Section {
                title: "Widget positions"
                width: parent.width
                visible: root.values.customLayoutEnabled

                Text {
                    width: parent.width
                    text: "X and Y set each card's center as a percentage of the screen. Cards stay within the screen edges."
                    wrapMode: Text.Wrap
                    color: Theme.subtleTextColor
                    font.family: Theme.textFontFamily
                    font.pixelSize: 14
                }

                Repeater {
                    model: [
                        {key: "profile", label: "User information"},
                        {key: "clock", label: "Time and date"},
                        {key: "password", label: "Password"},
                        {key: "weather", label: "Weather"},
                        {key: "music", label: "Music player"}
                    ]

                    PositionRow {
                        required property var modelData
                        title: modelData.label
                        widgetKey: modelData.key
                    }
                }
            }

            Section {
                title: "Appearance"
                width: parent.width

                SettingRow {
                    title: "Wallpaper"
                    hint: root.values.wallpaperPath || "Use the wallpaper selected in Tide Island"
                    elideHint: true
                    SettingButton {
                        text: "Choose image"
                        onClicked: {
                            imageDialog.settingKey = "wallpaperPath";
                            imageDialog.open();
                        }
                    }
                    SettingButton {
                        text: "Reset"
                        enabled: root.values.wallpaperPath !== ""
                        onClicked: root.update("wallpaperPath", "")
                    }
                }

                SplitLine {
                    width: parent.width
                }

                NumberRow {
                    title: "Background blur"
                    hint: "Blur the lock screen wallpaper (0–100%)"
                    settingKey: "blur"
                }

                SplitLine {
                    width: parent.width
                }

                NumberRow {
                    title: "Background dimming"
                    hint: "Darken the wallpaper behind the time and controls (0–100%)"
                    settingKey: "dim"
                }

                SplitLine {
                    width: parent.width
                }

                ToggleRow {
                    title: "Dim when idle"
                    hint: "After a few seconds without input, leave only the time on screen"
                    settingKey: "idleDim"
                }

                SplitLine {
                    width: parent.width
                }

                NumberRow {
                    title: "Glass opacity"
                    hint: "Opacity of the music player and password field (0–100%)"
                    settingKey: "cardOpacity"
                }

                SplitLine {
                    width: parent.width
                }

                NumberRow {
                    title: "Corner radius"
                    hint: "Corner radius of the music player (12–40 px)"
                    settingKey: "radius"
                    minimum: 12
                    maximum: 40
                }
            }

            Section {
                title: "User information"
                width: parent.width
                ToggleRow {
                    title: "Avatar"
                    hint: "Show your profile image on the lock screen"
                    settingKey: "showAvatar"
                }

                SplitLine {
                    width: parent.width
                    visible: root.values.showAvatar
                }

                SettingRow {
                    title: "Avatar image"
                    hint: root.values.avatarPath || "Use your system profile image"
                    elideHint: true
                    visible: root.values.showAvatar
                    SettingButton {
                        text: "Choose avatar"
                        onClicked: {
                            imageDialog.settingKey = "avatarPath";
                            imageDialog.open();
                        }
                    }
                    SettingButton {
                        text: "Reset"
                        enabled: root.values.avatarPath !== ""
                        onClicked: root.update("avatarPath", "")
                    }
                }

                SplitLine {
                    width: parent.width
                }

                ToggleRow {
                    title: "Display name"
                    hint: "Show your name on the lock screen"
                    settingKey: "showName"
                }

                SplitLine {
                    width: parent.width
                    visible: root.values.showName
                }

                TextRow {
                    title: "Name"
                    hint: "Leave empty to use your system username"
                    settingKey: "displayName"
                    placeholderText: "System username"
                    maximumLength: 80
                    visible: root.values.showName
                }

                SplitLine {
                    width: parent.width
                }

                TextRow {
                    title: "Lock screen message"
                    hint: "A short line shown at the bottom of the screen"
                    settingKey: "message"
                    placeholderText: "Leave empty to hide"
                    maximumLength: 180
                }
            }

            Section {
                title: "Time and date"
                width: parent.width
                ToggleRow {
                    title: "Clock"
                    hint: "Display the current time on the lock screen"
                    settingKey: "showClock"
                }

                SplitLine {
                    width: parent.width
                }

                ToggleRow {
                    title: "Date & weekday"
                    hint: "Display the current date and day of the week"
                    settingKey: "showDate"
                }

                SplitLine {
                    width: parent.width
                }

                ToggleRow {
                    title: "24-hour time"
                    hint: "Use 24-hour time instead of AM / PM"
                    settingKey: "use24Hour"
                }

                SplitLine {
                    width: parent.width
                }

                ToggleRow {
                    title: "Show seconds"
                    hint: "Include seconds in the clock"
                    settingKey: "showSeconds"
                }
            }

            Section {
                title: "Widgets"
                width: parent.width
                ToggleRow {
                    title: "Music player"
                    hint: "Playback controls for the Island player"
                    settingKey: "showMusic"
                }

                SplitLine {
                    width: parent.width
                    visible: root.values.showMusic
                }

                ToggleRow {
                    title: "Track title & artist"
                    hint: "Show the current track's title and artist"
                    settingKey: "showTrackInfo"
                    visible: root.values.showMusic
                }

                SplitLine {
                    width: parent.width
                    visible: root.values.showMusic
                }

                ToggleRow {
                    title: "Album artwork"
                    hint: "Show the current track's album cover"
                    settingKey: "showAlbumArt"
                    visible: root.values.showMusic
                }

                SplitLine {
                    width: parent.width
                }

                ToggleRow {
                    title: "Current weather"
                    hint: "Uses the location and units in General → Weather"
                    settingKey: "showWeather"
                }

                SplitLine {
                    width: parent.width
                }

                ToggleRow {
                    title: "Battery & charging"
                    hint: "Show battery level and charging state in the top-right corner"
                    settingKey: "showBattery"
                }

                SplitLine {
                    width: parent.width
                }

                ToggleRow {
                    title: "Power actions"
                    hint: "Sleep, restart and shut down buttons. Each asks for a second click to confirm."
                    settingKey: "showPowerActions"
                }
            }

            Text {
                width: parent.width
                text: "Unlock with your system password. Open the lock screen from the power menu, Lock now, or a shortcut configured on the Shortcut page. A Caps Lock warning appears under the password field when needed. Music favorites require a connected Spotify player."
                wrapMode: Text.Wrap
                color: Theme.secondaryTextColor
                font.family: Theme.textFontFamily
                font.pixelSize: 12
                lineHeight: 1.4
            }
        }
    }

    component SettingButton: Button {
        id: button
        property bool primary: false
        implicitWidth: label.implicitWidth + 28
        implicitHeight: 36
        padding: 0
        hoverEnabled: true
        opacity: enabled ? 1 : 0.45

        HoverHandler {
            cursorShape: button.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        }

        contentItem: Text {
            id: label
            text: button.text
            color: button.primary ? Theme.buttonTextColor : Theme.mutedButtonTextColor
            font.family: Theme.textFontFamily
            font.pixelSize: 13
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: 6
            color: button.primary ? (button.down ? Theme.buttonPressedColor : button.hovered ? Theme.buttonHoverColor : Theme.buttonColor) : (button.down ? Theme.controlPressedColor : button.hovered ? Theme.mutedButtonHoverColor : Theme.mutedButtonColor)
            border.width: 1
            border.color: button.visualFocus ? Theme.focusBorderColor : button.primary ? color : Theme.inputBorderColor

            Behavior on color {
                ColorAnimation {
                    duration: Theme.animationDuration
                }
            }
            Behavior on border.color {
                ColorAnimation {
                    duration: Theme.animationDuration
                }
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: -3
                radius: parent.radius + 3
                color: "transparent"
                border.width: 3
                border.color: Theme.focusRingColor
                opacity: button.visualFocus ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.animationDuration
                    }
                }
            }
        }
    }

    component SplitLine: Rectangle {
        height: 1
        color: Theme.splitLineColor
    }

    component Section: Item {
        id: section
        property string title
        default property alias contents: sectionBody.data
        implicitHeight: sectionTitle.implicitHeight + 15 + sectionPanel.height
        Text {
            id: sectionTitle
            x: 2
            text: section.title
            color: Theme.textColor
            font.family: Theme.titleFontFamily
            font.pixelSize: 23
        }
        Rectangle {
            id: sectionPanel
            y: sectionTitle.implicitHeight + 15
            width: parent.width
            height: sectionBody.implicitHeight + 36
            color: Theme.cardBgColor
            radius: 16
            border.width: 1
            border.color: Theme.splitLineColor
            Column {
                id: sectionBody
                x: 18
                y: 18
                width: parent.width - 36
                spacing: 16
            }
        }
    }

    component SettingRow: Item {
        id: row
        property string title
        property string hint: ""
        property bool elideHint: false
        default property alias controls: rowControls.data
        width: parent.width
        height: Math.max(49, rowLabels.implicitHeight, rowControls.implicitHeight)

        Column {
            id: rowLabels
            anchors.left: parent.left
            anchors.right: rowControls.left
            anchors.rightMargin: 28
            anchors.top: parent.top
            spacing: 5
            Text {
                width: parent.width
                text: row.title
                wrapMode: Text.Wrap
                color: Theme.textColor
                font.family: Theme.textFontFamily
                font.pixelSize: 18
            }
            Text {
                width: parent.width
                visible: row.hint !== ""
                text: row.hint
                wrapMode: row.elideHint ? Text.NoWrap : Text.Wrap
                elide: row.elideHint ? Text.ElideMiddle : Text.ElideNone
                color: Theme.subtleTextColor
                font.family: Theme.textFontFamily
                font.pixelSize: 14
            }
        }

        Row {
            id: rowControls
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
        }
    }

    component ToggleRow: SettingRow {
        id: toggle
        property string settingKey

        Switch {
            id: toggleControl
            checked: root.values[toggle.settingKey]
            Accessible.name: toggle.title
            onToggled: root.update(toggle.settingKey, checked)
            implicitWidth: 48
            implicitHeight: 26
            padding: 0

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }

            indicator: Rectangle {
                width: 40
                height: 24
                radius: 12
                anchors.centerIn: parent
                color: toggleControl.checked ? Theme.accentColor : Theme.componentBgColor
                border.width: toggleControl.visualFocus ? 2 : 1
                border.color: toggleControl.visualFocus ? Theme.focusBorderColor : toggleControl.checked ? Theme.accentColor : Theme.inputBorderColor

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.animationDuration
                    }
                }
                Behavior on border.color {
                    ColorAnimation {
                        duration: Theme.animationDuration
                    }
                }

                Rectangle {
                    x: toggleControl.checked ? 19 : 3
                    y: 3
                    width: 18
                    height: 18
                    radius: 9
                    color: Theme.cardBgColor
                    Behavior on x {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.InOutQuad
                        }
                    }
                }
            }
            contentItem: Item {}
        }
    }

    component PositionRow: SettingRow {
        id: positionRow
        required property string widgetKey
        readonly property point currentPosition: preview.widgetPosition(widgetKey)

        Text {
            text: "X"
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.subtleTextColor
            font.family: Theme.textFontFamily
            font.pixelSize: 14
        }
        CoordinateField {
            objectName: positionRow.widgetKey + "PositionX"
            currentValue: positionRow.currentPosition.x * 100
            field.Accessible.name: positionRow.title + " horizontal position (%)"
            onCommitted: value => root.saveCoordinate(positionRow.widgetKey, "x", value)
        }
        Text {
            text: "Y"
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.subtleTextColor
            font.family: Theme.textFontFamily
            font.pixelSize: 14
        }
        CoordinateField {
            objectName: positionRow.widgetKey + "PositionY"
            currentValue: positionRow.currentPosition.y * 100
            field.Accessible.name: positionRow.title + " vertical position (%)"
            onCommitted: value => root.saveCoordinate(positionRow.widgetKey, "y", value)
        }
        SettingButton {
            objectName: positionRow.widgetKey + "PositionReset"
            text: "Reset"
            Accessible.name: "Reset " + positionRow.title + " position"
            enabled: root.values.positions[positionRow.widgetKey] !== undefined
            onClicked: root.resetPosition(positionRow.widgetKey)
        }
    }

    component CoordinateField: ConfigTextField {
        id: coordinateField
        required property real currentValue
        signal committed(real value)
        width: 82
        height: 36
        text: currentValue.toFixed(1)
        inputMethodHints: Qt.ImhFormattedNumbersOnly
        validator: DoubleValidator {
            bottom: 0
            top: 100
            decimals: 1
            notation: DoubleValidator.StandardNotation
            locale: "C"
        }
        onAccepted: commit()
        onEditingFinished: commit()
        onCurrentValueChanged: if (!field.activeFocus)
            text = currentValue.toFixed(1)

        function commit() {
            const value = Number(text);
            if (text.trim() !== "" && isFinite(value))
                committed(Math.max(0, Math.min(100, value)));
            text = currentValue.toFixed(1);
        }
    }

    component TextRow: SettingRow {
        id: textRow
        property string settingKey
        property string placeholderText: ""
        property int maximumLength: 180

        ConfigTextField {
            width: 230
            height: 36
            text: root.values[textRow.settingKey]
            placeholderText: textRow.placeholderText
            field.maximumLength: textRow.maximumLength
            field.Accessible.name: textRow.title
            onAccepted: commit()
            onEditingFinished: commit()

            function commit() {
                root.update(textRow.settingKey, text.trim());
            }
        }
    }

    component NumberRow: SettingRow {
        id: numberRow
        property string settingKey
        property int minimum: 0
        property int maximum: 100

        IntValidator {
            id: numberValidator
            bottom: numberRow.minimum
            top: numberRow.maximum
        }

        ConfigTextField {
            width: 100
            height: 36
            text: String(root.values[numberRow.settingKey])
            inputMethodHints: Qt.ImhDigitsOnly
            validator: numberValidator
            field.Accessible.name: numberRow.title
            onAccepted: commit()
            onEditingFinished: commit()

            function commit() {
                const parsed = Number(text);
                if (text.trim() !== "" && isFinite(parsed)) {
                    root.update(numberRow.settingKey, Math.max(numberRow.minimum, Math.min(numberRow.maximum, Math.round(parsed))));
                }
                text = String(root.values[numberRow.settingKey]);
            }
        }
    }
}
