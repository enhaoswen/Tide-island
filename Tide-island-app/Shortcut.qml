import QtQuick
import TideIsland 1.0

PagePanel {
    id: root

    property int shortcutRevision: 0
    property int captureIndex: -1
    property int captureTokenRevision: 0
    property var captureTokens: []
    property bool hiddenLegacyOverviewShortcut: false

    readonly property bool supportsTideWorkspaceOverview: backend.supportsTideWorkspaceOverview()
    readonly property bool supportsHyprlandShortcutSnippets: backend.supportsHyprlandShortcutSnippets()
    readonly property bool supportsNiriShortcutSnippets: backend.supportsNiriShortcutSnippets()
    readonly property string compositorName: backend.compositorDisplayName()

    property var shortcuts: []

    function allShortcutDefinitions() {
        return [
            {
                "action": "Workspace overview",
                "mods": "SUPER",
                "key": "TAB",
                "target": "overview",
                "method": "toggle"
            },
            {
                "action": "Swipe right",
                "mods": "SUPER",
                "key": "right",
                "target": "tide",
                "method": "swipeRight"
            },
            {
                "action": "Custom page",
                "mods": "SUPER",
                "key": "left",
                "target": "tide",
                "method": "showCustom"
            },
            {
                "action": "Clock view",
                "mods": "SUPER",
                "key": "down",
                "target": "tide",
                "method": "showClock"
            },
            {
                "action": "Music player",
                "mods": "SUPER",
                "key": "M",
                "target": "tide",
                "method": "togglePlayer"
            },
            {
                "action": "Control center",
                "mods": "SUPER",
                "key": "C",
                "target": "tide",
                "method": "toggleControlCenter"
            },
            {
                "action": "Notification history",
                "mods": "SUPER",
                "key": "N",
                "target": "tide",
                "method": "toggleNotificationCenter"
            },
            {
                "action": "Wallpaper library",
                "mods": "SUPER",
                "key": "W",
                "target": "tide",
                "method": "toggleWallpaperPicker"
            },
            {
                "action": "Toggle island",
                "mods": "SUPER",
                "key": "F",
                "target": "island",
                "method": "toggle"
            }
        ]
    }

    function isWorkspaceOverviewShortcut(shortcut) {
        return shortcut && shortcut.target === "overview"
    }

    function supportedShortcutDefinitions() {
        const supported = []
        const all = allShortcutDefinitions()
        for (let i = 0; i < all.length; ++i) {
            if (!supportsTideWorkspaceOverview && isWorkspaceOverviewShortcut(all[i]))
                continue
            supported.push(all[i])
        }
        return supported
    }

    function beginCapture(index) {
        captureIndex = index
        setCaptureTokens([])
        keyCapture.forceActiveFocus()
    }

    function endCapture() {
        captureIndex = -1
        setCaptureTokens([])
    }

    function setCaptureTokens(tokens) {
        captureTokens = tokens
        captureTokenRevision += 1
    }

    function setShortcut(index, mods, key, finishCapture) {
        shortcuts[index].mods = mods
        shortcuts[index].key = key
        shortcutRevision += 1
        applyShortcutBindings()
        if (finishCapture)
            endCapture()
    }

    function shortcutIdentity(shortcut) {
        return shortcut.target + ":" + shortcut.method
    }

    function rawSavedShortcutBindings() {
        const value = ConfigStore.value("shortcutBindings", [])
        return Array.isArray(value) ? value : []
    }

    function savedHasWorkspaceOverviewShortcut() {
        const saved = rawSavedShortcutBindings()
        for (let i = 0; i < saved.length; ++i) {
            if (isWorkspaceOverviewShortcut(saved[i]))
                return true
        }
        return false
    }

    function shortcutBindingsForBackend() {
        const bindings = []
        for (let i = 0; i < shortcuts.length; ++i) {
            const shortcut = shortcuts[i]
            bindings.push({
                "mods": shortcut.mods,
                "key": shortcut.key,
                "target": shortcut.target,
                "method": shortcut.method
            })
        }
        return bindings
    }

    function applyShortcutBindings() {
        const bindings = shortcutBindingsForBackend()
        backend.applyShortcutBindings(bindings)
        hiddenLegacyOverviewShortcut = false
    }

    function loadShortcutBindings() {
        shortcuts = supportedShortcutDefinitions()
        hiddenLegacyOverviewShortcut = !supportsTideWorkspaceOverview && savedHasWorkspaceOverviewShortcut()

        const saved = backend.shortcutBindings()
        const byIdentity = ({})
        for (let i = 0; i < saved.length; ++i)
            byIdentity[shortcutIdentity(saved[i])] = saved[i]

        for (let j = 0; j < shortcuts.length; ++j) {
            const binding = byIdentity[shortcutIdentity(shortcuts[j])]
            if (!binding)
                continue

            shortcuts[j].mods = binding.mods
            shortcuts[j].key = binding.key
        }

        shortcutRevision += 1
    }

    function shortcutCommand(shortcut) {
        return "/usr/bin/quickshell ipc --any-display -p /usr/share/tide-island call "
            + shortcut.target + " " + shortcut.method
    }

    function luaQuote(value) {
        return "\"" + String(value).replace(/\\/g, "\\\\").replace(/"/g, "\\\"") + "\""
    }

    function modNames(modifiers) {
        const names = []
        if (modifiers & Qt.MetaModifier)
            names.push("SUPER")
        if (modifiers & Qt.ShiftModifier)
            names.push("SHIFT")
        if (modifiers & Qt.ControlModifier)
            names.push("CTRL")
        if (modifiers & Qt.AltModifier)
            names.push("ALT")
        return names
    }

    function modifierNameForKey(key) {
        switch (key) {
        case Qt.Key_Meta:
        case Qt.Key_Super_L:
        case Qt.Key_Super_R:
            return "SUPER"
        case Qt.Key_Shift:
            return "SHIFT"
        case Qt.Key_Control:
            return "CTRL"
        case Qt.Key_Alt:
            return "ALT"
        default:
            return ""
        }
    }

    function appendUnique(values, value) {
        if (value.length > 0 && values.indexOf(value) < 0)
            values.push(value)
    }

    function isModifierToken(value) {
        return value === "SUPER" || value === "SHIFT" || value === "CTRL" || value === "ALT"
    }

    function updateCapturedShortcut(tokens) {
        let key = ""
        const mods = []
        for (let i = 0; i < tokens.length; ++i) {
            if (isModifierToken(tokens[i])) {
                appendUnique(mods, tokens[i])
            } else {
                key = tokens[i]
            }
        }

        if (key.length > 0)
            setShortcut(captureIndex, mods.join(" "), key, false)
    }

    function addCaptureToken(token) {
        if (token.length === 0)
            return

        const tokens = captureTokens.slice()
        if (isModifierToken(token)) {
            if (tokens.indexOf(token) < 0 && tokens.length < 3) {
                let keyIndex = -1
                for (let i = 0; i < tokens.length; ++i) {
                    if (!isModifierToken(tokens[i])) {
                        keyIndex = i
                        break
                    }
                }

                if (keyIndex >= 0)
                    tokens.splice(keyIndex, 0, token)
                else
                    tokens.push(token)
            }
        } else {
            let replaced = false
            for (let i = 0; i < tokens.length; ++i) {
                if (!isModifierToken(tokens[i])) {
                    tokens[i] = token
                    replaced = true
                    break
                }
            }

            if (!replaced) {
                if (tokens.length < 3) {
                    tokens.push(token)
                } else {
                    tokens[tokens.length - 1] = token
                }
            }
        }

        if (tokens.length > 3)
            tokens.splice(3)

        setCaptureTokens(tokens)

        let hasKey = false
        for (let j = 0; j < tokens.length; ++j)
            hasKey = hasKey || !isModifierToken(tokens[j])

        if (hasKey)
            updateCapturedShortcut(tokens)
        if (tokens.length >= 3 && hasKey)
            endCapture()
    }

    function hyprKeyName(key, text) {
        if (key >= Qt.Key_A && key <= Qt.Key_Z)
            return String.fromCharCode("A".charCodeAt(0) + key - Qt.Key_A)
        if (key >= Qt.Key_0 && key <= Qt.Key_9)
            return String.fromCharCode("0".charCodeAt(0) + key - Qt.Key_0)
        if (key >= Qt.Key_F1 && key <= Qt.Key_F35)
            return "F" + (key - Qt.Key_F1 + 1)

        switch (key) {
        case Qt.Key_Tab:
            return "TAB"
        case Qt.Key_Left:
            return "left"
        case Qt.Key_Right:
            return "right"
        case Qt.Key_Up:
            return "up"
        case Qt.Key_Down:
            return "down"
        case Qt.Key_Space:
            return "space"
        case Qt.Key_Return:
        case Qt.Key_Enter:
            return "return"
        case Qt.Key_Backspace:
            return "backspace"
        case Qt.Key_Delete:
            return "delete"
        case Qt.Key_Insert:
            return "insert"
        case Qt.Key_Home:
            return "home"
        case Qt.Key_End:
            return "end"
        case Qt.Key_PageUp:
            return "page_up"
        case Qt.Key_PageDown:
            return "page_down"
        case Qt.Key_Minus:
            return "minus"
        case Qt.Key_Equal:
            return "equal"
        case Qt.Key_BracketLeft:
            return "bracketleft"
        case Qt.Key_BracketRight:
            return "bracketright"
        case Qt.Key_Backslash:
            return "backslash"
        case Qt.Key_Semicolon:
            return "semicolon"
        case Qt.Key_Apostrophe:
            return "apostrophe"
        case Qt.Key_Comma:
            return "comma"
        case Qt.Key_Period:
            return "period"
        case Qt.Key_Slash:
            return "slash"
        case Qt.Key_QuoteLeft:
            return "grave"
        default:
            return text && text.length === 1 ? text : ""
        }
    }

    function displayToken(value) {
        switch (String(value)) {
        case "SUPER":
            return "Super"
        case "SHIFT":
            return "Shift"
        case "CTRL":
            return "Ctrl"
        case "ALT":
            return "Alt"
        case "TAB":
            return "Tab"
        case "left":
            return "Left"
        case "right":
            return "Right"
        case "up":
            return "Up"
        case "down":
            return "Down"
        case "space":
            return "Space"
        case "return":
            return "Return"
        case "backspace":
            return "Backspace"
        case "delete":
            return "Delete"
        case "insert":
            return "Insert"
        case "home":
            return "Home"
        case "end":
            return "End"
        case "page_up":
            return "Page Up"
        case "page_down":
            return "Page Down"
        default:
            return String(value).length === 1 ? String(value).toUpperCase() : String(value)
        }
    }

    function displayChord(mods, key) {
        const parts = []
        const modParts = String(mods).split(" ")
        for (let i = 0; i < modParts.length; ++i) {
            if (modParts[i].length > 0)
                parts.push(displayToken(modParts[i]))
        }
        if (String(key).length > 0)
            parts.push(displayToken(key))
        return parts.join(" + ")
    }

    function displayTokens(tokens) {
        const parts = []
        for (let i = 0; i < tokens.length; ++i)
            parts.push(displayToken(tokens[i]))
        return parts.join(" + ")
    }

    function shortcutDisplay(index) {
        shortcutRevision
        captureTokenRevision
        if (captureIndex === index && captureTokens.length > 0)
            return displayTokens(captureTokens)
        if (captureIndex === index)
            return "Press keys"

        const shortcut = shortcuts[index]
        return displayChord(shortcut.mods, shortcut.key)
    }

    function handleShortcutKey(event) {
        if (captureIndex < 0)
            return

        if (event.key === Qt.Key_Escape) {
            endCapture()
            event.accepted = true
            return
        }

        if (event.key === Qt.Key_Backspace) {
            const tokens = captureTokens.slice()
            tokens.pop()
            setCaptureTokens(tokens)
            event.accepted = true
            return
        }

        const mods = modNames(event.modifiers)
        const modifierName = modifierNameForKey(event.key)
        for (let i = 0; i < mods.length; ++i)
            addCaptureToken(mods[i])

        const key = hyprKeyName(event.key, event.text)
        addCaptureToken(modifierName.length > 0 ? modifierName : key)
        event.accepted = true
    }

    function hyprlandConfCommands() {
        shortcutRevision
        const lines = []
        for (let i = 0; i < shortcuts.length; ++i) {
            const shortcut = shortcuts[i]
            lines.push("bind = " + shortcut.mods + ", " + shortcut.key + ", exec, " + shortcutCommand(shortcut))
        }
        return lines.join("\n")
    }

    function hyprlandLuaCommands() {
        shortcutRevision
        const lines = []
        for (let i = 0; i < shortcuts.length; ++i) {
            const shortcut = shortcuts[i]
            const modifiers = String(shortcut.mods).split(" ").filter(function(value) {
                return value.length > 0
            })
            const chord = modifiers.concat([displayToken(shortcut.key)]).join(" + ")
            lines.push("hl.bind("
                + luaQuote(chord) + ", "
                + "hl.dsp.exec_cmd("
                + luaQuote(shortcutCommand(shortcut))
                + "))")
        }
        return lines.join("\n")
    }

    function niriConfigCommands() {
        shortcutRevision
        return backend.niriConfigCommands()
    }

    Item {
        id: keyCapture
        focus: true
        Keys.onPressed: function(event) {
            root.handleShortcutKey(event)
        }
    }

    Component.onCompleted: loadShortcutBindings()

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
            height: pageColumn.implicitHeight + 100

            Column {
                id: pageColumn

                x: 30
                y: 50
                width: Math.max(260, parent.width - 70)
                spacing: 34

                Text {
                    text: "Shortcut"
                    color: Theme.textColor
                    font.family: Theme.titleFontFamily
                    font.pixelSize: 30
                }

                Text {
                    text: "Supported shortcuts"
                    color: Theme.textColor
                    font.family: Theme.titleFontFamily
                    font.pixelSize: 23
                    font.weight: Font.Normal
                }

                Text {
                    width: parent.width
                    text: supportsTideWorkspaceOverview
                        ? "Current desktop: " + compositorName + ". Tide workspace overview shortcuts are available here."
                        : "Current desktop: " + compositorName + ". Tide workspace overview is hidden here; use the compositor native overview or your own compositor config."
                    color: Theme.subtleTextColor
                    wrapMode: Text.WordWrap
                    font.family: Theme.textFontFamily
                    font.pixelSize: 14
                }

                Text {
                    width: parent.width
                    text: "Island shortcuts call Quickshell IPC and can be reused in shell scripts; the default island action is toggle."
                    color: Theme.subtleTextColor
                    wrapMode: Text.WordWrap
                    font.family: Theme.textFontFamily
                    font.pixelSize: 14
                }

                Text {
                    width: parent.width
                    visible: hiddenLegacyOverviewShortcut
                    text: "A saved Workspace overview shortcut exists from another compositor. It is hidden and will not be written to the current shortcut config."
                    color: Theme.subtleTextColor
                    wrapMode: Text.WordWrap
                    font.family: Theme.textFontFamily
                    font.pixelSize: 14
                }

                Rectangle {
                    width: parent.width
                    height: shortcutColumn.implicitHeight + 30
                    radius: 10
                    color: "transparent"
                    border.width: 2
                    border.color: Theme.splitLineColor

                    Column {
                        id: shortcutColumn

                        anchors.top: parent.top
                        anchors.topMargin: 15
                        anchors.left: parent.left
                        anchors.leftMargin: 18
                        anchors.right: parent.right
                        anchors.rightMargin: 18
                        spacing: 12

                        Repeater {
                            model: root.shortcuts

                            ShortcutRow {
                                width: parent.width
                                shortcutIndex: index
                                action: modelData.action
                                showSeparator: index < root.shortcuts.length - 1
                            }
                        }
                    }
                }

                CopyBox {
                    width: parent.width
                    visible: supportsHyprlandShortcutSnippets
                    title: "Hyprland.conf"
                    pathLabel: "~/.config/hypr/hyprland.conf"
                    description: "Paste these binds there, or reuse the island toggle command in your own scripts."
                    code: root.hyprlandConfCommands()
                }

                CopyBox {
                    width: parent.width
                    visible: supportsNiriShortcutSnippets
                    title: "Niri config.kdl"
                    pathLabel: "~/.config/tide-island/niri-shortcuts.kdl"
                    description: "Tide includes this file from ~/.config/niri/config.kdl after niri validate succeeds."
                    code: root.niriConfigCommands()
                }

                CopyBox {
                    width: parent.width
                    visible: supportsHyprlandShortcutSnippets
                    title: "Lua"
                    pathLabel: "~/.config/hypr/hyprland.lua"
                    description: "Use this variant when your Hyprland bindings are generated from Lua."
                    code: root.hyprlandLuaCommands()
                }

            }
        }
    }

    component ShortcutRow: Item {
        id: row

        property int shortcutIndex: -1
        property string action: ""
        property bool showSeparator: false
        readonly property bool capturing: root.captureIndex === shortcutIndex

        height: 48

        Text {
            id: actionText

            anchors.left: parent.left
            anchors.right: shortcutButton.left
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            text: row.action
            color: Theme.textColor
            elide: Text.ElideRight
            font.family: Theme.textFontFamily
            font.pixelSize: 16
            font.weight: Font.Normal
        }

        Rectangle {
            id: shortcutButton

            width: Math.min(190, Math.max(128, parent.width * 0.36))
            height: 34
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            radius: 8
            color: "transparent"
            border.width: 2
            border.color: row.capturing ? Theme.focusBorderColor : Theme.inputBorderColor

            Text {
                anchors.centerIn: parent
                width: parent.width - 20
                text: root.shortcutDisplay(row.shortcutIndex)
                color: row.capturing ? Theme.selectedColor : Theme.secondaryTextColor
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                font.family: Theme.textFontFamily
                font.pixelSize: 14
                font.weight: row.capturing ? Font.DemiBold : Font.Normal
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: root.beginCapture(row.shortcutIndex)
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 2
            color: Theme.splitLineColor
            visible: row.showSeparator
        }
    }

    component CopyBox: Rectangle {
        id: box

        property string title: ""
        property string pathLabel: ""
        property string description: ""
        property string code: ""
        property bool copied: false

        height: boxColumn.implicitHeight + 30
        radius: 10
        color: "transparent"
        border.width: 2
        border.color: Theme.splitLineColor

        Column {
            id: boxColumn

            anchors.top: parent.top
            anchors.topMargin: 15
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.right: parent.right
            anchors.rightMargin: 18
            spacing: 12

            Row {
                width: parent.width
                height: Math.max(34, boxTitle.implicitHeight)
                spacing: 12

                Text {
                    id: boxTitle

                    width: Math.max(110, parent.width - copyBadge.width - parent.spacing)
                    anchors.verticalCenter: parent.verticalCenter
                    text: box.title
                    color: Theme.textColor
                    elide: Text.ElideRight
                    font.family: Theme.titleFontFamily
                    font.pixelSize: 23
                }

                Rectangle {
                    id: copyBadge

                    width: Math.max(74, copyBadgeText.implicitWidth + 24)
                    height: 34
                    radius: 8
                    color: box.copied ? Theme.selectedColor : Theme.mutedButtonColor
                    border.width: 2
                    border.color: box.copied ? Theme.selectedColor : Theme.inputBorderColor

                    Behavior on color {
                        ColorAnimation { duration: Theme.animationDuration }
                    }

                    Behavior on border.color {
                        ColorAnimation { duration: Theme.animationDuration }
                    }

                    Text {
                        id: copyBadgeText

                        anchors.centerIn: parent
                        text: box.copied ? "Copied" : "Copy"
                        color: box.copied ? Theme.buttonTextColor : Theme.mutedButtonTextColor
                        font.family: Theme.textFontFamily
                        font.pixelSize: 14
                        font.weight: Font.DemiBold

                        Behavior on color {
                            ColorAnimation { duration: Theme.animationDuration }
                        }
                    }
                }
            }

            Text {
                width: parent.width
                text: box.pathLabel
                color: Theme.subtleTextColor
                elide: Text.ElideRight
                font.family: Theme.textFontFamily
                font.pixelSize: 14
            }

            Text {
                width: parent.width
                text: box.description
                color: Theme.subtleTextColor
                wrapMode: Text.WordWrap
                visible: box.description.length > 0
                font.family: Theme.textFontFamily
                font.pixelSize: 14
            }

            Rectangle {
                width: parent.width
                height: codeText.implicitHeight + 24
                radius: 8
                color: Theme.inputBgColor
                border.width: 2
                border.color: Theme.inputBorderColor

                Text {
                    id: codeText

                    anchors.top: parent.top
                    anchors.topMargin: 12
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    text: box.code
                    color: Theme.textColor
                    wrapMode: Text.WrapAnywhere
                    font.family: "monospace"
                    font.pixelSize: 13
                    lineHeight: 1.18
                }
            }
        }

        Timer {
            id: copyResetTimer
            interval: 1200
            repeat: false
            onTriggered: box.copied = false
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: {
                root.endCapture()
                if (backend.copyToClipboard(box.code)) {
                    box.copied = true
                    copyResetTimer.restart()
                }
            }
        }
    }
}
