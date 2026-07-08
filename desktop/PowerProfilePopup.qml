import QtQuick

CardWindow {
    id: powerPopup
    required property var root

    theme: root
    revealed: root.powerProfileVisible
    cardWidth: 260
    layerNamespace: "omarchy-powerprofile"
    title: "POWER"
    subtitle: root.powerProfile.length > 0
              ? root.batVal + "%  ·  " + root.batState.toUpperCase()
                + (root.batPower >= 0.05 ? "  ·  " + root.batPower.toFixed(1) + "W" : "")
              : root.batVal + "%  ·  " + root.batState.toUpperCase()

    anchorEdge: root.barEdge
    anchorBarX: root.popupAnchorX
    anchorBarY: root.popupAnchorY

    onDismiss: root.powerProfileVisible = false
    onKeyPressed: function(event) {
        const k = event.key;
        if (k === Qt.Key_Q) {
            root.powerProfileVisible = false;
            event.accepted = true;
            return;
        }
        if (!root.powerProfiles || root.powerProfiles.length === 0) return;
        const n = root.powerProfiles.length;
        if (k === Qt.Key_Up) {
            powerPopup.kbdIndex = (powerPopup.kbdIndex - 1 + n) % n;
            event.accepted = true;
        } else if (k === Qt.Key_Down || k === Qt.Key_Tab) {
            powerPopup.kbdIndex = (powerPopup.kbdIndex + 1) % n;
            event.accepted = true;
        } else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) {
            const name = root.powerProfiles[powerPopup.kbdIndex];
            if (name) root.setPowerProfile(name);
            event.accepted = true;
        }
    }

    onRevealedChanged: {
        if (revealed) {
            root.refreshPowerProfile();
            powerPopup.kbdIndex = Math.max(0, root.powerProfiles.indexOf(root.powerProfile));
        }
    }

    property int kbdIndex: 0

    footer: root.powerProfiles && root.powerProfiles.length > 1
            ? "↑↓ CYCLE  ·  ↵ SET  ·  ESC CLOSE"
            : ""

    Column {
        width: parent.width
        spacing: 12

        Item {
            width: parent.width
            height: 28
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 10
                radius: 5
                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.10)
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width * Math.max(0, Math.min(1, root.batVal / 100))
                    radius: parent.radius
                    color: root.batVal <= 10
                           ? root.seal
                           : (root.batVal <= 20
                              ? root.indigo
                              : root.ink)
                    Behavior on width { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation  { duration: 180 } }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: root.sep
        }

        Item {
            visible: root.powerProfiles && root.powerProfiles.length > 0
            width: parent.width
            height: visible ? bodyCol.implicitHeight : 0

            Column {
                id: bodyCol
                width: parent.width
                spacing: 6

                Text {
                    text: "POWER PROFILE"
                    color: root.inkDeep
                    font.family: root.mono
                    font.pixelSize: 10
                    font.letterSpacing: 2
                }

                Column {
                    width: parent.width
                    spacing: 4

                    Repeater {
                        model: root.powerProfiles || []

                        delegate: Item {
                            required property string modelData
                            required property int index

                            readonly property bool isActive: root.powerProfile === modelData
                            readonly property bool isFocused: powerPopup.kbdIndex === index

                            width: parent.width
                            height: 36

                            Item {
                                anchors.fill: parent
                                anchors.leftMargin: 4
                                clip: true

                                Rectangle {
                                    anchors.fill: parent
                                    radius: root.cornerRadius
                                    color: isActive
                                           ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.20)
                                           : (isFocused
                                              ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.10)
                                              : mouseArea.containsMouse
                                                ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)
                                                : "transparent")
                                    border.color: isActive ? root.seal : (isFocused ? root.ink : "transparent")
                                    border.width: isActive || isFocused ? 1.5 : 0
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }

                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 10

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: powerPopup._profileGlyph(modelData)
                                        color: isActive ? root.seal : root.ink
                                        font.family: root.mono
                                        font.pixelSize: 14
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.toUpperCase()
                                        color: isActive ? root.seal : root.ink
                                        font.family: root.mono
                                        font.pixelSize: 10
                                        font.letterSpacing: 1.5
                                        font.weight: isActive ? Font.Medium : Font.Normal
                                    }
                                }

                                Text {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "●"
                                    color: root.seal
                                    font.pixelSize: 8
                                    visible: isActive
                                }
                            }

                            MouseArea {
                                id: mouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    powerPopup.kbdIndex = index;
                                    root.setPowerProfile(modelData);
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    function _profileGlyph(p) {
        if (p === "performance") return "󱐌";
        if (p === "power-saver") return "󰌪";
        return "󰊚";
    }
}
