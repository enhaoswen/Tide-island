import TideIsland 1.0
import QtQuick
import QtQuick.Controls

Rectangle {
    id: root

    signal selectionChanged(var itemIds)

    readonly property string configKey: "dynamicIslandLeftSwipeItems"
    readonly property var defaultItems: ["cava", "battery"]
    readonly property string iconFontFamily: String(ConfigStore.value("iconFontFamily", "JetBrainsMono Nerd Font"))
    readonly property int selectedSpacing: 8
    readonly property var componentDefinitions: [
        { itemId: "time", displayName: "Time", previewText: "12:34", previewIcon: "", previewKind: "text", previewWidth: 76 },
        { itemId: "date", displayName: "Date", previewText: "Fri, Jul 03", previewIcon: "", previewKind: "text", previewWidth: 112 },
        { itemId: "battery", displayName: "Battery", previewText: "76%", previewIcon: "", previewKind: "battery", previewWidth: 92 },
        { itemId: "volume", displayName: "Volume", previewText: "42%", previewIcon: "\u{F057E}", previewKind: "iconText", previewWidth: 82 },
        { itemId: "brightness", displayName: "Brightness", previewText: "68%", previewIcon: "\u{F00E0}", previewKind: "iconText", previewWidth: 82 },
        { itemId: "workspace", displayName: "Workspace", previewText: "Workspace 2", previewIcon: "", previewKind: "text", previewWidth: 118 },
        { itemId: "cpu", displayName: "CPU", previewText: "CPU 38%", previewIcon: "\u{F035B}", previewKind: "iconText", previewWidth: 96 },
        { itemId: "ram", displayName: "RAM", previewText: "RAM 61%", previewIcon: "\u{F061A}", previewKind: "iconText", previewWidth: 96 },
        { itemId: "cava", displayName: "Cava", previewText: "", previewIcon: "", previewKind: "cava", previewWidth: 76 }
    ]

    property bool dragActive: false
    property string dragItemId: ""
    property bool dragFromSelection: false
    property int dragSelectedIndex: -1
    property real dragX: 0
    property real dragY: 0
    property real dragPointerOffsetX: 0
    property real dragPointerOffsetY: 0
    property string dragZone: ""
    readonly property bool dragPreviewUsesIslandStyle: dragFromSelection && dragZone === "island"

    color: Theme.cardBgColor
    radius: 16
    border.width: 1
    border.color: Theme.splitLineColor
    implicitHeight: selectorColumn.implicitHeight + 36

    ListModel {
        id: selectedModel
    }

    Component.onCompleted: loadFromConfig()

    function listValues(rawItems) {
        if (!rawItems)
            return [];

        if (Array.isArray(rawItems))
            return rawItems;

        if (typeof rawItems === "string")
            return [rawItems];

        const length = Number(rawItems.length);
        if (!isFinite(length) || length < 0)
            return [];

        const resolved = [];
        for (let index = 0; index < Math.floor(length); index++)
            resolved.push(rawItems[index]);
        return resolved;
    }

    function normalizeItemId(rawId) {
        return String(rawId === undefined || rawId === null ? "" : rawId).trim().toLowerCase();
    }

    function definitionForId(itemId) {
        const normalizedId = normalizeItemId(itemId);
        for (let index = 0; index < componentDefinitions.length; index++) {
            if (componentDefinitions[index].itemId === normalizedId)
                return componentDefinitions[index];
        }
        return null;
    }

    function isSupported(itemId) {
        return definitionForId(itemId) !== null;
    }

    function previewText(itemId) {
        const definition = definitionForId(itemId);
        return definition ? definition.previewText : "";
    }

    function previewIcon(itemId) {
        const definition = definitionForId(itemId);
        return definition ? definition.previewIcon : "";
    }

    function previewKind(itemId) {
        const definition = definitionForId(itemId);
        return definition ? definition.previewKind : "text";
    }

    function previewWidth(itemId) {
        const definition = definitionForId(itemId);
        return definition ? definition.previewWidth : 76;
    }

    function displayName(itemId) {
        const definition = definitionForId(itemId);
        return definition ? definition.displayName : "";
    }

    function selectedIds() {
        const ids = [];
        for (let index = 0; index < selectedModel.count; index++)
            ids.push(selectedModel.get(index).itemId);
        return ids;
    }

    function containsSelected(itemId) {
        const normalizedId = normalizeItemId(itemId);
        for (let index = 0; index < selectedModel.count; index++) {
            if (selectedModel.get(index).itemId === normalizedId)
                return true;
        }
        return false;
    }

    function loadFromConfig() {
        const source = listValues(ConfigStore.value(configKey, defaultItems));
        const seen = {};
        selectedModel.clear();

        for (let index = 0; index < source.length; index++) {
            const itemId = normalizeItemId(source[index]);
            if (!isSupported(itemId) || seen[itemId])
                continue;

            selectedModel.append({ itemId: itemId });
            seen[itemId] = true;
        }
    }

    function notifySelectionChanged() {
        const ids = selectedIds();
        ConfigStore.setValue(configKey, ids);
        ConfigStore.save();
        selectionChanged(ids);
    }

    function addItem(itemId, targetIndex) {
        const normalizedId = normalizeItemId(itemId);
        if (!isSupported(normalizedId) || containsSelected(normalizedId))
            return;

        const insertIndex = Math.max(0, Math.min(selectedModel.count, targetIndex));
        selectedModel.insert(insertIndex, { itemId: normalizedId });
        notifySelectionChanged();
    }

    function moveItem(fromIndex, targetIndex) {
        if (fromIndex < 0 || fromIndex >= selectedModel.count)
            return;

        const boundedTarget = Math.max(0, Math.min(selectedModel.count, targetIndex));
        const nextIndex = fromIndex < boundedTarget ? boundedTarget - 1 : boundedTarget;
        if (fromIndex === nextIndex)
            return;

        selectedModel.move(fromIndex, nextIndex, 1);
        notifySelectionChanged();
    }

    function removeItem(index) {
        if (index < 0 || index >= selectedModel.count)
            return;

        selectedModel.remove(index, 1);
        notifySelectionChanged();
    }

    function containsRootPoint(item, rootX, rootY) {
        const point = root.mapToItem(item, rootX, rootY);
        return point.x >= 0 && point.x <= item.width && point.y >= 0 && point.y <= item.height;
    }

    function refreshDragZone(rootX, rootY) {
        if (containsRootPoint(paletteDropZone, rootX, rootY)) {
            dragZone = "palette";
        } else if (containsRootPoint(islandPreview, rootX, rootY)) {
            dragZone = "island";
        } else {
            dragZone = "";
        }
    }

    function beginDrag(sourceChip, mouseX, mouseY) {
        const point = sourceChip.mapToItem(root, mouseX, mouseY);
        dragItemId = sourceChip.itemId;
        dragFromSelection = sourceChip.fromSelection;
        dragSelectedIndex = sourceChip.selectedIndex;
        dragPointerOffsetX = mouseX;
        dragPointerOffsetY = mouseY;
        dragActive = true;
        updateDrag(sourceChip, mouseX, mouseY);
    }

    function updateDrag(sourceChip, mouseX, mouseY) {
        const point = sourceChip.mapToItem(root, mouseX, mouseY);
        dragX = point.x - dragPointerOffsetX;
        dragY = point.y - dragPointerOffsetY;
        refreshDragZone(point.x, point.y);
    }

    function finishDrag(sourceChip, mouseX, mouseY) {
        const point = sourceChip.mapToItem(root, mouseX, mouseY);
        const wasFromSelection = dragFromSelection;
        const sourceIndex = dragSelectedIndex;
        const sourceId = dragItemId;

        if (containsRootPoint(paletteDropZone, point.x, point.y)) {
            if (wasFromSelection)
                removeItem(sourceIndex);
            clearDrag();
            return;
        }

        if (containsRootPoint(islandPreview, point.x, point.y)) {
            const islandPoint = root.mapToItem(islandPreview, point.x, point.y);
            const targetIndex = targetIndexForIslandX(islandPoint.x, wasFromSelection ? sourceIndex : -1);
            if (wasFromSelection)
                moveItem(sourceIndex, targetIndex);
            else
                addItem(sourceId, targetIndex);
        }

        clearDrag();
    }

    function clearDrag() {
        dragActive = false;
        dragItemId = "";
        dragFromSelection = false;
        dragSelectedIndex = -1;
        dragZone = "";
    }

    function isDraggingSelection(index) {
        return dragActive && dragFromSelection && dragSelectedIndex === index;
    }

    function selectedContentWidth(excludedIndex) {
        let width = 0;
        let visibleCount = 0;
        for (let index = 0; index < selectedModel.count; index++) {
            if (index === excludedIndex)
                continue;

            width += previewWidth(selectedModel.get(index).itemId);
            visibleCount++;
        }

        if (visibleCount > 1)
            width += selectedSpacing * (visibleCount - 1);
        return width;
    }

    function targetIndexForIslandX(localX, excludedIndex) {
        const contentWidth = selectedContentWidth(excludedIndex);
        let cursorX = (islandPreview.width - contentWidth) / 2;

        for (let index = 0; index < selectedModel.count; index++) {
            if (index === excludedIndex)
                continue;

            const itemWidth = previewWidth(selectedModel.get(index).itemId);
            if (localX < cursorX + itemWidth / 2)
                return index;

            cursorX += itemWidth + selectedSpacing;
        }

        return selectedModel.count;
    }

    Column {
        id: selectorColumn

        anchors.top: parent.top
        anchors.topMargin: 18
        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.right: parent.right
        anchors.rightMargin: 18
        spacing: 18

        Item {
            id: paletteDropZone

            width: parent.width
            height: paletteFlow.implicitHeight

            Flow {
                id: paletteFlow

                width: parent.width
                spacing: 10

                Repeater {
                    model: root.componentDefinitions

                    PreviewChip {
                        itemId: modelData.itemId
                        fromSelection: false
                        selectedIndex: -1
                        paletteDisabled: root.containsSelected(modelData.itemId)
                    }
                }
            }
        }

        Item {
            id: islandStage

            width: parent.width
            height: 124

            Rectangle {
                id: islandPreview

                readonly property real wantedWidth: selectedModel.count > 0
                    ? selectedContentWidth(root.dragFromSelection ? root.dragSelectedIndex : -1) + 46
                    : 220

                anchors.centerIn: parent
                width: Math.min(parent.width - 44, Math.max(220, wantedWidth))
                height: 48
                radius: height / 2
                color: "#050505"
                clip: true

                Behavior on width {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: selectedModel.count === 0
                    text: "+"
                    color: "#ffffff66"
                    font.family: Theme.textFontFamily
                    font.pixelSize: 24
                    font.weight: Font.DemiBold
                }

                Row {
                    id: selectedRow

                    visible: selectedModel.count > 0
                    anchors.centerIn: parent
                    height: 36
                    spacing: root.selectedSpacing

                    Repeater {
                        model: selectedModel

                        Item {
                            id: selectedSlot

                            width: root.isDraggingSelection(index) ? 0 : selectedChip.width
                            height: selectedChip.height

                            Behavior on width {
                                NumberAnimation {
                                    duration: 180
                                    easing.type: Easing.OutCubic
                                }
                            }

                            PreviewChip {
                                id: selectedChip

                                itemId: model.itemId
                                fromSelection: true
                                selectedIndex: index
                            }
                        }
                    }
                }
            }
        }
    }

    PreviewChip {
        id: dragPreview

        visible: root.dragActive
        itemId: root.dragItemId
        fromSelection: root.dragPreviewUsesIslandStyle
        floating: true
        interactive: false
        x: root.dragX
        y: root.dragY
        z: 10000
        opacity: 0.96
    }

    component PreviewChip: Rectangle {
        id: chip

        property string itemId: ""
        property bool fromSelection: false
        property bool paletteDisabled: false
        property bool floating: false
        property bool interactive: true
        property int selectedIndex: -1
        readonly property string chipKind: root.previewKind(itemId)
        readonly property string chipText: root.previewText(itemId)
        readonly property string chipIcon: root.previewIcon(itemId)
        readonly property bool draggable: interactive && (fromSelection || !paletteDisabled)
        readonly property bool hiddenByDrag: root.dragActive
            && root.dragItemId === itemId
            && root.dragFromSelection === fromSelection
            && (!fromSelection || root.dragSelectedIndex === selectedIndex)

        width: root.previewWidth(itemId)
        height: 34
        radius: 6
        color: !chip.fromSelection && chip.draggable && chipMouse.containsMouse
            ? Theme.controlHoverColor
            : "transparent"
        border.width: !chip.fromSelection && chip.draggable ? 1 : 0
        border.color: chipMouse.containsMouse ? Theme.inputHoverBorderColor : Theme.inputBorderColor
        opacity: hiddenByDrag ? 0 : (paletteDisabled ? 0.34 : 1)
        z: root.dragActive && hiddenByDrag ? 0 : 1

        Behavior on color { ColorAnimation { duration: Theme.animationDuration } }
        Behavior on border.color { ColorAnimation { duration: Theme.animationDuration } }

        Row {
            id: chipContent

            anchors.centerIn: parent
            spacing: 6

            BatteryPreview {
                visible: chip.chipKind === "battery"
                anchors.verticalCenter: parent.verticalCenter
            }

            CavaPreview {
                visible: chip.chipKind === "cava"
                anchors.verticalCenter: parent.verticalCenter
                barColor: chip.fromSelection ? "white" : Theme.selectedColor
            }

            Text {
                visible: chip.chipIcon !== "" && chip.chipKind !== "battery" && chip.chipKind !== "cava"
                anchors.verticalCenter: parent.verticalCenter
                text: chip.chipIcon
                color: chip.fromSelection ? "white" : Theme.selectedColor
                font.family: root.iconFontFamily
                font.pixelSize: 15
            }

            Text {
                visible: chip.chipKind !== "cava"
                anchors.verticalCenter: parent.verticalCenter
                text: chip.chipText
                color: chip.fromSelection ? "white" : Theme.textColor
                font.family: Theme.textFontFamily
                font.pixelSize: 14
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
            }
        }

        MouseArea {
            id: chipMouse

            anchors.fill: parent
            enabled: chip.draggable
            hoverEnabled: true
            cursorShape: chip.draggable ? Qt.OpenHandCursor : Qt.ArrowCursor

            property real pressX: 0
            property real pressY: 0
            property bool dragStarted: false

            onPressed: function(mouse) {
                pressX = mouse.x;
                pressY = mouse.y;
                dragStarted = false;
                cursorShape = Qt.ClosedHandCursor;
            }

            onPositionChanged: function(mouse) {
                if (!pressed)
                    return;

                const dx = mouse.x - pressX;
                const dy = mouse.y - pressY;
                if (!dragStarted && Math.sqrt(dx * dx + dy * dy) >= 4) {
                    dragStarted = true;
                    root.beginDrag(chip, mouse.x, mouse.y);
                } else if (dragStarted) {
                    root.updateDrag(chip, mouse.x, mouse.y);
                }
            }

            onReleased: function(mouse) {
                cursorShape = chip.draggable ? Qt.OpenHandCursor : Qt.ArrowCursor;
                if (dragStarted)
                    root.finishDrag(chip, mouse.x, mouse.y);
                dragStarted = false;
            }

            onCanceled: {
                cursorShape = chip.draggable ? Qt.OpenHandCursor : Qt.ArrowCursor;
                dragStarted = false;
                root.clearDrag();
            }
        }

    }

    component BatteryPreview: Item {
        width: 28
        height: 14

        Rectangle {
            anchors.fill: parent
            anchors.rightMargin: 4
            radius: 4
            color: "transparent"
            border.color: "#8e8e93"
            border.width: 1

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: 2
                width: (parent.width - 4) * 0.76
                radius: 2
                color: "#34c759"
            }
        }

        Rectangle {
            width: 3
            height: 7
            radius: 1
            color: "#8e8e93"
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    component CavaPreview: Item {
        id: cavaPreview

        property color barColor: Theme.selectedColor
        readonly property var levels: [0.35, 0.8, 0.55, 0.95, 0.48, 0.7, 0.4]

        width: 56
        height: 18

        Row {
            anchors.centerIn: parent
            spacing: 3

            Repeater {
                model: cavaPreview.levels

                Rectangle {
                    width: 4
                    height: Math.max(5, Math.round(cavaPreview.height * modelData))
                    radius: 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: cavaPreview.barColor
                }
            }
        }
    }
}
