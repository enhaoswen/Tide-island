pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

FocusScope {
    id: root

    signal closeRequested

    property bool showCondition: false
    property string iconFontFamily: ""
    property string textFontFamily: ""
    property string query: ""
    property var filteredApplications: []
    property var favoriteIds: []
    property var sortFavoriteIds: []
    property bool favoritesHydrated: false
    property int selectedIndex: -1

    readonly property int visibleApplicationCount: filteredApplications.length

    focus: showCondition
    activeFocusOnTab: true
    anchors.fill: parent
    opacity: showCondition ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: root.showCondition ? 220 : 120
            easing.type: Easing.InOutQuad
        }
    }

    function searchableText(entry) {
        if (!entry)
            return "";

        return [
            entry.name,
            entry.genericName,
            entry.comment,
            entry.id,
            entry.startupClass,
            entry.categories ? entry.categories.join(" ") : "",
            entry.keywords ? entry.keywords.join(" ") : ""
        ].join(" ").toLocaleLowerCase();
    }

    function isFavorite(entry) {
        return !!entry && root.favoriteIds.indexOf(String(entry.id)) >= 0;
    }

    function isSortFavorite(entry) {
        return !!entry && root.sortFavoriteIds.indexOf(String(entry.id)) >= 0;
    }

    function favoriteShortcutNumber(entry) {
        if (!entry)
            return 0;

        const entryId = String(entry.id);
        let shortcutNumber = 0;
        for (let index = 0; index < root.filteredApplications.length; ++index) {
            const candidate = root.filteredApplications[index];
            if (!root.isFavorite(candidate))
                continue;

            ++shortcutNumber;
            if (String(candidate.id) === entryId)
                return shortcutNumber;
        }
        return 0;
    }

    function shortcutNumberForKeyEvent(event) {
        const blockedModifiers = Qt.ControlModifier | Qt.AltModifier
            | Qt.MetaModifier | Qt.ShiftModifier;
        if (event.isAutoRepeat || (event.modifiers & blockedModifiers) !== 0)
            return 0;
        if (event.key < Qt.Key_1 || event.key > Qt.Key_9)
            return 0;
        return event.key - Qt.Key_0;
    }

    function launchFavoriteShortcut(event) {
        if (root.query !== "")
            return false;

        const requestedNumber = root.shortcutNumberForKeyEvent(event);
        if (requestedNumber === 0)
            return false;

        let shortcutNumber = 0;
        for (let index = 0; index < root.filteredApplications.length; ++index) {
            const entry = root.filteredApplications[index];
            if (!root.isFavorite(entry))
                continue;

            ++shortcutNumber;
            if (shortcutNumber === requestedNumber) {
                root.launchApplication(entry);
                return true;
            }
        }
        return false;
    }

    function applyFavorites(stored, adoptSortOrder) {
        const nextFavorites = [];
        const seen = ({});

        if (Array.isArray(stored)) {
            for (let index = 0; index < stored.length; ++index) {
                const entryId = String(stored[index] || "").trim();
                if (entryId === "" || seen[entryId])
                    continue;
                seen[entryId] = true;
                nextFavorites.push(entryId);
            }
        }

        root.favoriteIds = nextFavorites;
        if (adoptSortOrder && !root.favoritesHydrated)
            root.sortFavoriteIds = nextFavorites.slice();
        root.favoritesHydrated = true;
        root.rebuildApplications();
    }

    function loadFavoritesFromDisk(adoptSortOrder) {
        let stored = [];
        try {
            const contents = favoritesFile.text();
            if (contents.trim() !== "") {
                const parsed = JSON.parse(contents);
                stored = parsed && Array.isArray(parsed.favoriteIds) ? parsed.favoriteIds : [];
            }
        } catch (error) {
            stored = [];
        }
        root.applyFavorites(stored, adoptSortOrder);
    }

    function toggleFavorite(entry) {
        if (!entry)
            return;

        if (!root.favoritesHydrated) {
            favoritesFile.waitForJob();
            root.loadFavoritesFromDisk(true);
        }

        const entryId = String(entry.id);
        const nextFavorites = root.favoriteIds.slice();
        const existingIndex = nextFavorites.indexOf(entryId);
        if (existingIndex >= 0)
            nextFavorites.splice(existingIndex, 1);
        else
            nextFavorites.push(entryId);

        root.favoriteIds = nextFavorites;
        favoriteStore.favoriteIds = nextFavorites;
        favoritesFile.writeAdapter();
    }

    function rebuildApplications() {
        const needle = root.query.trim().toLocaleLowerCase();
        const available = DesktopEntries.applications.values;
        const nextApplications = [];

        for (let index = 0; index < available.length; ++index) {
            const entry = available[index];
            if (!entry || entry.noDisplay || String(entry.name).trim() === "")
                continue;
            if (needle !== "" && root.searchableText(entry).indexOf(needle) < 0)
                continue;
            nextApplications.push(entry);
        }

        nextApplications.sort((left, right) => {
            const leftFavorite = root.isSortFavorite(left);
            const rightFavorite = root.isSortFavorite(right);
            if (leftFavorite !== rightFavorite)
                return leftFavorite ? -1 : 1;
            return String(left.name).localeCompare(String(right.name));
        });
        root.filteredApplications = nextApplications;
        root.selectedIndex = nextApplications.length > 0 ? 0 : -1;
        if (!appGrid)
            return;
        appGrid.currentIndex = root.selectedIndex;
        if (root.selectedIndex >= 0)
            appGrid.positionViewAtIndex(root.selectedIndex, GridView.Beginning);
    }

    function grabKeyboardFocus() {
        root.forceActiveFocus();
        searchInput.forceActiveFocus();
    }

    function moveSelection(offset) {
        const count = root.visibleApplicationCount;
        if (count <= 0)
            return;

        root.selectedIndex = (root.selectedIndex + offset + count) % count;
        appGrid.currentIndex = root.selectedIndex;
        appGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain);
    }

    function launchApplication(entry) {
        if (!entry)
            return;

        const desktopCommand = [];
        for (let index = 0; index < entry.command.length; ++index)
            desktopCommand.push(String(entry.command[index]));

        if (desktopCommand.length === 0) {
            entry.execute();
        } else {
            const scopedCommand = [
                "systemd-run",
                "--user",
                "--scope",
                "--quiet",
                "--collect",
                "--slice=app.slice",
                "--expand-environment=no"
            ];
            const workingDirectory = String(entry.workingDirectory || "");
            if (workingDirectory !== "")
                scopedCommand.push("--working-directory=" + workingDirectory);
            scopedCommand.push("--");
            for (let index = 0; index < desktopCommand.length; ++index)
                scopedCommand.push(desktopCommand[index]);

            // Keep launched applications outside tide-island.service so a
            // service restart cannot kill their child process trees.
            Quickshell.execDetached(scopedCommand);
        }
        root.closeRequested();
    }

    function launchSelected() {
        if (root.selectedIndex < 0 || root.selectedIndex >= root.visibleApplicationCount)
            return;
        root.launchApplication(root.filteredApplications[root.selectedIndex]);
    }

    onShowConditionChanged: {
        if (showCondition) {
            sortFavoriteIds = favoriteIds.slice();
            searchInput.text = "";
            query = "";
            rebuildApplications();
            focusTimer.restart();
        }
    }

    Component.onCompleted: rebuildApplications()

    Connections {
        target: DesktopEntries

        function onApplicationsChanged() {
            root.rebuildApplications();
        }
    }

    FileView {
        id: favoritesFile
        path: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation)
            + "/tide-island/application-launcher.json"
        preload: true
        watchChanges: true
        atomicWrites: true
        printErrors: false

        JsonAdapter {
            id: favoriteStore
            property var favoriteIds: []
        }

        onLoaded: root.loadFavoritesFromDisk(true)
    }

    Timer {
        id: focusTimer
        interval: 0
        repeat: false
        onTriggered: root.grabKeyboardFocus()
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            root.closeRequested();
            event.accepted = true;
        } else if (root.launchFavoriteShortcut(event)) {
            event.accepted = true;
        }
    }

    Column {
        anchors.fill: parent
        anchors.topMargin: 15
        anchors.bottomMargin: 12
        anchors.leftMargin: 22
        anchors.rightMargin: 22
        spacing: 10

        Item {
            width: parent.width
            height: 46

            Rectangle {
                id: searchField
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(650, parent.width - 120)
                height: parent.height
                radius: 17
                color: searchInput.activeFocus ? "#17181c" : "#111216"
                border.width: 1
                border.color: searchInput.activeFocus ? "#3d3f47" : "#292a30"

                Behavior on color { ColorAnimation { duration: 140 } }
                Behavior on border.color { ColorAnimation { duration: 140 } }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uf002"
                    color: searchInput.activeFocus ? "#d1d1d6" : "#8e8e93"
                    font.family: root.iconFontFamily
                    font.pixelSize: 15
                }

                TextInput {
                    id: searchInput
                    anchors.left: parent.left
                    anchors.leftMargin: 45
                    anchors.right: parent.right
                    anchors.rightMargin: root.query === "" ? 16 : 42
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#f5f5f7"
                    selectionColor: "#0a84ff"
                    selectedTextColor: "#ffffff"
                    font.family: root.textFontFamily
                    font.pixelSize: 15
                    clip: true
                    selectByMouse: true
                    text: ""

                    onTextChanged: {
                        if (root.query !== text)
                            root.query = text;
                        root.rebuildApplications();
                    }

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            root.closeRequested();
                            event.accepted = true;
                        } else if (root.launchFavoriteShortcut(event)) {
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Right && text === "") {
                            root.moveSelection(1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                            root.moveSelection(1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Left && text === "") {
                            root.moveSelection(-1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
                            root.moveSelection(-1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.launchSelected();
                            event.accepted = true;
                        }
                    }
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 11
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.query !== ""
                    width: 24
                    height: 24
                    radius: 12
                    color: clearSearchArea.containsMouse ? "#34353b" : "#24252a"

                    Text {
                        anchors.centerIn: parent
                        text: "\uf00d"
                        color: "#a5a6ac"
                        font.family: root.iconFontFamily
                        font.pixelSize: 10
                    }

                    MouseArea {
                        id: clearSearchArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            searchInput.text = "";
                            searchInput.forceActiveFocus();
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    z: -1
                    onClicked: searchInput.forceActiveFocus()
                }
            }

        }

        GridView {
            id: appGrid
            width: parent.width
            height: parent.height - y
            model: root.filteredApplications
            cellWidth: 126
            cellHeight: height
            flow: GridView.FlowTopToBottom
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickDeceleration: 1800
            keyNavigationEnabled: false

            delegate: Item {
                id: appDelegate
                required property var modelData
                required property int index

                readonly property var entry: modelData
                readonly property bool selected: index === root.selectedIndex
                readonly property bool favorite: root.isFavorite(entry)
                readonly property int favoriteNumber: root.favoriteShortcutNumber(entry)

                width: appGrid.cellWidth
                height: appGrid.cellHeight

                Item {
                    z: 2
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 8
                    width: parent.width - 10
                    height: 124
                    scale: appArea.pressed ? 0.95 : (appDelegate.selected || appArea.containsMouse ? 1.035 : 1)

                    Behavior on scale {
                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                    }

                    Item {
                        id: iconArea
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 76
                        height: 76

                        IconImage {
                            id: appIcon
                            anchors.centerIn: parent
                            width: 64
                            height: 64
                            source: Quickshell.iconPath(appDelegate.entry.icon, "application-x-executable")
                            asynchronous: true
                            mipmap: true
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: appIcon.status === Image.Error
                            text: String(appDelegate.entry.name).charAt(0).toLocaleUpperCase()
                            color: "#f5f5f7"
                            font.family: root.textFontFamily
                            font.pixelSize: 24
                            font.weight: Font.DemiBold
                        }

                        Text {
                            anchors.top: parent.top
                            anchors.topMargin: -2
                            anchors.left: parent.left
                            anchors.leftMargin: -2
                            visible: appDelegate.favoriteNumber > 0
                            text: appDelegate.favoriteNumber
                            color: "#a5a6ac"
                            font.family: root.textFontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                    }

                    Text {
                        anchors.top: iconArea.bottom
                        anchors.topMargin: 10
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width - 8
                        text: appDelegate.entry.name
                        color: appDelegate.selected ? "#f5f5f7" : "#d0d1d5"
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        font.family: root.textFontFamily
                        font.pixelSize: 12
                        font.weight: appDelegate.selected ? Font.Medium : Font.Normal
                    }

                    FavoriteStar {
                        anchors.top: iconArea.top
                        anchors.topMargin: -2
                        anchors.right: iconArea.right
                        anchors.rightMargin: -4
                        active: appDelegate.favorite
                        hovered: delegateHover.hovered
                        onToggleRequested: root.toggleFavorite(appDelegate.entry)
                    }
                }

                MouseArea {
                    id: appArea
                    z: 1
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: {
                        root.selectedIndex = appDelegate.index;
                        appGrid.currentIndex = appDelegate.index;
                    }
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton)
                            root.toggleFavorite(appDelegate.entry);
                        else
                            root.launchApplication(appDelegate.entry);
                    }
                }

                HoverHandler {
                    id: delegateHover
                }
            }

            Text {
                anchors.centerIn: parent
                visible: root.visibleApplicationCount === 0
                text: root.query === "" ? "没有找到可启动的应用" : "没有找到“" + root.query + "”"
                color: "#696b72"
                font.family: root.textFontFamily
                font.pixelSize: 13
            }
        }
    }
}
