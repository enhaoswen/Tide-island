import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    signal closeRequested

    property bool showCondition: false
    property string iconFontFamily: ""
    property string textFontFamily: ""
    property bool appsLoaded: false
    property int highlightedIndex: -1

    // Edit these lists to personalise.
    property var favouriteApps: ["Brave", "kitty", "Spotify", "Neovim", "Visual Studio Code"]
    property var hiddenApps: ["Avahi Zeroconf Browser", "Avahi SSH Server Browser", "Avahi VNC Server Browser", "Bluetooth Adapters", "A Photo Tool (Libre)"]

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
            filterApps("");
            highlightedIndex = -1;
            if (!appsLoaded)
                scanProcess.running = true;
            focusTimer.restart();
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
        id: allApps
    }
    ListModel {
        id: shownApps
    }

    function isFavourite(name) {
        for (let i = 0; i < root.favouriteApps.length; i++)
            if (root.favouriteApps[i].toLowerCase() === name.toLowerCase())
                return true;
        return false;
    }
    function isHidden(name) {
        for (let i = 0; i < root.hiddenApps.length; i++)
            if (root.hiddenApps[i].toLowerCase() === name.toLowerCase())
                return true;
        return false;
    }

    function filterApps(query) {
        shownApps.clear();
        highlightedIndex = -1;
        const q = query.toLowerCase().trim();

        if (!q) {
            for (let i = 0; i < allApps.count; i++) {
                const a = allApps.get(i);
                if (isFavourite(a.appName) && !isHidden(a.appName))
                    shownApps.append({
                        appName: a.appName,
                        appExec: a.appExec,
                        appIcon: a.appIcon,
                        section: "favourites"
                    });
            }
        }

        let count = 0;
        const limit = q ? 14 : 10;
        for (let i = 0; i < allApps.count && count < limit; i++) {
            const a = allApps.get(i);
            if (isHidden(a.appName))
                continue;
            if (!q && isFavourite(a.appName))
                continue;
            if (!q || a.appName.toLowerCase().includes(q)) {
                shownApps.append({
                    appName: a.appName,
                    appExec: a.appExec,
                    appIcon: a.appIcon,
                    section: "all"
                });
                count++;
            }
        }
    }

    function moveHighlight(delta) {
        if (shownApps.count === 0)
            return;
        let next = highlightedIndex + delta;
        if (next < 0)
            next = shownApps.count - 1;
        if (next >= shownApps.count)
            next = 0;
        highlightedIndex = next;
        resultsList.positionViewAtIndex(next, ListView.Contain);
    }

    // ── Scanner ───────────────────────────────────────────────────────────────
    Process {
        id: scanProcess
        command: ["python3", "-c", "import glob,os,configparser\n" + "def find_icon(name):\n" + "    if not name: return ''\n" + "    if os.path.isabs(name) and os.path.isfile(name): return name\n" + "    base=os.path.expanduser('~/.local/share/icons')\n" + "    themes=['MacTahoe','MacTahoe-dark','MacTahoe-light','hicolor','Papirus','breeze']\n" + "    cats=['apps/scalable','apps/32','apps/22','apps/16']\n" + "    exts=['.svg','.png','.xpm']\n" + "    for t in themes:\n" + "        for c in cats:\n" + "            for e in exts:\n" + "                p=os.path.join(base,t,c,name+e)\n" + "                if os.path.isfile(p): return p\n" + "    for b in ['/usr/share/icons/hicolor/scalable/apps','/usr/share/icons/hicolor/48x48/apps','/usr/share/pixmaps']:\n" + "        for e in exts:\n" + "            p=os.path.join(b,name+e)\n" + "            if os.path.isfile(p): return p\n" + "    return ''\n" + "apps=[]\n" + "paths=glob.glob('/usr/share/applications/*.desktop')\n" + "paths+=glob.glob(os.path.expanduser('~/.local/share/applications/*.desktop'))\n" + "paths+=glob.glob('/var/lib/flatpak/exports/share/applications/*.desktop')\n" + "paths+=glob.glob(os.path.expanduser('~/.local/share/flatpak/exports/share/applications/*.desktop'))\n" + "seen=set()\n" + "for f in paths:\n" + "    c=configparser.ConfigParser(strict=False,interpolation=None)\n" + "    try:\n" + "        c.read(f)\n" + "        if 'Desktop Entry' not in c: continue\n" + "        e=c['Desktop Entry']\n" + "        if e.get('Type')!='Application': continue\n" + "        if e.get('NoDisplay','false').lower()=='true': continue\n" + "        n=e.get('Name','')\n" + "        x=e.get('Exec','').split('%')[0].strip()\n" + "        i=e.get('Icon','')\n" + "        if n and x and n not in seen:\n" + "            seen.add(n)\n" + "            apps.append((n,x,find_icon(i)))\n" + "    except: pass\n" + "for n,x,i in sorted(apps,key=lambda a:a[0].lower()): print(n+'\\t'+x+'\\t'+i)\n"]
        stdout: SplitParser {
            onRead: data => {
                const parts = data.split('\t');
                if (parts.length >= 2)
                    allApps.append({
                        appName: parts[0],
                        appExec: parts[1].trim(),
                        appIcon: parts.length >= 3 ? parts[2].trim() : ""
                    });
            }
        }
        onExited: {
            root.appsLoaded = true;
            root.filterApps(searchInput.text);
        }
    }

    Process {
        id: launcher
        property string execCmd: ""
        command: ["bash", "-c", "setsid " + launcher.execCmd + " </dev/null >/dev/null 2>&1 &"]
        onExited: running = false
    }

    function launch(execCmd) {
        launcher.execCmd = execCmd.trim();
        launcher.running = true;
        root.closeRequested();
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
            if (highlightedIndex >= 0 && highlightedIndex < shownApps.count)
                root.launch(shownApps.get(highlightedIndex).appExec);
            else if (shownApps.count > 0)
                root.launch(shownApps.get(0).appExec);
            event.accepted = true;
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
                text: "\uf002"
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
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "Search apps…"
                color: Qt.rgba(1, 1, 1, 0.28)
                font.pixelSize: 13
                font.family: root.textFontFamily
                visible: searchInput.text === "" && !searchInput.activeFocus
            }

            TextInput {
                id: searchInput
                anchors.left: searchIcon.right
                anchors.leftMargin: 8
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                verticalAlignment: TextInput.AlignVCenter
                color: "white"
                font.pixelSize: 13
                font.family: root.textFontFamily
                clip: true
                onTextChanged: root.filterApps(text)
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
                visible: !root.appsLoaded || shownApps.count === 0
                text: !root.appsLoaded ? "Scanning…" : "No results"
                color: Qt.rgba(1, 1, 1, 0.25)
                font.pixelSize: 12
                font.family: root.textFontFamily
            }

            ListView {
                id: resultsList
                anchors.fill: parent
                model: shownApps
                spacing: 2
                clip: true
                keyNavigationEnabled: false

                section.property: "section"
                section.delegate: Item {
                    width: resultsList.width
                    height: (root.favouriteApps.length > 0 && searchInput.text === "") ? 22 : 0
                    visible: height > 0
                    clip: true

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        text: section === "favourites" ? "FAVOURITES" : "ALL APPS"
                        color: Qt.rgba(1, 1, 1, 0.32)
                        font.pixelSize: 9
                        font.family: root.textFontFamily
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.2
                        visible: parent.visible
                    }
                }

                delegate: Rectangle {
                    width: ListView.view.width
                    height: 36
                    radius: 10
                    color: (index === root.highlightedIndex) ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                    Behavior on color {
                        ColorAnimation {
                            duration: 80
                        }
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: 2
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3
                        height: parent.height * 0.55
                        radius: 1.5
                        color: model.section === "favourites" ? "#f59e0b" : "#60a5fa"
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
                                anchors.centerIn: parent
                                width: 20
                                height: 20
                                source: model.appIcon !== "" ? ("file://" + model.appIcon) : ""
                                visible: model.appIcon !== "" && status === Image.Ready
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                mipmap: true
                                sourceSize: Qt.size(40, 40)
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: model.appIcon === "" || parent.children[0].status !== Image.Ready
                                text: "\uf11b"
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
                            width: parent.width - 28 - 8 - (model.section === "favourites" ? 18 : 0)
                            anchors.verticalCenter: parent.verticalCenter
                            text: model.appName
                            color: index === root.highlightedIndex ? "white" : Qt.rgba(1, 1, 1, 0.80)
                            font.pixelSize: 13
                            font.family: root.textFontFamily
                            font.weight: index === root.highlightedIndex ? Font.SemiBold : Font.Medium
                            elide: Text.ElideRight
                            Behavior on color {
                                ColorAnimation {
                                    duration: 80
                                }
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: model.section === "favourites"
                            text: "\uf005"
                            font.family: root.iconFontFamily
                            font.pixelSize: 10
                            color: "#f59e0b"
                            opacity: 0.90
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.launch(model.appExec)
                        onContainsMouseChanged: {
                            if (containsMouse)
                                root.highlightedIndex = index;
                        }
                    }
                }
            }
        }
    }
}
