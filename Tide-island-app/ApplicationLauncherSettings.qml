import QtCore
import QtQuick
import TideIsland 1.0

PagePanel {
    id: root

    property var favorites: []
    property string statusText: ""
    property bool statusIsError: false

    function refreshFavorites() {
        favorites = backend.applicationLauncherFavoriteEntries()
        statusText = ""
        statusIsError = false
    }

    function favoriteIdsExcept(removedId) {
        const ids = []
        for (let i = 0; i < favorites.length; ++i) {
            if (favorites[i].id !== removedId)
                ids.push(favorites[i].id)
        }
        return ids
    }

    function saveFavorites(ids, successMessage) {
        if (backend.saveApplicationLauncherFavorites(ids)) {
            favorites = backend.applicationLauncherFavoriteEntries()
            statusText = successMessage
            statusIsError = false
        } else {
            statusText = backend.errorString
            statusIsError = true
        }
    }

    function displayPath(path) {
        const home = StandardPaths.writableLocation(StandardPaths.HomeLocation)
        return path.indexOf(home) === 0 ? "~" + path.slice(home.length) : path
    }

    onVisibleChanged: {
        if (visible)
            refreshFavorites()
    }

    Component.onCompleted: refreshFavorites()

    Flickable {
        id: scroller

        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: content.height
        boundsBehavior: Flickable.StopAtBounds
        boundsMovement: Flickable.StopAtBounds

        Item {
            id: content

            width: scroller.width
            height: pageColumn.implicitHeight + 100

            Column {
                id: pageColumn

                x: 30
                y: 50
                width: Math.max(300, parent.width - 70)
                spacing: 26

                Text {
                    text: "Application Launcher"
                    color: Theme.textColor
                    font.family: Theme.titleFontFamily
                    font.pixelSize: 30
                }

                Rectangle {
                    width: parent.width
                    height: 112
                    radius: 10
                    color: Theme.cardBgColor
                    border.width: 1
                    border.color: Theme.cardBorderColor

                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: 20
                        anchors.right: openLauncherButton.left
                        anchors.rightMargin: 22
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Text {
                            width: parent.width
                            text: "Open with Super + /"
                            color: Theme.textColor
                            font.family: Theme.textFontFamily
                            font.pixelSize: 17
                            font.weight: Font.DemiBold
                        }

                        Text {
                            width: parent.width
                            text: "Search installed apps, then hover an app and click its star — or right-click it — to add a favorite. Favorite order updates the next time the launcher opens."
                            color: Theme.secondaryTextColor
                            wrapMode: Text.WordWrap
                            font.family: Theme.textFontFamily
                            font.pixelSize: 13
                        }
                    }

                    ActionButton {
                        id: openLauncherButton

                        anchors.right: parent.right
                        anchors.rightMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        width: 124
                        text: "Open Launcher"
                        onTriggered: {
                            if (!backend.toggleApplicationLauncher()) {
                                root.statusText = backend.errorString
                                root.statusIsError = true
                            }
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: 36

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Favorites"
                        color: Theme.textColor
                        font.family: Theme.titleFontFamily
                        font.pixelSize: 23
                    }

                    ActionButton {
                        id: clearButton

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 92
                        text: "Clear All"
                        muted: true
                        actionEnabled: root.favorites.length > 0
                        onTriggered: root.saveFavorites([], "All favorites removed")
                    }

                    ActionButton {
                        anchors.right: clearButton.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 88
                        text: "Refresh"
                        muted: true
                        onTriggered: root.refreshFavorites()
                    }
                }

                Text {
                    width: parent.width
                    text: root.favorites.length === 0
                        ? "No favorite apps yet. Add them from the launcher."
                        : root.favorites.length + (root.favorites.length === 1 ? " favorite app" : " favorite apps")
                    color: Theme.subtleTextColor
                    font.family: Theme.textFontFamily
                    font.pixelSize: 14
                }

                Rectangle {
                    width: parent.width
                    height: root.favorites.length > 0 ? root.favorites.length * 62 + 16 : 88
                    radius: 10
                    color: "transparent"
                    border.width: 2
                    border.color: Theme.splitLineColor

                    Text {
                        anchors.centerIn: parent
                        visible: root.favorites.length === 0
                        text: "Your starred apps will appear here"
                        color: Theme.subtleTextColor
                        font.family: Theme.textFontFamily
                        font.pixelSize: 14
                    }

                    Column {
                        anchors.top: parent.top
                        anchors.topMargin: 8
                        anchors.left: parent.left
                        anchors.leftMargin: 18
                        anchors.right: parent.right
                        anchors.rightMargin: 18

                        Repeater {
                            model: root.favorites

                            Item {
                                id: favoriteRow

                                required property var modelData
                                required property int index

                                width: parent.width
                                height: 62

                                Text {
                                    anchors.left: parent.left
                                    anchors.right: removeButton.left
                                    anchors.rightMargin: 18
                                    anchors.top: parent.top
                                    anchors.topMargin: 10
                                    text: favoriteRow.modelData.name
                                    color: Theme.textColor
                                    elide: Text.ElideRight
                                    font.family: Theme.textFontFamily
                                    font.pixelSize: 16
                                    font.weight: Font.DemiBold
                                }

                                Text {
                                    anchors.left: parent.left
                                    anchors.right: removeButton.left
                                    anchors.rightMargin: 18
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 9
                                    text: favoriteRow.modelData.id
                                    color: Theme.subtleTextColor
                                    elide: Text.ElideMiddle
                                    font.family: Theme.textFontFamily
                                    font.pixelSize: 12
                                }

                                ActionButton {
                                    id: removeButton

                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 84
                                    text: "Remove"
                                    muted: true
                                    onTriggered: root.saveFavorites(
                                        root.favoriteIdsExcept(favoriteRow.modelData.id),
                                        "Removed " + favoriteRow.modelData.name)
                                }

                                Rectangle {
                                    visible: favoriteRow.index < root.favorites.length - 1
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: 1
                                    color: Theme.splitLineColor
                                }
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    text: "Stored in " + root.displayPath(backend.applicationLauncherFavoritesPath())
                    color: Theme.subtleTextColor
                    elide: Text.ElideMiddle
                    font.family: Theme.textFontFamily
                    font.pixelSize: 12
                }

                Text {
                    width: parent.width
                    visible: root.statusText.length > 0
                    text: root.statusText
                    color: root.statusIsError ? "#8f2f16" : Theme.selectedColor
                    wrapMode: Text.WordWrap
                    font.family: Theme.textFontFamily
                    font.pixelSize: 13
                }
            }
        }
    }

    component ActionButton: Rectangle {
        id: button

        property string text: ""
        property bool muted: false
        property bool actionEnabled: true
        signal triggered()

        height: 34
        radius: 8
        opacity: actionEnabled ? 1 : 0.45
        color: muted
            ? (buttonMouse.containsMouse && actionEnabled ? Theme.componentBgColor : Theme.mutedButtonColor)
            : (buttonMouse.containsMouse && actionEnabled ? Theme.buttonHoverColor : Theme.buttonColor)

        Text {
            anchors.centerIn: parent
            text: button.text
            color: button.muted ? Theme.mutedButtonTextColor : Theme.buttonTextColor
            font.family: Theme.textFontFamily
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }

        MouseArea {
            id: buttonMouse

            anchors.fill: parent
            enabled: button.actionEnabled
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: button.triggered()
        }
    }
}
