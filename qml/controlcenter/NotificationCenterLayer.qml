import QtQuick
import QtQuick.Shapes
import IslandBackend
import "../island"

Item {
    id: notificationCenter

    signal clearAllRequested()

    property var notificationModel: null
    property string iconFontFamily: userConfig.iconFontFamily
    property string textFontFamily: userConfig.textFontFamily
    property string heroFontFamily: userConfig.heroFontFamily

    readonly property bool hasNotifications: notificationModel && notificationModel.count > 0
    readonly property real contentHeight: 218
    readonly property real verticalPadding: 10
    readonly property real horizontalPadding: 22

    NotificationHistory {
        id: notificationHistory

        anchors.fill: parent
        anchors.topMargin: notificationCenter.verticalPadding
        anchors.bottomMargin: notificationCenter.verticalPadding
        anchors.leftMargin: notificationCenter.horizontalPadding
        anchors.rightMargin: notificationCenter.horizontalPadding
        notificationModel: notificationCenter.notificationModel
        iconFontFamily: notificationCenter.iconFontFamily
        textFontFamily: notificationCenter.textFontFamily
        heroFontFamily: notificationCenter.heroFontFamily
    }

    // Keep the action inside the first notification card so it does not create
    // a separate black toolbar above the list.
    Item {
        id: clearButton

        z: 100
        opacity: notificationCenter.hasNotifications ? 1 : 0.5
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: notificationCenter.verticalPadding + 3
        anchors.rightMargin: notificationCenter.horizontalPadding + 2
        width: 24
        height: 24

        Behavior on opacity {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }

        Item {
            id: trashIcon

            anchors.centerIn: parent
            width: 24
            height: 24
            scale: clearMouse.pressed ? 0.70 : 0.75

            Behavior on scale {
                NumberAnimation {
                    duration: 280
                    easing.type: Easing.OutCubic
                }
            }

            Shape {
                id: trashBody

                x: 0
                y: clearMouse.containsMouse ? 1 : 0
                width: parent.width
                height: parent.height
                preferredRendererType: Shape.CurveRenderer

                Behavior on y {
                    NumberAnimation {
                        duration: 360
                        easing.type: Easing.OutCubic
                    }
                }

                ShapePath {
                    fillColor: StyleTokens.transparent
                    strokeColor: StyleTokens.textDim
                    strokeWidth: 1.8
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin

                    PathSvg {
                        path: "M5 6v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V6 M10 11v6 M14 11v6"
                    }
                }
            }

            Item {
                id: trashLid

                x: 0
                transformOrigin: Item.Right
                y: clearMouse.containsMouse ? -1.5 : 0
                width: parent.width
                height: parent.height
                rotation: clearMouse.containsMouse ? 12 : 0

                Behavior on y {
                    NumberAnimation {
                        duration: 360
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on rotation {
                    NumberAnimation {
                        duration: 360
                        easing.type: Easing.OutCubic
                    }
                }

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        fillColor: StyleTokens.transparent
                        strokeColor: StyleTokens.textDim
                        strokeWidth: 1.8
                        capStyle: ShapePath.RoundCap
                        joinStyle: ShapePath.RoundJoin

                        PathSvg {
                            path: "M3 6h18 M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"
                        }
                    }
                }
            }
        }

        MouseArea {
            id: clearMouse

            anchors.fill: parent
            enabled: notificationCenter.hasNotifications
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: notificationCenter.clearAllRequested()
        }
    }
}
