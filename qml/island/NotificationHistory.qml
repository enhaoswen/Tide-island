import QtQuick
    import QtQuick.Controls
    import IslandBackend

    Item {
        id: root

        readonly property var userConfig: UserConfig
        property var notificationModel: null
        property string iconFontFamily: userConfig.iconFontFamily
        property string textFontFamily: userConfig.textFontFamily
        property string heroFontFamily: userConfig.heroFontFamily

        // One UI color scheme
        property color textPrimary: "#f4f5f7"
        property color textSecondary: "#9ca3af"
        property color cardBg: "#1c1c1e"
        property color cardBorder: "#484855"
        property color cardHover: "#262630"
        property color panelBg: "#80000000"

        readonly property int cardRadius: 14
        readonly property int cardPadding: 12
        readonly property int cardGap: 10
        readonly property int cardHeight: 68
        readonly property int maxVisibleItems: 3
        readonly property int itemCount: notificationModel ? notificationModel.count : 0
        readonly property bool hasNotifications: itemCount > 0

        // listContentHeight reads actual ListView contentHeight, capped at maxVisibleItems cards
        readonly property real listContentHeight: hasNotifications
            ? Math.min(listView.contentHeight, maxVisibleItems * cardHeight + (maxVisibleItems - 1) * cardGap)
            : 80


        signal clearAllRequested()

        // Deterministic color per app name
        function appColor(name) {
            if (!name || name === "") return "#6b7280";
            const colors = ["#60a5fa", "#34d399", "#f472b6", "#fbbf24", "#a78bfa", "#fb923c", "#2dd4bf", "#f87171", "#a3e635", "#818cf8"];
            let hash = 0;
            for (let i = 0; i < name.length; i++)
                hash = (hash * 31 + name.charCodeAt(i)) | 0;
            return colors[Math.abs(hash) % colors.length];
        }

        function relativeTime(timestamp) {
            if (!timestamp) return "";
            const now = new Date();
            const diff = Math.floor((now - timestamp) / 1000);
            if (diff < 60) return "now";
            if (diff < 3600) return Math.floor(diff / 60) + "m";
            if (diff < 86400) return Math.floor(diff / 3600) + "h";
            return Math.floor(diff / 86400) + "d";
        }

        Column {
            anchors.fill: parent
            spacing: 0

            // Card list — capped at maxVisibleItems, scrollable
            Item {
                clip: true
                width: parent.width
                height: root.hasNotifications ? root.listContentHeight : parent.height

                // Empty state — only rendered/visible when there are no notifications
                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    visible: !root.hasNotifications

                    // Empty icon — vector-drawn bell, respects color (emoji glyphs ignore color)
                    Canvas {
                        id: bellIcon
                        width: 28
                        height: 28
                        anchors.horizontalCenter: parent.horizontalCenter
                        property color bellColor: "#9ca3af"

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();
                            ctx.strokeStyle = bellColor;
                            ctx.fillStyle = bellColor;
                            ctx.lineWidth = 1.5;

                            // Bell body
                            ctx.beginPath();
                            ctx.arc(width / 2, height / 2 - 2, width / 3, Math.PI, 0, false);
                            ctx.lineTo(width - 6, height - 8);
                            ctx.lineTo(6, height - 8);
                            ctx.closePath();
                            ctx.fill();

                            // Clapper
                            ctx.beginPath();
                            ctx.arc(width / 2, height - 5, 2.5, 0, 2 * Math.PI);
                            ctx.fill();
                        }
                    }

                    // Title
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "No notifications"
                        color: root.textSecondary
                        font.pixelSize: 14
                        font.family: root.textFontFamily
                    }

                    // Subtitle
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "You are all caught up"
                        color: "#6b7280"
                        font.pixelSize: 11
                        font.family: root.textFontFamily
                    }
                }

                ListView {
                    id: listView
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    anchors.topMargin: 0
                    anchors.bottomMargin: 0
                    visible: root.hasNotifications
                    clip: true
                    interactive: contentHeight > height
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.notificationModel
                    currentIndex: -1
                    spacing: root.cardGap

                    // Scroll indicator when >3 notifications
                    ScrollBar.vertical: ScrollBar {
                        active: true
                        policy: ScrollBar.AsNeeded
                        width: 4

                        contentItem: Rectangle {
                            radius: 2
                            color: "#555566"
                        }

                        background: Rectangle {
                            color: "transparent"
                        }
                    }

                    delegate: Item {
                        width: listView.width
                        id: delegateItem

                        height: Math.max(48, textContent.implicitHeight + 24)
                        readonly property string notifTime: model.timestamp
                            ? root.relativeTime(model.timestamp)
                            : ""
                        readonly property string appName: model.appName !== "" ? model.appName : "Notification"
                        readonly property color accentColor: root.appColor(appName)

                        // Card surface with border
                        Rectangle {
                            anchors.fill: parent
                            radius: root.cardRadius
                            color: mouseArea.containsMouse ? root.cardHover : root.cardBg

                            // Subtle 1px border
                            Rectangle {
                                anchors.fill: parent
                                radius: root.cardRadius
                                color: "transparent"
                                border.color: root.cardBorder
                                border.width: 1
                            }


                            // Content layout
                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: root.cardPadding + 6
                                anchors.right: parent.right
                                anchors.rightMargin: root.cardPadding + 4
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 10

                                // Colored app dot
                                Rectangle {
                                    width: 8
                                    height: 8
                                    radius: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: accentColor
                                }

                                // Text area
                                Column {
                                    id: textContent
                                    width: parent.width - 8 - 10 - 30 - 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    Text {
                                        width: parent.width
                                        text: appName
                                        color: root.textSecondary
                                        font.pixelSize: 11
                                        font.family: root.textFontFamily
                                        font.weight: Font.Medium
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        width: parent.width
                                        text: model.summary + (model.body !== "" && model.body !== model.summary ? " \u2014 " + model.body : "")
                                        color: root.textPrimary
                                        font.pixelSize: 13
                                        font.family: root.textFontFamily
                                        font.weight: Font.DemiBold
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                        lineHeight: 1.2
                                    }
                                }

                                // Timestamp
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: notifTime
                                    color: root.textSecondary
                                    font.pixelSize: 10
                                    font.family: root.textFontFamily
                                    horizontalAlignment: Text.AlignRight
                                }
                            }
                        }

                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                }
            }
        }
    }
