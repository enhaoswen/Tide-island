import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    signal closeRequested

    property bool showCondition: false
    property string iconFontFamily: ""
    property string textFontFamily: ""
    property bool historyLoaded: false
    property int highlightedIndex: -1
    property bool keyboardNavActive: false

    readonly property string thumbCacheDir: "/tmp/tide-island-cliphist"

    focus: true
    anchors.fill: parent
    opacity: showCondition ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: showCondition ? 220 : 100
            easing.type: Easing.InOutQuad
        }
    }

    onShowConditionChanged: {
        if (showCondition) {
            searchInput.text = "";
            highlightedIndex = -1;
            keyboardNavActive = false;
            historyLoaded = false;
            allEntries.clear();
            shownEntries.clear();
            ensureCacheDirProcess.running = true;
            focusTimer.restart();
        } else {
            copyProcess.running = false;
        }
    }

    Timer {
        id: focusTimer
        interval: 80
        repeat: false
        onTriggered: {
            root.forceActiveFocus();
            searchInputFocusTimer.restart();
        }
    }
    Timer {
        id: searchInputFocusTimer
        interval: 40
        repeat: false
        onTriggered: searchInput.forceActiveFocus()
    }

    ListModel {
        id: allEntries
    }
    ListModel {
        id: shownEntries
    }

    function filterEntries(query) {
        shownEntries.clear();
        highlightedIndex = -1;
        const q = query.toLowerCase().trim();

        let count = 0;
        const limit = 60;
        for (let i = 0; i < allEntries.count && count < limit; i++) {
            const e = allEntries.get(i);
            if (!q || e.preview.toLowerCase().includes(q)) {
                shownEntries.append({
                    entryId: e.entryId,
                    preview: e.preview,
                    isImage: e.isImage,
                    thumbPath: e.thumbPath
                });
                count++;
            }
        }
    }

    function moveHighlight(delta) {
        if (shownEntries.count === 0)
            return;
        root.keyboardNavActive = true;
        let next = highlightedIndex + delta;
        if (next < 0)
            next = shownEntries.count - 1;
        if (next >= shownEntries.count)
            next = 0;
        highlightedIndex = next;
        resultsList.positionViewAtIndex(next, ListView.Contain);
    }

    Process {
        id: ensureCacheDirProcess
        command: ["mkdir", "-p", root.thumbCacheDir]
        onExited: scanProcess.running = true
    }

    Process {
        id: scanProcess
        command: ["cliphist", "list"]
        stdout: SplitParser {
            onRead: line => {
                const tabIndex = line.indexOf('\t');
                if (tabIndex === -1)
                    return;
                const id = line.substring(0, tabIndex);
                const rest = line.substring(tabIndex + 1);
                const isImage = /^\[\[\s*binary data/.test(rest);
                allEntries.append({
                    entryId: id,
                    preview: rest,
                    isImage: isImage,
                    thumbPath: ""
                });
            }
        }
        onExited: {
            root.historyLoaded = true;
            root.filterEntries(searchInput.text);
            thumbDecodeQueue.startIfIdle();
        }
    }

    QtObject {
        id: thumbDecodeQueue
        property var pending: []
        property bool running: false

        function enqueue(entryId) {
            if (pending.indexOf(entryId) !== -1)
                return;
            pending.push(entryId);
            startIfIdle();
        }

        function startIfIdle() {
            if (running || pending.length === 0)
                return;
            running = true;
            const id = pending.shift();
            thumbDecodeProcess.entryId = id;
            thumbDecodeProcess.targetPath = root.thumbCacheDir + "/" + id + ".png";
            thumbDecodeProcess.running = true;
        }
    }

    Process {
        id: thumbDecodeProcess
        property string entryId: ""
        property string targetPath: ""
        command: ["bash", "-c", "cliphist decode " + thumbDecodeProcess.entryId + " > '" + thumbDecodeProcess.targetPath + "'"]
        onExited: exitCode => {
            if (exitCode === 0) {
                for (let i = 0; i < allEntries.count; i++) {
                    if (allEntries.get(i).entryId === thumbDecodeProcess.entryId) {
                        allEntries.setProperty(i, "thumbPath", thumbDecodeProcess.targetPath);
                        break;
                    }
                }
                for (let j = 0; j < shownEntries.count; j++) {
                    if (shownEntries.get(j).entryId === thumbDecodeProcess.entryId) {
                        shownEntries.setProperty(j, "thumbPath", thumbDecodeProcess.targetPath);
                        break;
                    }
                }
            }
            thumbDecodeQueue.running = false;
            thumbDecodeQueue.startIfIdle();
        }
    }

    function requestThumb(entryId) {
        thumbDecodeQueue.enqueue(entryId);
    }

    Process {
        id: copyProcess
        property bool pendingClose: false
        onExited: {
            running = false;
            if (pendingClose) {
                pendingClose = false;
                root.closeRequested();
            }
        }
    }

    function selectEntry(entryId) {
        if (copyProcess.running)
            copyProcess.running = false;
        copyProcess.pendingClose = true;
        copyProcess.command = ["bash", "-c", "cliphist decode " + entryId + " | wl-copy"];
        copyProcess.running = true;
    }

    Process {
        id: deleteProcess
        property string targetLine: ""
        command: ["cliphist", "delete-query", deleteProcess.targetLine]
        onExited: {
            scanProcess.running = false;
            allEntries.clear();
            shownEntries.clear();
            root.historyLoaded = false;
            scanProcess.running = true;
        }
    }

    function deleteEntry(entryId, preview) {
        deleteProcess.targetLine = entryId + "\t" + preview;
        deleteProcess.running = true;
    }

    Process {
        id: wipeProcess
        command: ["cliphist", "wipe"]
        onExited: {
            allEntries.clear();
            shownEntries.clear();
            highlightedIndex = -1;
            root.historyLoaded = true;
        }
    }

    function clearAll() {
        wipeProcess.running = true;
    }

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Down:
        case Qt.Key_Tab:
            moveHighlight(1);
            event.accepted = true;
            break;
        case Qt.Key_Up:
        case Qt.Key_Backtab:
            moveHighlight(-1);
            event.accepted = true;
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (highlightedIndex >= 0 && highlightedIndex < shownEntries.count)
                root.selectEntry(shownEntries.get(highlightedIndex).entryId);
            else if (shownEntries.count > 0)
                root.selectEntry(shownEntries.get(0).entryId);
            event.accepted = true;
            break;
        case Qt.Key_Delete:
            if (highlightedIndex >= 0 && highlightedIndex < shownEntries.count) {
                const e = shownEntries.get(highlightedIndex);
                root.deleteEntry(e.entryId, e.preview);
            }
            event.accepted = true;
            break;
        case Qt.Key_Backspace:
            if (event.modifiers & Qt.ControlModifier) {
                root.clearAll();
                event.accepted = true;
            }
            break;
        case Qt.Key_Escape:
            root.closeRequested();
            event.accepted = true;
            break;
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        Item {
            width: parent.width
            height: 34

            Text {
                id: searchIcon
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf0ea"
                font.family: root.iconFontFamily
                font.pixelSize: 12
                color: searchInput.activeFocus ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(1, 1, 1, 0.28)
                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }
            }

            Text {
                anchors.left: searchIcon.right
                anchors.leftMargin: 8
                anchors.right: clearAllButton.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: "Search clipboard history…"
                color: Qt.rgba(1, 1, 1, 0.28)
                font.pixelSize: 13
                font.family: root.textFontFamily
                visible: searchInput.text === "" && !searchInput.activeFocus
            }

            TextInput {
                id: searchInput
                anchors.left: searchIcon.right
                anchors.leftMargin: 8
                anchors.right: clearAllButton.left
                anchors.rightMargin: 8
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                verticalAlignment: TextInput.AlignVCenter
                color: "white"
                font.pixelSize: 13
                font.family: root.textFontFamily
                clip: true
                onTextChanged: root.filterEntries(text)
            }

            Rectangle {
                id: clearAllButton
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: clearAllLabel.implicitWidth + 16
                height: 24
                radius: 8
                color: clearAllMouseArea.containsMouse ? Qt.rgba(1, 0.35, 0.35, 0.18) : Qt.rgba(1, 1, 1, 0.06)
                visible: allEntries.count > 0

                Behavior on color {
                    ColorAnimation {
                        duration: 100
                    }
                }

                Text {
                    id: clearAllLabel
                    anchors.centerIn: parent
                    text: "Clear all"
                    color: clearAllMouseArea.containsMouse ? "#fca5a5" : Qt.rgba(1, 1, 1, 0.45)
                    font.pixelSize: 11
                    font.family: root.textFontFamily
                    font.weight: Font.Medium
                    Behavior on color {
                        ColorAnimation {
                            duration: 100
                        }
                    }
                }

                MouseArea {
                    id: clearAllMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.clearAll()
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Qt.rgba(1, 1, 1, 0.10)
        }

        Item {
            width: parent.width
            height: parent.height - 34 - 8 - 1 - 8

            Text {
                anchors.centerIn: parent
                visible: !root.historyLoaded || shownEntries.count === 0
                text: !root.historyLoaded ? "Loading…" : "No results"
                color: Qt.rgba(1, 1, 1, 0.25)
                font.pixelSize: 12
                font.family: root.textFontFamily
            }

            ListView {
                id: resultsList
                anchors.fill: parent
                model: shownEntries
                spacing: 2
                clip: true
                keyNavigationEnabled: false

                delegate: Rectangle {
                    id: rowDelegate
                    width: ListView.view.width
                    height: 36
                    radius: 10
                    color: (index === root.highlightedIndex) ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                    Behavior on color {
                        ColorAnimation {
                            duration: 80
                        }
                    }

                    Component.onCompleted: {
                        if (model.isImage && model.thumbPath === "")
                            root.requestThumb(model.entryId);
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: 2
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3
                        height: parent.height * 0.55
                        radius: 1.5
                        color: model.isImage ? "#a78bfa" : "#60a5fa"
                        opacity: (index === root.highlightedIndex) ? 1 : 0
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 100
                            }
                        }
                    }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 0

                        Item {
                            width: 28
                            height: parent.height

                            Image {
                                id: thumbImage
                                anchors.centerIn: parent
                                width: 24
                                height: 24
                                source: model.isImage && model.thumbPath !== "" ? ("file://" + model.thumbPath) : ""
                                visible: model.isImage && status === Image.Ready
                                fillMode: Image.PreserveAspectCrop
                                smooth: true
                                mipmap: true
                                sourceSize: Qt.size(48, 48)
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: !model.isImage || thumbImage.status !== Image.Ready
                                text: model.isImage ? "\uf03e" : "\uf0ea"
                                font.family: root.iconFontFamily
                                font.pixelSize: 13
                                color: Qt.rgba(1, 1, 1, 0.30)
                            }
                        }

                        Item {
                            width: 8
                            height: 1
                        }

                        Text {
                            width: parent.width - 28 - 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: model.isImage ? "Image (" + model.preview.replace(/^\[\[\s*binary data\s*/, "").replace(/\s*\]\]$/, "") + ")" : model.preview
                            color: index === root.highlightedIndex ? "white" : Qt.rgba(1, 1, 1, 0.80)
                            font.pixelSize: 13
                            font.family: root.textFontFamily
                            font.weight: index === root.highlightedIndex ? Font.SemiBold : Font.Medium
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                            Behavior on color {
                                ColorAnimation {
                                    duration: 80
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton)
                                root.deleteEntry(model.entryId, model.preview);
                            else
                                root.selectEntry(model.entryId);
                        }
                        onPositionChanged: {
                            root.keyboardNavActive = false;
                            root.highlightedIndex = index;
                        }
                        onEntered: {
                            if (!root.keyboardNavActive)
                                root.highlightedIndex = index;
                        }
                    }
                }
            }
        }
    }
}
