import QtQuick

MouseArea {
    id: root

    property var islandController: null
    property var capsule: null

    hoverEnabled: false
    acceptedButtons: Qt.NoButton

    property real accumulatedDelta: 0
    property real swipeStartProgress: 0
    property bool isSwiping: false

    onWheel: (wheel) => {
        if (!islandController || !capsule)
            return;

        if (!isSwiping) {
            isSwiping = true;
            swipeStartProgress = islandController.swipeTransitionProgress;
            accumulatedDelta = 0;
            islandController.cancelSideSwipeSettle();
        }

        const deltaX = wheel.pixelDelta.x !== 0 ? wheel.pixelDelta.x : wheel.angleDelta.x / 4;
        const deltaY = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y : wheel.angleDelta.y / 4;
        const effectiveDelta = Math.abs(deltaX) > Math.abs(deltaY) ? deltaX : deltaY;

        accumulatedDelta += effectiveDelta * 0.8;

        const nextProgress = islandController.advanceSideSwipeProgress(swipeStartProgress, -accumulatedDelta);
        islandController.swipeTransitionProgress = nextProgress;
        capsule.displayedWidth = capsule.sideSwipePreviewWidth;

        swipeSettleTimer.restart();
        wheel.accepted = false;
    }

    Timer {
        id: swipeSettleTimer

        interval: 150

        onTriggered: {
            if (!root.isSwiping || !root.islandController)
                return;

            root.isSwiping = false;
            const settleResult = root.islandController.resolveSideSwipeSettle(
                root.swipeStartProgress,
                root.islandController.swipeTransitionProgress
            );
            root.islandController.beginSideSwipeSettle(settleResult.width);

            switch (settleResult.action) {
            case "time":
                root.islandController.showTimeCapsule();
                break;
            case "custom":
                root.islandController.showCustomCapsule();
                break;
            case "lyrics":
                root.islandController.showLyricsCapsule();
                break;
            default:
                root.islandController.swipeTransitionProgress = settleResult.progress;
            }
        }
    }
}
