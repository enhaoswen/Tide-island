import QtQuick
import IslandBackend

Item {
    id: root
    readonly property var userConfig: UserConfig
    property bool showCondition: false
    property string appName: ""
    property string summary: ""
    property string body: ""
    property string iconText: ""
    property string imagePath: ""
    property var configSource: null
    readonly property var activeConfig: configSource || userConfig
    property string iconFontFamily: activeConfig.iconFontFamily
    property string textFontFamily: activeConfig.textFontFamily
    property string heroFontFamily: activeConfig.heroFontFamily

    readonly property string titleText: summary !== "" ? summary : "New notification"
    readonly property string bodyText: (body !== "" && body !== summary) ? body : ""
    readonly property bool hasTwoLines: bodyText !== ""
    readonly property bool useImageIcon: imagePath !== ""

    readonly property real minimumWidth: 280
    readonly property real maximumWidth: 700
    readonly property real iconSlotWidth: 28
    readonly property real contentSpacing: 10
    readonly property real horizontalPadding: 14
    readonly property real verticalPadding: 8

    readonly property real titleWidth: {
        if (titleText === "")
            return 0;
        var metrics = titleMetrics;
        metrics.text = titleText;
        return metrics.advanceWidth;
    }

    readonly property real bodyWidth: {
        if (bodyText === "")
            return 0;
        var metrics = bodyMetrics;
        metrics.text = bodyText;
        return metrics.advanceWidth;
    }

    readonly property real preferredWidth: {
        var width = minimumWidth;

        var textWidth = Math.max(titleWidth, bodyWidth);
        var neededWidth = textWidth + iconSlotWidth + contentSpacing + horizontalPadding * 2 + 20; // Extra padding for safety

        width = Math.max(minimumWidth, neededWidth);

        return Math.min(maximumWidth, width);
    }

    readonly property real preferredHeight: hasTwoLines ? 68 : 56

    TextMetrics {
        id: titleMetrics
        font.family: textFontFamily
        font.pixelSize: hasTwoLines ? 13 : 15
        font.weight: Font.DemiBold
        font.letterSpacing: -0.15
    }

    TextMetrics {
        id: bodyMetrics
        font.family: textFontFamily
        font.pixelSize: 12
        font.weight: Font.Normal
        font.letterSpacing: -0.1
    }

    anchors.fill: parent
    anchors.margins: 0
    opacity: showCondition ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: showCondition ? 280 : 140
            easing.type: Easing.InOutQuad
        }
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: horizontalPadding
        anchors.rightMargin: horizontalPadding
        anchors.topMargin: verticalPadding
        anchors.bottomMargin: verticalPadding
        spacing: contentSpacing

        Item {
            width: iconSlotWidth
            height: iconSlotWidth
            anchors.verticalCenter: parent.verticalCenter

            Image {
                id: appIcon
                anchors.fill: parent
                source: useImageIcon ? imagePath : ""
                fillMode: Image.PreserveAspectFit
                smooth: true
                visible: useImageIcon && status === Image.Ready
            }

            Text {
                anchors.fill: parent
                visible: !useImageIcon || appIcon.status !== Image.Ready
                text: iconText
                color: "#f4f5f7"
                font.pixelSize: 18
                font.family: iconFontFamily
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        Column {
            width: parent.width - iconSlotWidth - contentSpacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                id: titleTextItem
                width: parent.width
                text: titleText
                color: "white"
                font.pixelSize: hasTwoLines ? 13 : 15
                font.family: textFontFamily
                font.weight: Font.DemiBold
                font.letterSpacing: -0.15
                elide: Text.ElideRight
                maximumLineCount: 1
                onImplicitWidthChanged: {
                    root.preferredWidthChanged();
                }
            }

            // Rreshti 2: Body — pjesa e mesazhit
            Text {
                id: bodyTextItem
                width: parent.width
                visible: hasTwoLines
                height: hasTwoLines ? implicitHeight : 0
                text: bodyText
                color: "#b0b4ba"
                font.pixelSize: 12
                font.family: textFontFamily
                font.weight: Font.Normal
                font.letterSpacing: -0.1
                elide: Text.ElideRight
                maximumLineCount: 1
                onImplicitWidthChanged: {
                    root.preferredWidthChanged();
                }
            }
        }
    }
}
