import QtQuick
import Qt5Compat.GraphicalEffects
import IslandBackend

Item {
    id: root

    readonly property var userConfig: UserConfig

    property string lyricText: ""
    property string currentArtUrl: ""
    property var cavaLevels: []
    property string timeText: ""
    property var configSource: null
    readonly property var activeConfig: configSource || userConfig
    property string textFontFamily: activeConfig.textFontFamily
    property string timeFontFamily: activeConfig.timeFontFamily
    property bool showCondition: false
    property bool showSecondaryText: true
    property bool recordingActive: false
    property real transitionProgress: 0
    property int textPixelSize: userConfig.bodyFontSize
    property real minimumWidth: 220
    property real maximumWidth: minimumWidth
    property real horizontalPadding: 14
    property real coverSize: 24
    property real coverRadius: 7
    property real visualSpacing: 20
    property real hiddenLeftPadding: 18
    property real hiddenRightPadding: 16
    property string activeLyricText: lyricText
    property string previousLyricText: ""
    property real lyricChangeProgress: 1
    property int recordingDotSpacing: 12

    readonly property real clampedProgress: Math.max(0, Math.min(1, transitionProgress))
    readonly property bool lyricMostlyVisible: clampedProgress > 0.92
    readonly property real textWidth: Math.max(0, width - horizontalPadding * 2)
    readonly property real lyricTextWidth: Math.max(
        0,
        textWidth - coverSize - cavaBars.implicitWidth - visualSpacing * 2
    )
    readonly property real centeredX: horizontalPadding
    readonly property real lyricHiddenLeftX: -textWidth - hiddenLeftPadding
    readonly property real timeHiddenRightX: width + hiddenRightPadding
    readonly property real lyricEntryDistance: Math.max(0, centeredX - lyricHiddenLeftX)
    readonly property real timeExitDistance: Math.max(0, timeHiddenRightX - centeredX)
    readonly property real dragDistance: Math.max(lyricEntryDistance, timeExitDistance)
    readonly property real lyricX: centeredX - (1 - clampedProgress) * dragDistance
    readonly property real timeX: centeredX + clampedProgress * dragDistance
    readonly property real lyricBaselineY: lyricBaselineGuide.y + lyricBaselineGuide.baselineOffset
    readonly property real timeBaselineY: timeBaselineGuide.y + timeBaselineGuide.baselineOffset
    readonly property real visibleLyricWidth: Math.min(lyricTextWidth, Math.max(0, lyricMetrics.advanceWidth))
    readonly property real visibleTimeWidth: Math.min(textWidth, Math.max(0, timeMetrics.advanceWidth))
    readonly property real timeRecordingDotX: Math.max(
        4,
        timeX + (textWidth - visibleTimeWidth) / 2 - recordingDotSpacing - timeRecordingIndicator.width
    )
    readonly property real preferredWidth: Math.max(
        minimumWidth,
        Math.min(
            Math.max(minimumWidth, maximumWidth),
            lyricMetrics.advanceWidth
                + horizontalPadding * 2
                + coverSize
                + cavaBars.implicitWidth
                + visualSpacing * 2
        )
    )

    onLyricTextChanged: {
        if (lyricText === activeLyricText) return;

        if (activeLyricText === "" || !lyricMostlyVisible) {
            lyricChangeAnimation.stop();
            previousLyricText = "";
            activeLyricText = lyricText;
            lyricChangeProgress = 1;
            return;
        }

        previousLyricText = activeLyricText;
        activeLyricText = lyricText;
        lyricChangeProgress = 0;
        lyricChangeAnimation.restart();
    }

    onShowConditionChanged: {
        if (showCondition) return;
        lyricChangeAnimation.stop();
        previousLyricText = "";
        activeLyricText = lyricText;
        lyricChangeProgress = 1;
    }

    onTransitionProgressChanged: {
        if (lyricMostlyVisible) return;
        lyricChangeAnimation.stop();
        previousLyricText = "";
        activeLyricText = lyricText;
        lyricChangeProgress = 1;
    }

    anchors.fill: parent
    clip: true
    opacity: showCondition ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: showCondition ? 220 : 140
            easing.type: Easing.InOutQuad
        }
    }

    TextMetrics {
        id: lyricMetrics
        font.family: textFontFamily
        font.pixelSize: textPixelSize
        font.weight: Font.DemiBold
        text: activeLyricText !== "" ? activeLyricText : lyricText
    }

    TextMetrics {
        id: timeMetrics
        font.family: timeFontFamily
        font.pixelSize: textPixelSize + 1
        font.weight: Font.Bold
        text: timeText
    }

    Text {
        id: lyricBaselineGuide
        anchors.verticalCenter: parent.verticalCenter
        text: "Ag国"
        opacity: 0
        font.pixelSize: textPixelSize
        font.family: textFontFamily
        font.weight: Font.DemiBold
        font.letterSpacing: -0.15
        wrapMode: Text.NoWrap
    }

    Text {
        id: timeBaselineGuide
        anchors.verticalCenter: parent.verticalCenter
        text: "00:00"
        opacity: 0
        font.pixelSize: textPixelSize + 1
        font.family: timeFontFamily
        font.weight: Font.Bold
        font.letterSpacing: -0.25
        wrapMode: Text.NoWrap
    }

    SequentialAnimation {
        id: lyricChangeAnimation

        NumberAnimation {
            target: root
            property: "lyricChangeProgress"
            from: 0
            to: 1
            duration: 260
            easing.type: Easing.OutCubic
        }

        ScriptAction {
            script: root.previousLyricText = ""
        }
    }

    Item {
        id: lyricContent

        x: root.lyricX
        width: root.textWidth
        height: parent.height
        opacity: root.clampedProgress

        Rectangle {
            id: coverFrame

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: root.coverSize
            height: root.coverSize
            radius: root.coverRadius
            color: "#2c2c2e"
            antialiasing: true

            Rectangle {
                id: coverMask

                anchors.fill: parent
                radius: root.coverRadius
                antialiasing: true
                visible: false
                layer.enabled: true
            }

            Image {
                anchors.fill: parent
                source: root.currentArtUrl
                fillMode: Image.PreserveAspectCrop
                visible: source.toString() !== ""
                sourceSize: Qt.size(root.coverSize * 2, root.coverSize * 2)
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: coverMask
                }
            }
        }

        Item {
            id: lyricViewport

            anchors.left: coverFrame.right
            anchors.leftMargin: root.visualSpacing
            anchors.right: cavaBars.left
            anchors.rightMargin: root.visualSpacing
            height: parent.height
            clip: true

            Text {
                visible: root.previousLyricText !== ""
                y: root.lyricBaselineY - baselineOffset - 14 * root.lyricChangeProgress
                width: parent.width
                text: root.previousLyricText
                color: "white"
                opacity: 1 - root.lyricChangeProgress
                font.pixelSize: root.textPixelSize
                font.family: root.textFontFamily
                font.weight: Font.DemiBold
                font.letterSpacing: -0.15
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
            }

            Text {
                visible: root.activeLyricText !== ""
                y: root.lyricBaselineY - baselineOffset
                    + (root.previousLyricText !== "" ? 12 * (1 - root.lyricChangeProgress) : 0)
                width: parent.width
                text: root.activeLyricText
                color: "white"
                opacity: root.previousLyricText !== "" ? root.lyricChangeProgress : 1
                font.pixelSize: root.textPixelSize
                font.family: root.textFontFamily
                font.weight: Font.DemiBold
                font.letterSpacing: -0.15
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
            }
        }

        SwipeCavaBars {
            id: cavaBars

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            levels: root.cavaLevels
            barCount: 5
            barWidth: 3
            barSpacing: 3
            minimumBarHeight: 4
            barColor: "white"
        }
    }

    Text {
        visible: timeText !== "" && showSecondaryText
        x: timeX
        y: timeBaselineY - baselineOffset
        width: textWidth
        text: timeText
        color: "white"
        opacity: 1 - clampedProgress
        font.pixelSize: textPixelSize + 1
        font.family: timeFontFamily
        font.weight: Font.Bold
        font.letterSpacing: -0.25
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        wrapMode: Text.NoWrap
    }

    RecordingIndicator {
        id: timeRecordingIndicator
        active: root.recordingActive
            && root.showSecondaryText
            && root.timeText !== ""
            && root.clampedProgress < 0.001
        contentOpacity: 1 - root.clampedProgress
        x: root.timeRecordingDotX
        anchors.verticalCenter: parent.verticalCenter
    }
}
