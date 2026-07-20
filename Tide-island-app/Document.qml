import TideIsland 1.0
import QtQuick

PagePanel {
    id: root

    color: "transparent"

    readonly property bool supportsTideWorkspaceOverview: backend.supportsTideWorkspaceOverview()
    readonly property bool supportsHyprlandShortcutSnippets: backend.supportsHyprlandShortcutSnippets()
    readonly property bool supportsNiriShortcutSnippets: backend.supportsNiriShortcutSnippets()
    readonly property string compositorName: backend.compositorDisplayName()
    readonly property string nightLightBackendName: backend.nightLightBackendName()

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
                spacing: 24

                Text {
                    text: "Document"
                    color: Theme.textColor
                    font.family: Theme.titleFontFamily
                    font.pixelSize: 30
                }

                InfoBlock {
                    title: "Current desktop"
                    body: root.supportsTideWorkspaceOverview
                        ? root.compositorName + " has the full Tide Island experience, including Tide workspace overview."
                        : root.compositorName + " uses all Tide Island features except Tide workspace overview. Use the compositor native overview or your own compositor config."
                }

                InfoBlock {
                    visible: root.supportsHyprlandShortcutSnippets
                    title: "Hyprland shortcuts"
                    body: "The Shortcut page writes ~/.config/tide-island/hyprland-shortcuts.conf, sources it from ~/.config/hypr/hyprland.conf, then reloads Hyprland."
                }

                InfoBlock {
                    visible: root.supportsNiriShortcutSnippets
                    title: "niri shortcuts"
                    body: "The Shortcut page writes ~/.config/tide-island/niri-shortcuts.kdl, includes it from ~/.config/niri/config.kdl after niri validate succeeds, then reloads niri."
                }

                InfoBlock {
                    title: "Night Light"
                    body: "Night Light uses " + root.nightLightBackendName + " on this desktop."
                }
            }
        }
    }

    component InfoBlock: Rectangle {
        id: block

        property string title: ""
        property string body: ""

        width: parent ? parent.width : 0
        height: blockColumn.implicitHeight + 30
        radius: 16
        color: Theme.cardBgColor
        border.width: 1
        border.color: Theme.splitLineColor

        Column {
            id: blockColumn

            anchors.top: parent.top
            anchors.topMargin: 15
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.right: parent.right
            anchors.rightMargin: 18
            spacing: 10

            Text {
                width: parent.width
                text: block.title
                color: Theme.textColor
                font.family: Theme.titleFontFamily
                font.pixelSize: 23
            }

            Text {
                width: parent.width
                text: block.body
                color: Theme.subtleTextColor
                wrapMode: Text.WordWrap
                font.family: Theme.textFontFamily
                font.pixelSize: 14
            }
        }
    }
}
