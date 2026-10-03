import QtQuick

Item {
    id: root

    property bool active: false
    property bool animateChanges: true
    property string stateKey: ""
    property bool animating: false
    property bool initialized: false

    width: 24
    height: 24

    // Heart.zip: 30 fps, 10 frames; outline pulses 100% → 90% → 100%,
    // with the fill growing from 50% after frame 2 and fading in by frame 7.

    function showCurrentState() {
        outlineHeart.opacity = active ? 0 : 1;
        outlineHeart.scale = 1;
        filledHeart.opacity = active ? 1 : 0;
        filledHeart.scale = 1;
    }

    function playForCurrentState() {
        favoriteOnAnimation.stop();
        favoriteOffAnimation.stop();
        animating = true;
        if (active)
            favoriteOnAnimation.restart();
        else
            favoriteOffAnimation.restart();
    }

    Image {
        id: outlineHeart

        anchors.centerIn: parent
        width: root.width
        height: root.height
        source: Qt.resolvedUrl("assets/heart.svg")
        sourceSize: Qt.size(48, 48)
        smooth: true
        mipmap: true
    }

    Image {
        id: filledHeart

        anchors.centerIn: parent
        width: root.width
        height: root.height
        source: Qt.resolvedUrl("assets/heart-filled.svg")
        sourceSize: Qt.size(48, 48)
        smooth: true
        mipmap: true
    }

    SequentialAnimation {
        id: favoriteOnAnimation

        ScriptAction {
            script: {
                outlineHeart.opacity = 1;
                outlineHeart.scale = 1;
                filledHeart.opacity = 0;
                filledHeart.scale = 0.5;
            }
        }
        ParallelAnimation {
            SequentialAnimation {
                NumberAnimation {
                    target: outlineHeart
                    property: "scale"
                    from: 1
                    to: 0.9
                    duration: 167
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.333, 0, 0.667, 1, 1, 1]
                }
                NumberAnimation {
                    target: outlineHeart
                    property: "scale"
                    from: 0.9
                    to: 1
                    duration: 166
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.333, 0, 0.667, 1, 1, 1]
                }
            }
            SequentialAnimation {
                PauseAnimation { duration: 66 }
                NumberAnimation {
                    target: filledHeart
                    property: "scale"
                    from: 0.5
                    to: 1
                    duration: 267
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.333, 0, 0.667, 1, 1, 1]
                }
            }
            SequentialAnimation {
                PauseAnimation { duration: 66 }
                NumberAnimation {
                    target: filledHeart
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: 167
                    easing.type: Easing.Linear
                }
            }
        }
        ScriptAction {
            script: {
                outlineHeart.opacity = 0;
                root.animating = false;
                root.showCurrentState();
            }
        }
    }

    SequentialAnimation {
        id: favoriteOffAnimation

        ScriptAction {
            script: {
                outlineHeart.opacity = 1;
                outlineHeart.scale = 1;
                filledHeart.opacity = 1;
                filledHeart.scale = 1;
            }
        }
        ParallelAnimation {
            SequentialAnimation {
                NumberAnimation {
                    target: outlineHeart
                    property: "scale"
                    from: 1
                    to: 0.9
                    duration: 167
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.333, 0, 0.667, 1, 1, 1]
                }
                NumberAnimation {
                    target: outlineHeart
                    property: "scale"
                    from: 0.9
                    to: 1
                    duration: 166
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.333, 0, 0.667, 1, 1, 1]
                }
            }
            NumberAnimation {
                target: filledHeart
                property: "scale"
                from: 1
                to: 0.5
                duration: 267
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.333, 0, 0.667, 1, 1, 1]
            }
            SequentialAnimation {
                PauseAnimation { duration: 100 }
                NumberAnimation {
                    target: filledHeart
                    property: "opacity"
                    from: 1
                    to: 0
                    duration: 167
                    easing.type: Easing.Linear
                }
            }
        }
        ScriptAction {
            script: {
                root.animating = false;
                root.showCurrentState();
            }
        }
    }

    Component.onCompleted: {
        initialized = true;
        showCurrentState();
    }

    function settleCurrentState() {
        favoriteOnAnimation.stop();
        favoriteOffAnimation.stop();
        animating = false;
        showCurrentState();
    }

    onStateKeyChanged: if (initialized) settleCurrentState()
    onAnimateChangesChanged: if (initialized && !animateChanges) settleCurrentState()
    onActiveChanged: {
        if (!initialized) return;
        if (animateChanges)
            playForCurrentState();
        else
            settleCurrentState();
    }
}
