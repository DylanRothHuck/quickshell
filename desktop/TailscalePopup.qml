import QtQuick

CardWindow {
    id: tsPopup
    property var root: ({})

    theme: root
    revealed: root.tailscaleVisible
    cardWidth: 340
    layerNamespace: "omarchy-tailscale"
    title: "TAILSCALE"
    subtitle: {
        if (!root.tailscaleOnline) return "OFF";
        return root.tailscaleOnlineCount + "/" + root.tailscalePeerCount + " ONLINE  \u00b7  " + root.tailscaleIp;
    }

    anchorEdge: root.barEdge
    anchorBarX: root.popupAnchorX
    anchorBarY: root.popupAnchorY

    headerRight: Row {
        spacing: 8
        QuickButton {
            root: tsPopup.root
            label: root.tailscaleOnline ? "STOP" : "START"
            selected: tsPopup.kbdIndex === 0
            onClicked: root.toggleTailscale()
        }
    }

    onDismiss: root.tailscaleVisible = false
    onKeyPressed: function(event) {
        const k = event.key;
        if (k === Qt.Key_Q) {
            root.tailscaleVisible = false;
            event.accepted = true;
            return;
        }
        const n = tsPopup._kbdMax;
        if (n === 0) return;
        if (k === Qt.Key_Up) {
            tsPopup.kbdIndex = Math.max(0, tsPopup.kbdIndex - 1);
            event.accepted = true;
        } else if (k === Qt.Key_Down || k === Qt.Key_Tab) {
            tsPopup.kbdIndex = Math.min(n - 1, tsPopup.kbdIndex + 1);
            event.accepted = true;
        } else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) {
            tsPopup._activateAt(tsPopup.kbdIndex);
            event.accepted = true;
        }
    }

    onRevealedChanged: {
        if (revealed) {
            tsPopup.kbdIndex = 0;
            root.refreshTailscale();
        }
    }

    property int kbdIndex: 0
    readonly property int _headerCount: 1
    readonly property var _visiblePeers: root.tailscalePeers
    readonly property int _selfIdx: _headerCount + _visiblePeers.length
    readonly property int _kbdMax: _selfIdx + 1

    // Tracks which peer row just copied its IP so we can flash "COPIED".
    property int copiedIndex: -1
    property bool selfCopied: false
    Timer {
        id: copiedTimer
        interval: 900
        onTriggered: { tsPopup.copiedIndex = -1; tsPopup.selfCopied = false; }
    }

    function _activateAt(i) {
        tsPopup.kbdIndex = i;
        if (i === 0) { root.toggleTailscale(); return; }
        if (i >= _visiblePeers.length + _headerCount) {
            if (root.tailscaleIp) {
                root.copyToClipboard(root.tailscaleIp);
                tsPopup.selfCopied = true;
                copiedTimer.restart();
            }
            return;
        }
        const peer = tsPopup._visiblePeers[i - tsPopup._headerCount];
        if (!peer) return;
        root.copyToClipboard(peer.ip);
        tsPopup.copiedIndex = i;
        copiedTimer.restart();
    }

    footer: root.tailscaleOnline && root.tailscalePeers.length > 0
            ? "\u2191\u2193 CYCLE  \u00b7  \u23CE COPY IP  \u00b7  ESC CLOSE"
            : root.tailscaleOnline
              ? "\u23CE COPY IP  \u00b7  ESC CLOSE"
              : ""

    Column {
        width: parent.width
        spacing: 10

        Rectangle {
            width: parent.width
            height: 1
            color: root.sep
        }

        Item {
            width: parent.width
            height: 26

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.tailscaleOnline
                      ? root.tailscalePeerCount + " PEERS"
                      : "SERVICE OFF"
                color: root.inkDeep
                font.family: root.mono
                font.pixelSize: 10
                font.letterSpacing: 2
            }
        }

        Repeater {
            model: tsPopup._visiblePeers

            delegate: Rectangle {
                required property var modelData
                required property int index

                readonly property int localIndex: index + tsPopup._headerCount
                readonly property bool isOnline: modelData.online === true
                readonly property bool isFocused: tsPopup.kbdIndex === localIndex

                width: parent.width
                height: 38
                radius: root.cornerRadius
                color: isFocused
                       ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.20)
                       : (peerMouse.containsMouse
                          ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)
                          : "transparent")
                border.color: isFocused ? root.seal : "transparent"
                border.width: isFocused ? 1.5 : 0
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                Text {
                    id: osIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.os === "macOS" ? "\uF179"
                         : modelData.os === "iOS" ? "\uF179"
                         : modelData.os === "windows" ? "\uF17A"
                         : modelData.os === "android" ? "\uF17B"
                         : "\uF109"
                    color: isOnline ? root.accent : root.inkDeep
                    font.family: root.mono
                    font.pixelSize: 16
                }
                Text {
                    anchors.left: osIcon.right
                    anchors.right: ipArea.left
                    anchors.leftMargin: 10
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.name
                    elide: Text.ElideRight
                    color: isOnline ? root.ink : root.inkDeep
                    font.family: root.mono
                    font.pixelSize: 11
                    font.weight: isOnline ? Font.Medium : Font.Normal
                    opacity: isOnline ? 1.0 : 0.6
                }
                Item {
                    id: ipArea
                    anchors.right: dot.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 100
                    height: 16
                    clip: true

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.ip
                        color: root.inkDeep
                        font.family: root.mono
                        font.pixelSize: 9
                        font.letterSpacing: 0.5
                        opacity: tsPopup.copiedIndex === localIndex ? 0 : (isOnline ? 0.8 : 0.4)
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\u2713  COPIED"
                        color: root.green
                        font.family: root.mono
                        font.pixelSize: 9
                        font.letterSpacing: 1
                        font.weight: Font.Medium
                        opacity: tsPopup.copiedIndex === localIndex ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }
                }
                Text {
                    id: dot
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\u25CF"
                    color: isOnline ? root.green : root.inkDeep
                    font.pixelSize: 8
                    opacity: isOnline ? 1.0 : 0.4
                }
                MouseArea {
                    id: peerMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: tsPopup._activateAt(localIndex)
                }
            }
        }

        Text {
            visible: root.tailscaleOnline && root.tailscalePeers.length === 0
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "NO PEERS"
            color: root.inkDeep
            font.family: root.mono
            font.pixelSize: 10
            font.letterSpacing: 2
            opacity: 0.6
        }

        Text {
            visible: !root.tailscaleOnline
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "TAILSCALE DISCONNECTED"
            color: root.inkDeep
            font.family: root.mono
            font.pixelSize: 10
            font.letterSpacing: 2
            opacity: 0.6
        }

        Rectangle {
            width: parent.width
            height: 1
            color: root.sep
        }

        Rectangle {
            readonly property int localIndex: tsPopup._selfIdx
            readonly property bool isFocused: tsPopup.kbdIndex === localIndex
            visible: root.tailscaleOnline && root.tailscaleIp.length > 0
            width: parent.width
            height: 38
            radius: root.cornerRadius
            color: isFocused
                   ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.20)
                   : (selfMouse.containsMouse
                      ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)
                      : "transparent")
            border.color: isFocused ? root.seal : "transparent"
            border.width: isFocused ? 1.5 : 0
            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            Text {
                id: selfLabel
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: "\uF0C1"
                color: root.accent
                font.family: root.mono
                font.pixelSize: 11
            }
            Text {
                anchors.left: selfLabel.right
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: root.tailscaleIp
                color: root.inkDeep
                font.family: root.mono
                font.pixelSize: 10
                font.letterSpacing: 1
                opacity: tsPopup.selfCopied ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 100 } }
            }
            Text {
                anchors.left: selfLabel.right
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: "\u2713  COPIED"
                color: root.green
                font.family: root.mono
                font.pixelSize: 10
                font.letterSpacing: 1
                font.weight: Font.Medium
                opacity: tsPopup.selfCopied ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 100 } }
            }
            MouseArea {
                id: selfMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: tsPopup._activateAt(localIndex)
            }
        }
    }
}
