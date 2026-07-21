import QtQuick

CardWindow {
    id: wifiPopup
    property var root: ({})

    theme: root
    revealed: root.wifiVisible
    cardWidth: 340
    layerNamespace: "omarchy-wifi"
    title: "WI-FI"

    subtitle: {
        if (!root.wifiRadioOn) return "OFF";
        if (root.wifiScanning) return "SCANNING\u2026";
        if (root.netKind === "wifi" && root.wifiSsid)
            return root.wifiSsid + "  \u00b7  " + root.wifiSignal + "%";
        if (root.wifiNetworks.length > 0)
            return root.wifiNetworks.length + " NETWORKS";
        return "NO NETWORKS";
    }

    anchorEdge: root.barEdge
    anchorBarX: root.popupAnchorX
    anchorBarY: root.popupAnchorY

    headerRight: Row {
        spacing: 8
        QuickButton {
            root: wifiPopup.root
            label: root.wifiRadioOn ? "OFF" : "ON"
            selected: wifiPopup.kbdIndex === 0
            onClicked: root.toggleWifiRadio()
        }
        QuickButton {
            root: wifiPopup.root
            glyph: root.icoRefresh
            selected: wifiPopup.kbdIndex === 1
            onClicked: root.refreshWifi()
        }
        QuickButton {
            root: wifiPopup.root
            visible: root.netKind === "wifi" && root.wifiSsid.length > 0
            glyph: "\uF029"
            selected: wifiPopup.kbdIndex === 2
            onClicked: root.shareWifi(root.wifiSsid)
        }
    }

    onDismiss: root.wifiVisible = false
    onKeyPressed: function(event) {
        const k = event.key;
        if (k === Qt.Key_Q) {
            root.wifiVisible = false;
            event.accepted = true;
            return;
        }
        const n = wifiPopup._kbdMax;
        if (n === 0) return;
        if (k === Qt.Key_Up) {
            wifiPopup.kbdIndex = Math.max(0, wifiPopup.kbdIndex - 1);
            event.accepted = true;
        } else if (k === Qt.Key_Down || k === Qt.Key_Tab) {
            wifiPopup.kbdIndex = Math.min(n - 1, wifiPopup.kbdIndex + 1);
            event.accepted = true;
        } else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) {
            wifiPopup._activateAt(wifiPopup.kbdIndex);
            event.accepted = true;
        }
    }

    onRevealedChanged: {
        if (revealed) {
            wifiPopup.kbdIndex = 0;
            root.refreshWifi();
        }
    }

    property int kbdIndex: 0
    readonly property int _headerCount: 3
    readonly property var _visibleNets: root.wifiRadioOn
                                        ? root.wifiNetworks.slice(0, 8)
                                        : []
    readonly property int _kbdMax: _headerCount + _visibleNets.length

    function _activateAt(i) {
        wifiPopup.kbdIndex = i;
        if (i === 0) { root.toggleWifiRadio(); return; }
        if (i === 1) { root.refreshWifi(); return; }
        if (i === 2) { root.shareWifi(root.wifiSsid); return; }
        const netIdx = i - wifiPopup._headerCount;
        if (netIdx < _visibleNets.length) {
            const net = wifiPopup._visibleNets[netIdx];
            if (!net) return;
            if (net.inUse) root.disconnectWifi();
            else root.connectWifi(net.ssid);
            return;
        }
    }

    footer: root.wifiRadioOn && root.wifiNetworks.length > 0
            ? "\u2191\u2193 CYCLE  \u00b7  \u23CE CONNECT  \u00b7  ESC CLOSE"
            : root.wifiRadioOn
              ? "\u2191\u2193 CYCLE  \u00b7  \u23CE TOGGLE  \u00b7  ESC CLOSE"
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
            model: wifiPopup._visibleNets

            delegate: Rectangle {
                required property var modelData
                required property int index

                readonly property int localIndex: index + wifiPopup._headerCount
                readonly property bool isConnected: modelData.inUse === true || modelData.inUse === "1"
                readonly property bool isFocused: wifiPopup.kbdIndex === localIndex

                width: parent.width
                height: 38
                radius: root.cornerRadius
                color: isConnected || isFocused
                       ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.20)
                       : (netMouse.containsMouse
                          ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)
                          : "transparent")
                border.color: isConnected || isFocused ? root.seal : "transparent"
                border.width: isConnected || isFocused ? 1.5 : 0
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                Text {
                    id: barsIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.wifiBarsGlyph(modelData.signal)
                    color: isConnected ? root.seal : root.ink
                    font.family: root.mono
                    font.pixelSize: 16
                }
                Text {
                    anchors.left: barsIcon.right
                    anchors.right: secTag.left
                    anchors.leftMargin: 10
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.ssid
                    elide: Text.ElideRight
                    color: isConnected ? root.ink : root.fg
                    font.family: root.mono
                    font.pixelSize: 11
                    font.weight: isConnected ? Font.Medium : Font.Normal
                }
                Text {
                    id: secTag
                    anchors.right: sigText.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.security && modelData.security.length > 0
                          && modelData.security !== "open" ? "\uF032" : ""
                    color: root.inkDeep
                    font.family: root.mono
                    font.pixelSize: 12
                }
                Text {
                    id: sigText
                    anchors.right: isConnected ? dot.left : parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.signal + "%"
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
                    id: netMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: wifiPopup._activateAt(localIndex)
                }
            }
        }

        Text {
            visible: root.wifiRadioOn && root.wifiNetworks.length === 0 && !root.wifiScanning
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "NO NETWORKS FOUND"
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

        // Hotspot — disabled, feature not finished
        // Rectangle {
        //     readonly property int localIndex: wifiPopup._headerCount + wifiPopup._visibleNets.length
        //     readonly property bool isHotspotFocused: wifiPopup.kbdIndex === localIndex
        //
        //     width: parent.width
        //     height: 38
        //     radius: root.cornerRadius
        //     color: isHotspotFocused
        //            ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.20)
        //            : hotspotMouse.containsMouse
        //              ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)
        //              : "transparent"
        //     border.color: isHotspotFocused ? root.seal : "transparent"
        //     border.width: isHotspotFocused ? 1.5 : 0
        //     Behavior on color { ColorAnimation { duration: 120 } }
        //     Behavior on border.color { ColorAnimation { duration: 120 } }
        //
        //     Text {
        //         id: hotspotIcon
        //         anchors.left: parent.left
        //         anchors.leftMargin: 12
        //         anchors.verticalCenter: parent.verticalCenter
        //         text: root.icoHotspot
        //         color: root.hotspotActive ? root.seal : root.inkDeep
        //         font.family: root.mono
        //         font.pixelSize: 16
        //     }
        //     Text {
        //         anchors.left: hotspotIcon.right
        //         anchors.leftMargin: 10
        //         anchors.verticalCenter: parent.verticalCenter
        //         text: "HOTSPOT"
        //         color: root.ink
        //         font.family: root.mono
        //         font.pixelSize: 11
        //     }
        //
        //     Text {
        //         anchors.right: hotspotBtn.left
        //         anchors.rightMargin: 10
        //         anchors.verticalCenter: parent.verticalCenter
        //         text: root.hotspotActive
        //               ? (root.hotspotClients > 0
        //                  ? "ACTIVE \u00b7 " + root.hotspotClients + " CLIENT(S)"
        //                  : "ACTIVE")
        //               : ""
        //         color: root.seal
        //         font.family: root.mono
        //         font.pixelSize: 9
        //         font.letterSpacing: 1
        //         visible: text.length > 0
        //     }
        //
        //     QuickButton {
        //         id: hotspotBtn
        //         root: wifiPopup.root
        //         anchors.right: parent.right
        //         anchors.rightMargin: 8
        //         anchors.verticalCenter: parent.verticalCenter
        //         label: root.hotspotActive ? "STOP" : "START"
        //         selected: root.hotspotActive
        //         onClicked: root.toggleHotspot()
        //     }
        //
        //     MouseArea {
        //         id: hotspotMouse
        //         anchors.fill: parent
        //         hoverEnabled: true
        //         cursorShape: Qt.PointingHandCursor
        //         onClicked: wifiPopup._activateAt(localIndex)
        //     }
        // }
    }
}
