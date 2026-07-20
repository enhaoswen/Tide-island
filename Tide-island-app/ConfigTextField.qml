import QtQuick
import QtQuick.Controls
import TideIsland 1.0

Rectangle {
    id: control

    property alias text: field.text
    property alias placeholderText: field.placeholderText
    property alias inputMethodHints: field.inputMethodHints
    property alias validator: field.validator
    property alias field: field
    property int textPixelSize: 15

    signal accepted()
    signal editingFinished()

    readonly property bool hovered: hoverHandler.hovered

    radius: 6
    color: field.activeFocus ? Theme.cardBgColor
                             : hovered ? Theme.inputHoverBgColor
                                       : Theme.inputBgColor
    border.width: 1
    border.color: field.activeFocus ? Theme.focusBorderColor
                                    : hovered ? Theme.inputHoverBorderColor
                                              : Theme.inputBorderColor
    implicitWidth: 100
    implicitHeight: 36

    Behavior on color { ColorAnimation { duration: Theme.animationDuration } }
    Behavior on border.color { ColorAnimation { duration: Theme.animationDuration } }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        z: -1
        radius: control.radius + 3
        color: "transparent"
        border.width: 3
        border.color: Theme.focusRingColor
        opacity: field.activeFocus ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: Theme.animationDuration } }
    }

    HoverHandler {
        id: hoverHandler
        cursorShape: Qt.IBeamCursor
    }

    TextField {
        id: field
        background: null
        anchors.fill: parent
        color: Theme.textColor
        placeholderTextColor: Theme.subtleTextColor
        selectionColor: Theme.selectedColor
        selectedTextColor: Theme.buttonTextColor
        font.family: Theme.textFontFamily
        font.pixelSize: control.textPixelSize
        leftPadding: 10
        rightPadding: 10
        verticalAlignment: TextInput.AlignVCenter

        onAccepted: control.accepted()
        onEditingFinished: control.editingFinished()
    }
}
