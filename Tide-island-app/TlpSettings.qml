import QtQuick
import QtQuick.Controls
import TideIsland 1.0

Rectangle {
    id: root

    property int revision: 0
    readonly property var permissionOptions: [
        { "label": "Disabled", "value": "skip" },
        { "label": "Ask", "value": "ask" },
        { "label": "Enable", "value": "password" }
    ]

    color: "transparent"
    radius: 10
    border.width: 2
    border.color: Theme.splitLineColor
    implicitHeight: tlpColumn.implicitHeight + 36

    function textValue(key, fallback) {
        return String(ConfigStore.value(key, fallback))
    }

    function permissionMode() {
        revision
        const mode = textValue("tlpPermissionMode", "skip").trim()
        if (mode === "ask")
            return "ask"
        if (mode === "password" || mode === "enable")
            return "password"
        return "skip"
    }

    function passwordValue() {
        revision
        return textValue("tlpSudoPassword", "")
    }

    function savePermissionMode(mode) {
        ConfigStore.setValue("tlpPermissionMode", mode)
        if (mode !== "password")
            ConfigStore.remove("tlpSudoPassword")
        ConfigStore.save()
        revision += 1
    }

    function savePassword(value) {
        ConfigStore.setValue("tlpSudoPassword", String(value))
        ConfigStore.setValue("tlpPermissionMode", "password")
        ConfigStore.save()
        revision += 1
    }

    Column {
        id: tlpColumn

        anchors.top: parent.top
        anchors.topMargin: 18
        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.right: parent.right
        anchors.rightMargin: 18
        spacing: 16

        PermissionModeRow {
            width: parent.width
        }

        Rectangle {
            width: parent.width
            height: 2
            visible: root.permissionMode() === "password"
            color: Theme.splitLineColor
        }

        PasswordRow {
            visible: root.permissionMode() === "password"
            width: parent.width
        }
    }

    component PermissionModeRow: Item {
        id: row

        height: 49

        Text {
            id: rowTitle

            text: "TLP Permission"
            anchors.left: parent.left
            anchors.top: parent.top
            color: Theme.textColor
            font.family: Theme.textFontFamily
            font.pixelSize: 18
        }

        Text {
            text: root.permissionMode() === "skip"
                ? "Hide TLP power profile controls"
                : root.permissionMode() === "ask"
                    ? "Ask through the system authentication dialog"
                    : "Use the saved sudo password when changing profiles"
            anchors.left: rowTitle.left
            anchors.top: rowTitle.bottom
            anchors.topMargin: 5
            width: Math.max(80, parent.width - permissionGroup.width - 28)
            color: Theme.subtleTextColor
            elide: Text.ElideRight
            font.family: Theme.textFontFamily
            font.pixelSize: 14
        }

        ButtonGroup {
            id: permissionGroup

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            options: root.permissionOptions
            selectedValue: root.permissionMode()

            onSelected: function(value) {
                root.savePermissionMode(value)
            }
        }
    }

    component PasswordRow: Item {
        id: row

        height: 49

        Text {
            id: rowTitle

            text: "Sudo Password"
            anchors.left: parent.left
            anchors.top: parent.top
            color: Theme.textColor
            font.family: Theme.textFontFamily
            font.pixelSize: 18
        }

        Text {
            text: "Used when switching TLP power profiles"
            anchors.left: rowTitle.left
            anchors.top: rowTitle.bottom
            anchors.topMargin: 5
            color: Theme.subtleTextColor
            font.family: Theme.textFontFamily
            font.pixelSize: 14
        }

        Rectangle {
            id: passwordBox

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(180, Math.min(300, parent.width / 3))
            height: 36
            radius: 8
            color: Theme.inputBgColor
            border.width: 2
            border.color: passwordField.activeFocus ? Theme.focusBorderColor : Theme.inputBorderColor

            Behavior on color {
                ColorAnimation { duration: Theme.animationDuration }
            }

            Behavior on border.color {
                ColorAnimation { duration: Theme.animationDuration }
            }

            TextField {
                id: passwordField

                anchors.fill: parent
                background: null
                echoMode: TextInput.Password
                color: Theme.textColor
                placeholderText: "Password"
                placeholderTextColor: Theme.subtleTextColor
                selectionColor: Theme.selectedColor
                selectedTextColor: Theme.buttonTextColor
                inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                leftPadding: 10
                rightPadding: 10
                verticalAlignment: TextInput.AlignVCenter
                font.family: Theme.textFontFamily
                font.pixelSize: 14

                Component.onCompleted: text = root.passwordValue()
                onAccepted: root.savePassword(text)
                onEditingFinished: root.savePassword(text)
            }
        }
    }

    component ButtonGroup: Row {
        id: group

        signal selected(string value)

        property var options: []
        property string selectedValue: ""

        width: implicitWidth
        height: implicitHeight
        spacing: 6

        Repeater {
            model: group.options

            Rectangle {
                id: option

                property bool selectedState: group.selectedValue === modelData.value

                width: Math.max(74, optionText.implicitWidth + 24)
                height: 36
                radius: 8
                color: selectedState ? Theme.selectedColor : (optionMouse.containsMouse ? Theme.accentSoftColor : Theme.inputBgColor)
                border.width: 2
                border.color: selectedState ? Theme.selectedColor : Theme.inputBorderColor

                Behavior on color {
                    ColorAnimation { duration: Theme.animationDuration }
                }

                Behavior on border.color {
                    ColorAnimation { duration: Theme.animationDuration }
                }

                Text {
                    id: optionText

                    anchors.centerIn: parent
                    text: modelData.label
                    color: option.selectedState ? Theme.buttonTextColor : Theme.textColor
                    font.family: Theme.textFontFamily
                    font.pixelSize: 14
                    font.weight: option.selectedState ? Font.DemiBold : Font.Normal
                }

                MouseArea {
                    id: optionMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: group.selected(modelData.value)
                }
            }
        }
    }
}
