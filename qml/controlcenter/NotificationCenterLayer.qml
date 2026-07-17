    import QtQuick
    import IslandBackend
    import "../island"

    Item {
        id: notificationCenter

        signal requestDismiss()

        property var notificationModel: null
        property string iconFontFamily: userConfig.iconFontFamily
        property string textFontFamily: userConfig.textFontFamily
        property string heroFontFamily: userConfig.heroFontFamily

        property color panelBg: "#80000000"
        property int cardRadius: 14
        // Exposed for parent to dynamically size the panel
        readonly property real contentHeight: notificationHistory.listContentHeight + 36 + 20

        signal clearAllRequested()

            // Panel background for blur
            Rectangle {
                anchors.fill: parent
                radius: parent.cardRadius
                color: "#0d0d0d"
            }

        Column {
            anchors.fill: parent
            spacing: 0

            // Unified header — "Notifications" title + count + clear all + close
            Item {
                width: parent.width
                height: 36

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    id: headerTitle
                    text: "Notifications"
                    color: "#f4f5f7"
                    font.pixelSize: 15
                    font.family: notificationCenter.heroFontFamily
                    font.weight: Font.Medium
                }

                // Count badge
                Text {
                    anchors.left: headerTitle.right
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -1
                    text: notificationModel ? String(notificationModel.count) : ""
                    color: "#9ca3af"
                    font.pixelSize: 12
                    font.family: notificationCenter.textFontFamily
                    visible: notificationModel && notificationModel.count > 0
                }

                // Clear All
                Text {
                    id: clearBtn
                    anchors.right: closeBtn.left
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -2
                    text: "Clear all"
                    color: notificationModel && notificationModel.count > 0 ? "#f87171" : "transparent"
                    font.pixelSize: 11
                    font.family: notificationCenter.textFontFamily
                    visible: notificationModel && notificationModel.count > 0

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: notificationCenter.clearAllRequested()
                        onEntered: clearBtn.color = "#fca5a5"
                        onExited: clearBtn.color = "#f87171"
                    }
                }

                Text {
                    id: closeBtn
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 0.5
                    text: "\u2715"
                    color: "#9ca3af"
                    font.pixelSize: 16

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: notificationCenter.requestDismiss()
                        onEntered: closeBtn.color = "#f4f5f7"
                        onExited: closeBtn.color = "#9ca3af"
                    }
                }
            }

            // NotificationHistory — cards, no duplicate header
            NotificationHistory {
                id: notificationHistory
                width: parent.width
                height: parent.height - 36
                notificationModel: notificationCenter.notificationModel
                iconFontFamily: notificationCenter.iconFontFamily
                textFontFamily: notificationCenter.textFontFamily
                heroFontFamily: notificationCenter.heroFontFamily
            }
        }
    }
