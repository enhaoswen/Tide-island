import TideIsland 1.0
import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.folderlistmodel

Dialog {
    id: dialog

    property bool directoryMode: false
    property url currentFolder: folderUrl(StandardPaths.writableLocation(StandardPaths.HomeLocation))
    property string selectedDirectory: ""

    signal pathAccepted(string path)

    title: directoryMode ? "Choose wallpaper library" : "Choose wallpaper target"
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape
    padding: 0
    header: null
    footer: null
    parent: Overlay.overlay
    width: Math.min(700, Math.max(420, parent.width - 64))
    height: Math.min(500, Math.max(360, parent.height - 64))
    x: Math.round((parent.width - width) / 2)
    y: Math.round((parent.height - height) / 2)

    function localPath(value) {
        if (value === undefined || value === null)
            return ""
        if (value.toLocalFile)
            return value.toLocalFile()

        const text = String(value)
        return text.startsWith("file://") ? decodeURIComponent(text.substring(7)) : text
    }

    function folderUrl(path) {
        const text = String(path || "")
        if (text.length === 0)
            return "file:///"
        return text.startsWith("file://") ? text : "file://" + encodeURI(text)
    }

    function parentPath(path) {
        const text = String(path || "").replace(/\/+$/, "")
        const slashIndex = text.lastIndexOf("/")
        if (slashIndex <= 0)
            return "/"
        return text.substring(0, slashIndex)
    }

    function baseName(path) {
        const text = String(path || "").replace(/\/+$/, "")
        const slashIndex = text.lastIndexOf("/")
        return slashIndex < 0 ? text : text.substring(slashIndex + 1)
    }

    function joinedPath(folder, name) {
        const cleanFolder = String(folder || "").replace(/\/+$/, "")
        const cleanName = String(name || "").replace(/^\/+/, "")
        if (cleanFolder === "")
            return "/" + cleanName
        if (cleanFolder === "/")
            return "/" + cleanName
        return cleanFolder + "/" + cleanName
    }

    function openForPath(path) {
        const text = String(path || "")
        selectedDirectory = ""

        if (directoryMode) {
            currentFolder = folderUrl(text.length > 0
                ? text
                : StandardPaths.writableLocation(StandardPaths.HomeLocation))
        } else {
            currentFolder = folderUrl(text.length > 0
                ? parentPath(text)
                : StandardPaths.writableLocation(StandardPaths.HomeLocation))
        }

        open()
        Qt.callLater(function() {
            locationField.text = localPath(currentFolder)
            fileList.currentIndex = -1
            if (!directoryMode) {
                fileNameField.text = baseName(text)
                fileNameField.field.selectAll()
            }
        })
    }

    function navigate(folder) {
        selectedDirectory = ""
        fileList.currentIndex = -1
        currentFolder = folder
    }

    function navigateFromField() {
        const path = locationField.text.trim()
        if (path.length > 0)
            navigate(folderUrl(path))
    }

    function acceptSelection() {
        let path = ""
        if (directoryMode) {
            path = selectedDirectory.length > 0 ? selectedDirectory : localPath(currentFolder)
        } else {
            const name = fileNameField.text.trim()
            if (name.length === 0) {
                fileNameField.field.forceActiveFocus()
                return
            }
            path = name.startsWith("/") ? name : joinedPath(localPath(currentFolder), name)
        }

        pathAccepted(path)
        accept()
    }

    onCurrentFolderChanged: {
        locationField.text = localPath(currentFolder)
        fileList.currentIndex = -1
        selectedDirectory = ""
    }

    background: Rectangle {
        radius: 14
        color: Theme.totalBgColor
        border.width: 1
        border.color: Theme.cardBorderColor
    }

    Overlay.modal: Rectangle {
        color: Theme.overlayColor
    }

    contentItem: ColumnLayout {
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 18
            Layout.rightMargin: 18
            Layout.topMargin: 16
            Layout.bottomMargin: 13

            Text {
                Layout.fillWidth: true
                text: dialog.title
                color: Theme.textColor
                font.family: Theme.textFontFamily
                font.pixelSize: 17
                font.weight: Font.DemiBold
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.splitLineColor
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 18
            Layout.rightMargin: 18
            Layout.topMargin: 12
            Layout.bottomMargin: 10
            spacing: 8

            ToolbarButton {
                text: "Home"
                onClicked: dialog.navigate(dialog.folderUrl(StandardPaths.writableLocation(StandardPaths.HomeLocation)))
            }

            ToolbarButton {
                text: "Up"
                enabled: dialog.localPath(folderModel.parentFolder) !== dialog.localPath(dialog.currentFolder)
                onClicked: dialog.navigate(folderModel.parentFolder)
            }

            CompactTextField {
                id: locationField
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                textPixelSize: 13
                placeholderText: "/home/user/.hidden-folder"
                onAccepted: dialog.navigateFromField()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 18
            Layout.rightMargin: 18
            radius: 8
            color: Theme.cardBgColor
            border.width: 1
            border.color: Theme.cardBorderColor
            clip: true

            ListView {
                id: fileList

                anchors.fill: parent
                anchors.margins: 1
                clip: true
                model: FolderListModel {
                    id: folderModel

                    folder: dialog.currentFolder
                    showFiles: !dialog.directoryMode
                    showDirs: true
                    showDirsFirst: true
                    showDotAndDotDot: false
                    showHidden: true
                    showOnlyReadable: true
                    sortField: FolderListModel.Name
                    sortCaseSensitive: false
                }

                ScrollBar.vertical: ScrollBar { }

                delegate: Rectangle {
                    id: entry

                    required property int index
                    required property string fileName
                    required property url fileUrl
                    required property bool fileIsDir

                    width: ListView.view.width
                    height: 39
                    color: ListView.isCurrentItem
                        ? Theme.accentSoftColor
                        : entryMouse.containsMouse ? Theme.controlHoverColor : "transparent"

                    Behavior on color {
                        ColorAnimation { duration: Theme.animationDuration }
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 13
                        anchors.right: parent.right
                        anchors.rightMargin: 13
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 9

                        FileGlyph {
                            folder: entry.fileIsDir
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            width: parent.width - 27
                            text: entry.fileName
                            elide: Text.ElideMiddle
                            color: Theme.textColor
                            font.family: Theme.textFontFamily
                            font.pixelSize: 13
                        }
                    }

                    MouseArea {
                        id: entryMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            fileList.currentIndex = entry.index
                            if (dialog.directoryMode) {
                                dialog.selectedDirectory = dialog.localPath(entry.fileUrl)
                            } else if (!entry.fileIsDir) {
                                fileNameField.text = entry.fileName
                            }
                        }

                        onDoubleClicked: {
                            if (entry.fileIsDir) {
                                dialog.navigate(entry.fileUrl)
                            } else if (!dialog.directoryMode) {
                                fileNameField.text = entry.fileName
                                dialog.acceptSelection()
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: folderModel.status === FolderListModel.Ready && folderModel.count === 0
                    text: "This folder is empty"
                    color: Theme.subtleTextColor
                    font.family: Theme.textFontFamily
                    font.pixelSize: 14
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 18
            Layout.rightMargin: 18
            Layout.topMargin: 11
            Layout.bottomMargin: 16
            spacing: 8

            Text {
                visible: dialog.directoryMode
                Layout.fillWidth: true
                text: dialog.selectedDirectory.length > 0
                    ? dialog.selectedDirectory
                    : dialog.localPath(dialog.currentFolder)
                elide: Text.ElideMiddle
                color: Theme.secondaryTextColor
                font.family: Theme.textFontFamily
                font.pixelSize: 12
            }

            CompactTextField {
                id: fileNameField
                visible: !dialog.directoryMode
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                textPixelSize: 13
                placeholderText: "wallpaper.png"
                onAccepted: dialog.acceptSelection()
            }

            DialogButton {
                text: "Cancel"
                muted: true
                onClicked: dialog.reject()
            }

            DialogButton {
                text: "Select"
                onClicked: dialog.acceptSelection()
            }
        }
    }

    component FileGlyph: Item {
        id: glyph

        property bool folder: false

        width: 18
        height: 16

        Rectangle {
            visible: glyph.folder
            x: 1
            y: 4
            width: 16
            height: 11
            radius: 2
            color: "transparent"
            border.width: 1
            border.color: Theme.secondaryTextColor
        }

        Rectangle {
            visible: glyph.folder
            x: 2
            y: 2
            width: 7
            height: 4
            radius: 1
            color: Theme.cardBgColor
            border.width: 1
            border.color: Theme.secondaryTextColor
        }

        Rectangle {
            visible: !glyph.folder
            x: 3
            y: 1
            width: 12
            height: 14
            radius: 2
            color: "transparent"
            border.width: 1
            border.color: Theme.subtleTextColor
        }

        Rectangle {
            visible: !glyph.folder
            x: 6
            y: 5
            width: 6
            height: 1
            color: Theme.subtleTextColor
        }

        Rectangle {
            visible: !glyph.folder
            x: 6
            y: 9
            width: 5
            height: 1
            color: Theme.subtleTextColor
        }
    }

    component ToolbarButton: Rectangle {
        id: toolbarButton

        signal clicked
        property string text: ""

        implicitWidth: toolbarLabel.implicitWidth + 16
        implicitHeight: 34
        radius: 6
        color: toolbarMouse.pressed ? Theme.controlPressedColor
                                    : toolbarMouse.containsMouse ? Theme.controlHoverColor
                                                                : "transparent"
        opacity: enabled ? 1 : 0.38

        Behavior on color {
            ColorAnimation { duration: Theme.animationDuration }
        }

        Text {
            id: toolbarLabel

            anchors.centerIn: parent
            text: toolbarButton.text
            color: Theme.secondaryTextColor
            font.family: Theme.textFontFamily
            font.pixelSize: 12
            font.weight: Font.Medium
        }

        MouseArea {
            id: toolbarMouse

            anchors.fill: parent
            enabled: toolbarButton.enabled
            hoverEnabled: true
            cursorShape: toolbarButton.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: toolbarButton.clicked()
        }
    }

    component CompactTextField: Rectangle {
        id: compactField

        property alias text: textInput.text
        property alias placeholderText: textInput.placeholderText
        property alias field: textInput
        property int textPixelSize: 13

        signal accepted

        radius: 6
        color: Theme.inputBgColor
        border.width: 1
        border.color: textInput.activeFocus ? Theme.focusBorderColor : Theme.inputBorderColor

        Behavior on border.color {
            ColorAnimation { duration: Theme.animationDuration }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            z: -1
            radius: compactField.radius + 3
            color: "transparent"
            border.width: 3
            border.color: Theme.focusRingColor
            opacity: textInput.activeFocus ? 1 : 0

            Behavior on opacity { NumberAnimation { duration: Theme.animationDuration } }
        }

        TextField {
            id: textInput

            anchors.fill: parent
            background: null
            color: Theme.textColor
            placeholderTextColor: Theme.subtleTextColor
            selectionColor: Theme.selectedColor
            selectedTextColor: Theme.buttonTextColor
            leftPadding: 10
            rightPadding: 10
            verticalAlignment: TextInput.AlignVCenter
            font.family: Theme.textFontFamily
            font.pixelSize: compactField.textPixelSize
            onAccepted: compactField.accepted()
        }
    }

    component DialogButton: Rectangle {
        id: button

        signal clicked
        property string text: ""
        property bool muted: false

        implicitWidth: Math.max(64, buttonLabel.implicitWidth + 22)
        implicitHeight: 34
        radius: 6
        color: !enabled
            ? Theme.componentBgColor
            : buttonMouse.pressed
                ? (muted ? Theme.controlPressedColor : Theme.buttonPressedColor)
                : buttonMouse.containsMouse
                    ? (muted ? Theme.mutedButtonHoverColor : Theme.buttonHoverColor)
                    : (muted ? "transparent" : Theme.buttonColor)
        border.width: 1
        border.color: muted ? Theme.inputBorderColor : color
        opacity: enabled ? 1 : 0.55

        Behavior on color {
            ColorAnimation { duration: Theme.animationDuration }
        }

        Text {
            id: buttonLabel

            anchors.centerIn: parent
            text: button.text
            color: button.muted ? Theme.mutedButtonTextColor : Theme.buttonTextColor
            font.family: Theme.textFontFamily
            font.pixelSize: 12
            font.weight: Font.Medium
        }

        MouseArea {
            id: buttonMouse

            anchors.fill: parent
            enabled: button.enabled
            hoverEnabled: true
            cursorShape: button.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: button.clicked()
        }
    }
}
