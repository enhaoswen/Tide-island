import QtQuick
import QtQuick.Controls
import TideIsland 1.0

PagePanel {
    id: root

    readonly property string playerAction: "toggleExpandedPlayer"
    readonly property string controlAction: "toggleControlCenter"
    readonly property var mouseButtonOptions: [
        { "label": "Left", "value": 1 },
        { "label": "Middle", "value": 2 },
        { "label": "Right", "value": 3 }
    ]
    readonly property var hoverActionOptions: [
        { "label": "Disabled", "value": 0 },
        { "label": "Music Player", "value": 1 },
        { "label": "Control Center", "value": 2 }
    ]

    property int revision: 0

    function normalizedButton(value, fallback) {
        const parsedValue = Number(value)
        if (parsedValue === 1 || parsedValue === 2 || parsedValue === 3)
            return parsedValue
        return fallback
    }

    function normalizedHoverAction(value) {
        const parsedValue = Number(value)
        if (parsedValue === 0 || parsedValue === 1 || parsedValue === 2)
            return parsedValue
        return 1
    }

    function normalizedAutoHideDelay(value) {
        const parsedValue = Number(value)
        if (isNaN(parsedValue))
            return 1000
        return Math.min(10000, Math.max(100, Math.round(parsedValue)))
    }

    function boolValue(key, fallback) {
        const value = ConfigStore.value(key, fallback)
        return value === true || value === "true"
    }

    function buttonForAction(actionName, fallback) {
        revision

        const primaryAction = String(ConfigStore.value("dynamicIslandPrimaryAction", root.playerAction))
        const secondaryAction = String(ConfigStore.value("dynamicIslandSecondaryAction", root.controlAction))

        if (primaryAction === actionName)
            return normalizedButton(ConfigStore.value("dynamicIslandPrimaryButton", fallback), fallback)
        if (secondaryAction === actionName)
            return normalizedButton(ConfigStore.value("dynamicIslandSecondaryButton", fallback), fallback)

        return fallback
    }

    function firstFreeButton(usedButton) {
        const buttons = [1, 2, 3]
        for (let i = 0; i < buttons.length; ++i) {
            if (buttons[i] !== usedButton)
                return buttons[i]
        }
        return 1
    }

    function saveClickMappings(playerButton, controlButton) {
        ConfigStore.setValue("dynamicIslandPrimaryAction", root.playerAction)
        ConfigStore.setValue("dynamicIslandPrimaryButton", playerButton)
        ConfigStore.setValue("dynamicIslandSecondaryAction", root.controlAction)
        ConfigStore.setValue("dynamicIslandSecondaryButton", controlButton)
        ConfigStore.save()
        revision += 1
    }

    function setButtonForAction(actionName, button) {
        let playerButton = buttonForAction(root.playerAction, 1)
        let controlButton = buttonForAction(root.controlAction, 3)
        const previousPlayerButton = playerButton
        const previousControlButton = controlButton

        if (actionName === root.playerAction) {
            playerButton = button
            if (controlButton === playerButton)
                controlButton = normalizedButton(previousPlayerButton, 1)
            if (controlButton === playerButton)
                controlButton = firstFreeButton(playerButton)
        } else if (actionName === root.controlAction) {
            controlButton = button
            if (playerButton === controlButton)
                playerButton = normalizedButton(previousControlButton, 3)
            if (playerButton === controlButton)
                playerButton = firstFreeButton(controlButton)
        }

        saveClickMappings(playerButton, controlButton)
    }

    function hoverActionValue() {
        revision
        return normalizedHoverAction(ConfigStore.value("hoverExpandAction", 1))
    }

    function setHoverAction(value) {
        ConfigStore.setValue("hoverExpandAction", value)
        ConfigStore.save()
        revision += 1
    }

    function islandAutoHideEnabled() {
        revision
        return boolValue("islandAutoHideEnabled", true)
    }

    function setIslandAutoHideEnabled(enabled) {
        ConfigStore.setValue("islandAutoHideEnabled", enabled)
        ConfigStore.save()
        revision += 1
    }

    function islandAutoHideDelayMs() {
        revision
        return normalizedAutoHideDelay(ConfigStore.value("islandAutoHideDelayMs", 1000))
    }

    function hideDelaySecondsText() {
        const seconds = islandAutoHideDelayMs() / 1000
        if (Math.abs(seconds - Math.round(seconds)) < 0.001)
            return String(Math.round(seconds))
        return String(Math.round(seconds * 10) / 10)
    }

    function saveCustomHideDelay(value) {
        const parsedValue = Number(String(value).trim())
        const seconds = isNaN(parsedValue) ? islandAutoHideDelayMs() / 1000 : parsedValue
        const boundedSeconds = Math.min(10, Math.max(0.1, seconds))
        const delayMs = normalizedAutoHideDelay(boundedSeconds * 1000)
        ConfigStore.setValue("islandAutoHideDelayMs", delayMs)
        ConfigStore.save()
        revision += 1
        return delayMs / 1000
    }

    function autoExpandOnTrackChange() {
        revision
        return !boolValue("disableAutoExpandOnTrackChange", false)
    }

    function setAutoExpandOnTrackChange(enabled) {
        ConfigStore.setValue("disableAutoExpandOnTrackChange", !enabled)
        ConfigStore.save()
        revision += 1
    }

    Flickable {
        id: scroller

        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: content.height
        boundsBehavior: Flickable.StopAtBounds
        boundsMovement: Flickable.StopAtBounds
        interactive: false

        WheelHandler {
            target: null
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

            onWheel: function(event) {
                const rawDelta = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y / 120 * 64
                const maxY = Math.max(0, scroller.contentHeight - scroller.height)
                scroller.contentY = Math.max(0, Math.min(maxY, scroller.contentY - rawDelta))
                event.accepted = true
            }
        }

        Item {
            id: content

            width: scroller.width
            height: playerPanel.y + playerPanel.height + 40

            Text {
                id: title

                text: "Interaction"
                x: 60
                y: 50
                color: Theme.textColor
                font.family: Theme.titleFontFamily
                font.pixelSize: 30
            }

            Text {
                id: clickTitle

                text: "Click"
                anchors.top: title.bottom
                anchors.topMargin: 40
                anchors.left: parent.left
                anchors.leftMargin: 32
                anchors.right: parent.right
                anchors.rightMargin: 40
                color: Theme.textColor
                font.family: Theme.titleFontFamily
                font.pixelSize: 23
            }

            Rectangle {
                id: clickPanel

                color: Theme.cardBgColor
                radius: 16
                border.width: 1
                border.color: Theme.splitLineColor
                anchors.top: clickTitle.bottom
                anchors.topMargin: 15
                anchors.left: parent.left
                anchors.leftMargin: 30
                anchors.right: parent.right
                anchors.rightMargin: 40
                height: clickColumn.implicitHeight + 30

                Column {
                    id: clickColumn

                    anchors.top: parent.top
                    anchors.topMargin: 15
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    spacing: 15

                    ActionButtonRow {
                        title: "Music Player"
                        description: "Mouse button that toggles the player"
                        actionName: root.playerAction
                        fallbackButton: 1
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ActionButtonRow {
                        title: "Control Center"
                        description: "Mouse button that toggles the control center"
                        actionName: root.controlAction
                        fallbackButton: 3
                        width: parent.width
                    }
                }
            }

            Text {
                id: hoverTitle

                text: "Hover"
                anchors.top: clickPanel.bottom
                anchors.topMargin: 34
                anchors.left: parent.left
                anchors.leftMargin: 32
                anchors.right: parent.right
                anchors.rightMargin: 40
                color: Theme.textColor
                font.family: Theme.titleFontFamily
                font.pixelSize: 23
            }

            Rectangle {
                id: hoverPanel

                color: Theme.cardBgColor
                radius: 16
                border.width: 1
                border.color: Theme.splitLineColor
                anchors.top: hoverTitle.bottom
                anchors.topMargin: 15
                anchors.left: parent.left
                anchors.leftMargin: 30
                anchors.right: parent.right
                anchors.rightMargin: 40
                height: hoverColumn.implicitHeight + 30

                Column {
                    id: hoverColumn

                    anchors.top: parent.top
                    anchors.topMargin: 15
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    spacing: 15

                    HoverActionRow {
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    AutoHideRow {
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    HideDelayRow {
                        width: parent.width
                    }
                }
            }

            Text {
                id: playerTitle

                text: "Player"
                anchors.top: hoverPanel.bottom
                anchors.topMargin: 34
                anchors.left: parent.left
                anchors.leftMargin: 32
                anchors.right: parent.right
                anchors.rightMargin: 40
                color: Theme.textColor
                font.family: Theme.titleFontFamily
                font.pixelSize: 23
            }

            Rectangle {
                id: playerPanel

                color: Theme.cardBgColor
                radius: 16
                border.width: 1
                border.color: Theme.splitLineColor
                anchors.top: playerTitle.bottom
                anchors.topMargin: 15
                anchors.left: parent.left
                anchors.leftMargin: 30
                anchors.right: parent.right
                anchors.rightMargin: 40
                height: playerColumn.implicitHeight + 30

                Column {
                    id: playerColumn

                    anchors.top: parent.top
                    anchors.topMargin: 15
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.right: parent.right
                    anchors.rightMargin: 18

                    AutoExpandTrackRow {
                        width: parent.width
                    }
                }
            }
        }
    }

    component SplitLine: Rectangle {
        height: 1
        color: Theme.splitLineColor
    }

    component ActionButtonRow: Item {
        id: row

        property string title: ""
        property string description: ""
        property string actionName: ""
        property int fallbackButton: 1

        height: 49

        Text {
            id: rowTitle

            text: row.title
            anchors.left: parent.left
            anchors.top: parent.top
            color: Theme.textColor
            font.family: Theme.textFontFamily
            font.pixelSize: 18
        }

        Text {
            text: row.description
            anchors.left: rowTitle.left
            anchors.top: rowTitle.bottom
            anchors.topMargin: 5
            width: Math.max(80, parent.width - buttonGroup.width - 28)
            color: Theme.subtleTextColor
            elide: Text.ElideRight
            font.family: Theme.textFontFamily
            font.pixelSize: 14
        }

        ButtonGroup {
            id: buttonGroup

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            options: root.mouseButtonOptions
            selectedValue: root.buttonForAction(row.actionName, row.fallbackButton)

            onSelected: function(value) {
                root.setButtonForAction(row.actionName, value)
            }
        }
    }

    component HoverActionRow: Item {
        id: row

        height: 49

        Text {
            id: rowTitle

            text: "Hover Expand"
            anchors.left: parent.left
            anchors.top: parent.top
            color: Theme.textColor
            font.family: Theme.textFontFamily
            font.pixelSize: 18
        }

        Text {
            text: "Choose what opens when the island is hovered"
            anchors.left: rowTitle.left
            anchors.top: rowTitle.bottom
            anchors.topMargin: 5
            width: Math.max(80, parent.width - hoverGroup.width - 28)
            color: Theme.subtleTextColor
            elide: Text.ElideRight
            font.family: Theme.textFontFamily
            font.pixelSize: 14
        }

        ButtonGroup {
            id: hoverGroup

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            options: root.hoverActionOptions
            selectedValue: root.hoverActionValue()

            onSelected: function(value) {
                root.setHoverAction(value)
            }
        }
    }

    component AutoExpandTrackRow: Item {
        id: row

        height: 49

        Text {
            id: rowTitle

            text: "Auto Expand Player"
            anchors.left: parent.left
            anchors.top: parent.top
            color: Theme.textColor
            font.family: Theme.textFontFamily
            font.pixelSize: 18
        }

        Text {
            text: "Open the music player when the current track changes"
            anchors.left: rowTitle.left
            anchors.top: rowTitle.bottom
            anchors.topMargin: 5
            width: Math.max(80, parent.width - autoExpandSwitch.width - 28)
            color: Theme.subtleTextColor
            elide: Text.ElideRight
            font.family: Theme.textFontFamily
            font.pixelSize: 14
        }

        StyledSwitch {
            id: autoExpandSwitch

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: root.autoExpandOnTrackChange()

            onToggled: function(checked) {
                root.setAutoExpandOnTrackChange(checked)
            }
        }
    }

    component AutoHideRow: Item {
        id: row

        height: 49

        Text {
            id: rowTitle

            text: "Auto Hide"
            anchors.left: parent.left
            anchors.top: parent.top
            color: Theme.textColor
            font.family: Theme.textFontFamily
            font.pixelSize: 18
        }

        Text {
            text: "Hide the island until the pointer reaches the top edge"
            anchors.left: rowTitle.left
            anchors.top: rowTitle.bottom
            anchors.topMargin: 5
            width: Math.max(80, parent.width - autoHideSwitch.width - 28)
            color: Theme.subtleTextColor
            elide: Text.ElideRight
            font.family: Theme.textFontFamily
            font.pixelSize: 14
        }

        StyledSwitch {
            id: autoHideSwitch

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: root.islandAutoHideEnabled()

            onToggled: function(checked) {
                root.setIslandAutoHideEnabled(checked)
            }
        }
    }

    component HideDelayRow: Item {
        id: row

        height: 49

        Text {
            id: rowTitle

            text: "Hide Delay"
            anchors.left: parent.left
            anchors.top: parent.top
            color: Theme.textColor
            font.family: Theme.textFontFamily
            font.pixelSize: 18
        }

        Text {
            text: "Delay after the pointer leaves the island"
            anchors.left: rowTitle.left
            anchors.top: rowTitle.bottom
            anchors.topMargin: 5
            width: Math.max(80, parent.width - delayControls.width - 28)
            color: Theme.subtleTextColor
            elide: Text.ElideRight
            font.family: Theme.textFontFamily
            font.pixelSize: 14
        }

        Row {
            id: delayControls

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            ConfigTextField {
                id: delayField

                width: 72
                height: 36
                textPixelSize: 14
                placeholderText: "1"
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                validator: DoubleValidator {
                    bottom: 0.1
                    top: 10
                    decimals: 1
                    notation: DoubleValidator.StandardNotation
                }

                Component.onCompleted: text = root.hideDelaySecondsText()
                onAccepted: row.commitCustomDelay()
                onEditingFinished: row.commitCustomDelay()
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "s"
                color: Theme.subtleTextColor
                font.family: Theme.textFontFamily
                font.pixelSize: 14
            }
        }

        function commitCustomDelay() {
            delayField.text = String(root.saveCustomHideDelay(delayField.text))
        }
    }

    component StyledSwitch: Item {
        id: control

        signal toggled(bool checked)

        property bool checked: false

        width: 48
        height: 26

        Rectangle {
            id: track

            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            width: 40
            height: 24
            radius: 12
            color: control.checked ? Theme.accentColor : Theme.componentBgColor
            border.width: 1
            border.color: control.checked ? Theme.accentColor : Theme.inputBorderColor

            Behavior on color {
                ColorAnimation { duration: 180; easing.type: Easing.InOutQuad }
            }
        }

        Rectangle {
            id: knob

            width: 18
            height: 18
            radius: 9
            x: control.checked ? 22 : 6
            y: 3
            color: Theme.cardBgColor
            border.width: 0

            Behavior on x {
                NumberAnimation { duration: 180; easing.type: Easing.InOutQuad }
            }

        }

        MouseArea {
            id: switchMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: control.toggled(!control.checked)
        }
    }

    component ButtonGroup: Row {
        id: group

        signal selected(int value)

        property var options: []
        property int selectedValue: -1

        width: implicitWidth
        height: implicitHeight
        spacing: 6

        Repeater {
            model: group.options

            Rectangle {
                id: option

                property bool selectedState: group.selectedValue === modelData.value

                width: Math.max(74, optionText.implicitWidth + 24)
                height: 36
                radius: 7
                color: selectedState ? Theme.cardBgColor
                                     : optionMouse.pressed ? Theme.controlPressedColor
                                                           : Theme.componentBgColor
                border.width: 1
                border.color: Theme.inputBorderColor

                Behavior on color {
                    ColorAnimation { duration: Theme.animationDuration }
                }

                Behavior on border.color {
                    ColorAnimation { duration: Theme.animationDuration }
                }

                Text {
                    id: optionText

                    anchors.centerIn: parent
                    text: modelData.label
                    color: option.selectedState ? Theme.textColor : Theme.secondaryTextColor
                    font.family: Theme.textFontFamily
                    font.pixelSize: 14
                    font.weight: option.selectedState ? Font.DemiBold : Font.Normal
                }

                MouseArea {
                    id: optionMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: group.selected(modelData.value)
                }
            }
        }
    }
}
