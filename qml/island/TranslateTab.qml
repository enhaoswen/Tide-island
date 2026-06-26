import QtQuick
import QtQuick.Controls

Item {
    id: translateTab

    property string textFontFamily: ""
    property var backend: null
    property bool isActive: false

    // Language codes for MyMemory
    readonly property var languages: [
        { label: "English",  code: "en" },
        { label: "Albanian", code: "sq" },
        { label: "German",   code: "de" }
    ]

    property int sourceLangIndex: 0
    property int targetLangIndex: 1

    onIsActiveChanged: {
        if (isActive) sourceInput.forceActiveFocus();
    }

    // ── Backend connections ───────────────────────────────────────────────
    Connections {
        target: backend
        function onTranslateResponseReceived(result) {
            resultText.text = result;
        }
        function onTranslateErrorReceived(error) {
            resultText.text = "⚠ " + error;
        }
    }

    function doTranslate() {
        if (sourceInput.text.trim() === "" || !backend || backend.translateLoading) return;
        const src = languages[sourceLangIndex].code;
        const tgt = languages[targetLangIndex].code;
        resultText.text = "";
        backend.translate(sourceInput.text.trim(), src, tgt);
    }

    function swapLanguages() {
        const tmp = sourceLangIndex;
        sourceLangIndex = targetLangIndex;
        targetLangIndex = tmp;
        // Re-translate if there's input
        if (sourceInput.text.trim() !== "") doTranslate();
    }

    // ── Language picker row ───────────────────────────────────────────────
    Row {
        id: langRow
        z: 50
        anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 2 }
        height: 36
        spacing: 6

        // Source language selector
        LangSelector {
            id: sourceSel
            width: (parent.width - 40) / 2
            height: 34
            fontFamily: translateTab.textFontFamily
            languages: translateTab.languages
            selectedIndex: translateTab.sourceLangIndex
            onSelected: idx => {
                if (idx === translateTab.targetLangIndex) {
                    translateTab.targetLangIndex = translateTab.sourceLangIndex;
                }
                translateTab.sourceLangIndex = idx;
            }
        }

        // Swap button
        Rectangle {
            width: 28; height: 34
            radius: 8
            color: swapMa.containsMouse ? "#2a2a2a" : "#1e1e1e"
            anchors.verticalCenter: parent.verticalCenter

            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
                anchors.centerIn: parent
                text: "⇄"
                font.pixelSize: 15
                color: "#888888"
            }

            MouseArea {
                id: swapMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: translateTab.swapLanguages()
            }
        }

        // Target language selector
        LangSelector {
            id: targetSel
            width: (parent.width - 40) / 2
            height: 34
            fontFamily: translateTab.textFontFamily
            languages: translateTab.languages
            selectedIndex: translateTab.targetLangIndex
            onSelected: idx => {
                if (idx === translateTab.sourceLangIndex) {
                    translateTab.sourceLangIndex = translateTab.targetLangIndex;
                }
                translateTab.targetLangIndex = idx;
            }
        }
    }

    // ── Source input ──────────────────────────────────────────────────────
    Rectangle {
        id: sourceBox
        anchors {
            top: langRow.bottom
            left: parent.left
            right: parent.right
            topMargin: 8
        }
        height: 100
        radius: 14
        color: "#1e1e1e"
        border.width: sourceInput.activeFocus ? 1 : 0
        border.color: "#3d7aed"

        Behavior on border.color { ColorAnimation { duration: 150 } }

        Flickable {
            anchors { fill: parent; margins: 12 }
            contentHeight: sourceInput.implicitHeight
            clip: true

            TextEdit {
                id: sourceInput
                width: parent.width
                font.family: translateTab.textFontFamily
                font.pixelSize: 13
                color: "#ffffff"
                wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                selectionColor: "#3d7aed"

                Text {
                    anchors.fill: parent
                    text: "Type or paste text to translate..."
                    font: parent.font
                    color: "#555555"
                    visible: parent.text === ""
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                }

                // Auto-translate after pause
                onTextChanged: autoTranslateTimer.restart()
            }
        }

        // Char count + clear
        Row {
            anchors { right: parent.right; bottom: parent.bottom; margins: 8 }
            spacing: 8

            Text {
                text: sourceInput.text.length + " chars"
                font.family: translateTab.textFontFamily
                font.pixelSize: 10
                color: "#444444"
                anchors.verticalCenter: parent.verticalCenter
                visible: sourceInput.text.length > 0
            }

            Rectangle {
                width: 22; height: 22; radius: 6
                color: clearSrcMa.containsMouse ? "#2a2a2a" : "transparent"
                visible: sourceInput.text.length > 0

                Text {
                    anchors.centerIn: parent
                    text: "✕"; font.pixelSize: 10; color: "#666666"
                }
                MouseArea {
                    id: clearSrcMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        sourceInput.text = "";
                        resultText.text = "";
                    }
                }
            }
        }
    }

    Timer {
        id: autoTranslateTimer
        interval: 800
        onTriggered: translateTab.doTranslate()
    }

    // ── Divider with loading indicator ────────────────────────────────────
    Item {
        id: divider
        anchors { top: sourceBox.bottom; left: parent.left; right: parent.right; topMargin: 8 }
        height: 20

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: loadingRow.visible ? loadingRow.left : parent.right
            anchors.rightMargin: loadingRow.visible ? 8 : 0
            height: 1
            color: "#2a2a2a"
        }

        Row {
            id: loadingRow
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 4
            visible: backend && backend.translateLoading

            Repeater {
                model: 3
                Rectangle {
                    width: 5; height: 5; radius: 3
                    color: "#3d7aed"
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: backend && backend.translateLoading
                        PauseAnimation { duration: index * 180 }
                        NumberAnimation { to: 0.2; duration: 300 }
                        NumberAnimation { to: 1.0; duration: 300 }
                    }
                }
            }
        }
    }

    // ── Result area ───────────────────────────────────────────────────────
    Rectangle {
        id: resultBox
        anchors {
            top: divider.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            topMargin: 0
        }
        radius: 14
        color: "#1a1a1a"

        Flickable {
            anchors { fill: parent; margins: 12 }
            contentHeight: resultText.implicitHeight
            clip: true

            Text {
                id: resultText
                width: parent.width
                font.family: translateTab.textFontFamily
                font.pixelSize: 13
                color: resultText.text.startsWith("⚠") ? "#cc5555" : "#e0e0e0"
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                lineHeight: 1.45
                text: ""

                Text {
                    anchors.fill: parent
                    text: "Translation appears here"
                    font: parent.font
                    color: "#333333"
                    visible: parent.text === ""
                }
            }
        }

        // Copy button
        Rectangle {
            width: 60; height: 24
            anchors { right: parent.right; bottom: parent.bottom; margins: 8 }
            radius: 7
            color: copyMa.containsMouse ? "#2a2a2a" : "#222222"
            visible: resultText.text !== "" && !resultText.text.startsWith("⚠")

            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
                anchors.centerIn: parent
                text: copyMa.copied ? "Copied!" : "Copy"
                font.family: translateTab.textFontFamily
                font.pixelSize: 11
                color: copyMa.copied ? "#3d7aed" : "#888888"
            }

            MouseArea {
                id: copyMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                property bool copied: false

                onClicked: {
                    Clipboard.setText(resultText.text);
                    copied = true;
                    copyResetTimer.restart();
                }
            }

            Timer {
                id: copyResetTimer
                interval: 1500
                onTriggered: copyMa.copied = false
            }
        }
    }
}
