import QtQuick
import QtQuick.LocalStorage

Item {
    id: root

    property string iconFontFamily: ""
    property string textFontFamily: ""
    property bool showCondition: false

    opacity: showCondition ? 1 : 0
    anchors.fill: parent

    Behavior on opacity {
        NumberAnimation {
            duration: 200
            easing.type: Easing.InOutQuad
        }
    }

    ListModel {
        id: todoModel
    }

    function db() {
        return LocalStorage.openDatabaseSync("QuickshellTodo", "1.0", "Todo list", 500000);
    }

    function loadTodos() {
        db().transaction(function (tx) {
            tx.executeSql("CREATE TABLE IF NOT EXISTS todos (id INTEGER PRIMARY KEY AUTOINCREMENT, text TEXT, done INTEGER DEFAULT 0)");
            const rs = tx.executeSql("SELECT id, text, done FROM todos ORDER BY id");
            for (let i = 0; i < rs.rows.length; i++) {
                const r = rs.rows.item(i);
                todoModel.append({
                    dbId: r.id,
                    itemText: r.text,
                    done: r.done === 1
                });
            }
        });
    }

    function addTodo(text) {
        const t = text.trim();
        if (!t)
            return;
        db().transaction(function (tx) {
            tx.executeSql("INSERT INTO todos (text, done) VALUES (?, 0)", [t]);
            const rs = tx.executeSql("SELECT last_insert_rowid() AS id");
            todoModel.append({
                dbId: rs.rows.item(0).id,
                itemText: t,
                done: false
            });
        });
    }

    function toggleTodo(idx) {
        const item = todoModel.get(idx);
        const newDone = !item.done;
        todoModel.setProperty(idx, "done", newDone);
        db().transaction(function (tx) {
            tx.executeSql("UPDATE todos SET done = ? WHERE id = ?", [newDone ? 1 : 0, item.dbId]);
        });
    }

    function removeTodo(idx) {
        const item = todoModel.get(idx);
        db().transaction(function (tx) {
            tx.executeSql("DELETE FROM todos WHERE id = ?", [item.dbId]);
        });
        todoModel.remove(idx);
    }

    Component.onCompleted: loadTodos()

    Column {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 8

        Row {
            width: parent.width
            height: 26
            spacing: 6

            Rectangle {
                width: parent.width - 32
                height: 26
                radius: 8
                color: todoInput.activeFocus ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.06)
                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    verticalAlignment: Text.AlignVCenter
                    text: "Add a task…"
                    color: Qt.rgba(1, 1, 1, 0.25)
                    font.pixelSize: 11
                    font.family: root.textFontFamily
                    visible: todoInput.text === "" && !todoInput.activeFocus
                }

                TextInput {
                    id: todoInput
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 8
                    verticalAlignment: TextInput.AlignVCenter
                    color: "white"
                    font.pixelSize: 11
                    font.family: root.textFontFamily
                    clip: true
                    Keys.onReturnPressed: {
                        addTodo(text);
                        text = "";
                    }
                }
            }

            Rectangle {
                width: 26
                height: 26
                radius: 8
                color: plusMouse.pressed ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)
                Behavior on color {
                    ColorAnimation {
                        duration: 100
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "+"
                    color: Qt.rgba(1, 1, 1, 0.7)
                    font.pixelSize: 16
                    font.family: root.textFontFamily
                }

                MouseArea {
                    id: plusMouse
                    anchors.fill: parent
                    onClicked: {
                        addTodo(todoInput.text);
                        todoInput.text = "";
                    }
                }
            }
        }

        ListView {
            id: todoList
            width: parent.width
            height: parent.height - 26 - 8
            clip: true
            model: todoModel
            spacing: 2

            delegate: Item {
                width: todoList.width
                height: 28

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 2
                    anchors.rightMargin: 2
                    spacing: 8
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        width: parent.width - 22 - 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: model.itemText
                        color: model.done ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(1, 1, 1, 0.88)
                        font.pixelSize: 12
                        font.family: root.textFontFamily
                        font.strikeout: model.done
                        elide: Text.ElideRight
                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: toggleTodo(index)
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "×"
                        color: delMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.6) : Qt.rgba(1, 1, 1, 0.18)
                        font.pixelSize: 16
                        font.family: root.textFontFamily
                        Behavior on color {
                            ColorAnimation {
                                duration: 100
                            }
                        }

                        MouseArea {
                            id: delMouse
                            anchors.fill: parent
                            anchors.margins: 0
                            hoverEnabled: false
                            preventStealing: true
                            propagateComposedEvents: false
                            cursorShape: Qt.PointingHandCursor
                            onPressed: { event.accepted = true }
                            onClicked: removeTodo(index)
                        }
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.05)
                    visible: index < todoModel.count - 1
                }
            }

            Text {
                anchors.centerIn: parent
                visible: todoModel.count === 0
                text: "No tasks yet"
                color: Qt.rgba(1, 1, 1, 0.20)
                font.pixelSize: 12
                font.family: root.textFontFamily
            }
        }
    }
}
