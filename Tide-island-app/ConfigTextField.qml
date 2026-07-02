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

    radius: 8
    color: Theme.inputBgColor
    border.width: 2
    border.color: field.activeFocus ? Theme.focusBorderColor : Theme.inputBorderColor
    implicitWidth: 100
    implicitHeight: 40

    Behavior on border.color {
        ColorAnimation { duration: Theme.animationDuration }
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
