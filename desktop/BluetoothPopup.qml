import QtQuick

CardWindow {
    id: btPopup
    property var root: ({})

    theme: root
    revealed: root.btVisible
    cardWidth: 340
    layerNamespace: "omarchy-bluetooth"
    title: "BLUETOOTH"
    subtitle: {
        if (!root.btPowered) return "POWER OFF";
        let s = root.btDevices.length + " DEVICES";
        if (root.btCount > 0) s += "  \u00b7  " + root.btCount + " CONN";
        if (root.btScanning) s += "  \u00b7  SCANNING";
        return s;
    }

    anchorEdge: root.barEdge
    anchorBarX: root.popupAnchorX
    anchorBarY: root.popupAnchorY

    headerRight: Row {
        spacing: 8
        QuickButton {
            root: btPopup.root
            label: root.btPowered ? "POWER OFF" : "POWER ON"
            selected: btPopup.kbdIndex === 0
            onClicked: root.btTogglePower()
        }
        QuickButton {
            root: btPopup.root
            label: root.btScanning ? "SCANNING" : "SCAN"
            selected: btPopup.kbdIndex === 1 || root.btScanning
            onClicked: root.btToggleScan()
        }
    }

    onDismiss: root.btVisible = false
    onKeyPressed: function(event) {
        const k = event.key;
        if (k === Qt.Key_Q) {
            root.btVisible = false;
            event.accepted = true;
            return;
        }
        const n = btPopup._kbdMax;
        if (n === 0) return;
        if (k === Qt.Key_Up) {
            btPopup.kbdIndex = Math.max(0, btPopup.kbdIndex - 1);
            event.accepted = true;
        } else if (k === Qt.Key_Down || k === Qt.Key_Tab) {
            btPopup.kbdIndex = Math.min(n - 1, btPopup.kbdIndex + 1);
            event.accepted = true;
        } else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) {
            btPopup._activateAt(btPopup.kbdIndex);
            event.accepted = true;
        }
    }

    onRevealedChanged: {
        if (revealed) {
            btPopup.kbdIndex = 0;
            root.refreshBluetooth();
        }
    }

    property int kbdIndex: 0
    readonly property int _headerCount: 2
    readonly property var _visibleDevs: root.btPowered
                                        ? root.btDevices.slice(0, 8)
                                        : []
    readonly property int _kbdMax: _headerCount + _visibleDevs.length

    function _activateAt(i) {
        btPopup.kbdIndex = i;
        if (i === 0) { root.btTogglePower(); return; }
        if (i === 1) { root.btToggleScan(); return; }
        const dev = btPopup._visibleDevs[i - btPopup._headerCount];
        if (!dev) return;
        if (dev.connected) root.btDisconnect(dev.mac);
        else root.btConnect(dev.mac);
    }

    footer: root.btPowered && root.btDevices.length > 0
            ? "\u2191\u2193 CYCLE  \u00b7  \u23CE CONNECT  \u00b7  ESC CLOSE"
            : ""

    Column {
        width: parent.width
        spacing: 10

        Rectangle {
            width: parent.width
            height: 1
            color: root.sep
        }

        Repeater {
            model: btPopup._visibleDevs

            delegate: Rectangle {
                required property var modelData
                required property int index

                readonly property int localIndex: index + btPopup._headerCount
                readonly property bool isConnected: modelData.connected === true || modelData.connected === "1" || modelData.connected === 1
                readonly property bool isFocused: btPopup.kbdIndex === localIndex
                readonly property bool hasBattery: modelData.battery != null

                width: parent.width
                height: 38
                radius: root.cornerRadius
                color: isConnected || isFocused
                       ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.20)
                       : (devMouse.containsMouse
                          ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)
                          : "transparent")
                border.color: isConnected || isFocused ? root.seal : "transparent"
                border.width: isConnected || isFocused ? 1.5 : 0
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                Text {
                    id: devIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: isConnected ? "\uF081"
                         : (modelData.paired ? "\uF0AF"
                                             : "\uF0B2")
                    color: isConnected ? root.seal : root.ink
                    font.family: root.mono
                    font.pixelSize: 16
                }
                Text {
                    anchors.left: devIcon.right
                    anchors.right: hasBattery ? batText.left : tag.left
                    anchors.leftMargin: 10
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.name
                    elide: Text.ElideRight
                    color: isConnected ? root.ink : root.fg
                    font.family: root.mono
                    font.pixelSize: 11
                    font.weight: isConnected ? Font.Medium : Font.Normal
                }
                Text {
                    id: tag
                    anchors.right: isConnected ? dot.left : parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !hasBattery
                    text: isConnected ? "CONNECTED"
                           : modelData.paired ? "PAIRED"
                                              : (modelData.trusted ? "TRUSTED" : "")
                    color: root.inkDeep
                    font.family: root.mono
                    font.pixelSize: 9
                    font.letterSpacing: 1.5
                }
                Text {
                    id: batText
                    anchors.right: isConnected ? dot.left : parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    visible: hasBattery
                    text: modelData.battery + "%"
                    color: root.inkDeep
                    font.family: root.mono
                    font.pixelSize: 10
                    font.letterSpacing: 1
                }
                Text {
                    id: dot
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\u25CF"
                    color: root.seal
                    font.pixelSize: 8
                    visible: isConnected
                }
                MouseArea {
                    id: devMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: btPopup._activateAt(localIndex)
                }
            }
        }

        Text {
            visible: root.btPowered && root.btDevices.length === 0
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "NO DEVICES \u2014 TAP SCAN"
            color: root.inkDeep
            font.family: root.mono
            font.pixelSize: 10
            font.letterSpacing: 2
            opacity: 0.6
        }
    }
}
