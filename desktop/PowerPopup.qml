import QtQuick

CardWindow {
    id: powerPopup
    required property var root

    theme: root
    revealed: root.powerVisible
    cardWidth: 290
    layerNamespace: "omarchy-power"
    title: "POWER"
    footer: "󰍹 B SCREENSAVER  ·  ↵  ·  ESC / Q CLOSE"
    headerRight: Text {
        anchors.verticalCenter: parent.verticalCenter
        text: powerPopup._hoveredLabel
        color: root.inkDeep
        font.family: root.mono
        font.pixelSize: 10
        font.letterSpacing: 1.5
        visible: powerPopup._hoveredLabel.length > 0
    }
    anchorEdge: "top"
    anchorBarX: powerPopup.width / 2
    anchorGap: 1

    onDismiss: root.powerVisible = false
    onKeyPressed: function(event) {
        const k = event.key;
        const n = powerPopup._actions.length;
        if (k === Qt.Key_Left) {
            const row = Math.floor(powerPopup._kbdIndex / 3);
            const col = powerPopup._kbdIndex % 3;
            powerPopup._kbdIndex = row * 3 + ((col - 1 + 3) % 3);
            event.accepted = true;
        } else if (k === Qt.Key_Right) {
            const row = Math.floor(powerPopup._kbdIndex / 3);
            const col = powerPopup._kbdIndex % 3;
            powerPopup._kbdIndex = row * 3 + ((col + 1) % 3);
            event.accepted = true;
        } else if (k === Qt.Key_Up) {
            powerPopup._kbdIndex = Math.max(0, powerPopup._kbdIndex - 3);
            event.accepted = true;
        } else if (k === Qt.Key_Down || k === Qt.Key_Tab) {
            powerPopup._kbdIndex = Math.min(n - 1, powerPopup._kbdIndex + 3);
            event.accepted = true;
        } else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) {
            const a = powerPopup._actions[powerPopup._kbdIndex];
            if (a) powerPopup._fire(a);
            event.accepted = true;
        } else if (k === Qt.Key_Q) {
            root.powerVisible = false;
            event.accepted = true;
        } else if (k === Qt.Key_B) {
            root.run("omarchy-launch-screensaver force");
            root.powerVisible = false;
            event.accepted = true;
        }
    }

    readonly property var _actions: [
        { glyph: "󰌾", label: "Lock",      cmd: "omarchy-system-lock" },
        { glyph: "󰤄", label: "Suspend",   cmd: "systemctl suspend" },
        { glyph: "󰋊", label: "Hibernate", cmd: "systemctl hibernate" },
        { glyph: "󰗽", label: "Logout",    cmd: "omarchy-system-logout" },
        { glyph: "󰜉", label: "Reboot",    cmd: "omarchy-system-reboot" },
        { glyph: "󰐥", label: "Shutdown",  cmd: "omarchy-system-shutdown" },
        { glyph: "󰍹", label: "Screensaver", cmd: "omarchy-launch-screensaver force" }
    ]
    property int _kbdIndex: 0
    property string _hoveredLabel: ""

    function _fire(a) {
        root.run(a.cmd);
        root.powerVisible = false;
    }

    readonly property real _tileSize: (cardWidth - 34 - 16) / 3

    Column {
        anchors { left: parent.left; right: parent.right }
        spacing: 10

        Grid {
            width: parent.width
            columns: 3
            columnSpacing: 8
            rowSpacing: 8
            Repeater {
                model: 6
                delegate: Item {
                    required property int index
                    width: powerPopup._tileSize
                    height: powerPopup._tileSize

                    readonly property var _action: powerPopup._actions[index]
                    readonly property bool _selected: powerPopup._kbdIndex === index

                    Rectangle {
                        anchors.fill: parent
                        radius: root.cornerRadius
                        color: parent._selected
                               ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.20)
                               : tileMouse.containsMouse
                                  ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.10)
                                  : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.03)
                        border.color: parent._selected ? root.seal : root.sep
                        border.width: parent._selected ? 2 : 1
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: parent._action.glyph
                        color: root.ink
                        font.family: root.mono
                        font.pixelSize: 24
                    }

                    MouseArea {
                        id: tileMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: powerPopup._fire(parent._action)
                        onEntered: powerPopup._hoveredLabel = parent._action.label
                        onExited:  powerPopup._hoveredLabel = ""
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: root.sep
            opacity: 0.5
        }

        Item {
            width: parent.width
            height: 38

            readonly property var _action: powerPopup._actions[6]
            readonly property bool _selected: powerPopup._kbdIndex === 6

            Rectangle {
                anchors.fill: parent
                radius: root.cornerRadius
                color: parent._selected
                       ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.20)
                       : saverMouse.containsMouse
                          ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.10)
                          : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.03)
                border.color: parent._selected ? root.seal : root.sep
                border.width: parent._selected ? 2 : 1
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }
            }

            Row {
                anchors.centerIn: parent
                spacing: 8
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent.parent._action.glyph
                    color: root.ink
                    font.family: root.mono
                    font.pixelSize: 13
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "SCREENSAVER"
                    color: root.ink
                    font.family: root.mono
                    font.pixelSize: 10
                    font.letterSpacing: 1.5
                    font.weight: Font.Medium
                }
            }

            MouseArea {
                id: saverMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: powerPopup._fire(parent._action)
                onEntered: powerPopup._hoveredLabel = parent._action.label
                onExited:  powerPopup._hoveredLabel = ""
            }
        }

    }
}
