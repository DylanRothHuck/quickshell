import QtQuick

Item {
    id: body
    required property var root
    required property var nav
    width: parent ? parent.width : 0

    signal close()

    implicitHeight: col.implicitHeight + 8

    property int _copiedQuickIdx: -1
    readonly property var _displayItems: {
        const items = body.nav ? (body.nav.tailscalePeers || []).slice() : [];
        if (body.nav && body.nav.tailscaleOnline && body.nav.tailscaleIp && body.nav.tailscaleIp.length > 0) {
            items.push({ name: body.nav.tailscaleIp + "  \u2022  SELF", ip: body.nav.tailscaleIp, os: "self", online: true });
        }
        return items;
    }
    Timer {
        id: quickCopiedTimer
        interval: 900
        onTriggered: body._copiedQuickIdx = -1
    }

    Component.onCompleted: if (body.nav) body.nav.refreshTailscale()

    Column {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 6
        spacing: 10

        Item {
            width: parent.width
            height: 28

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: body.nav && body.nav.tailscaleOnline
                      ? body.nav.tailscaleOnlineCount + "/" + body.nav.tailscalePeerCount + " ONLINE"
                      : "SERVICE OFF"
                color: body.root.inkDeep
                font.family: body.root.mono
                font.pixelSize: 10
                font.letterSpacing: 2
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                QuickButton {
                    root: body.root
                    label: body.nav && body.nav.tailscaleOnline ? "STOP" : "START"
                    selected: body.nav && body.nav.tailscaleOnline
                    onClicked: if (body.nav) body.nav.toggleTailscale()
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: body.root.sep }

        Repeater {
            model: body._displayItems

            delegate: Rectangle {
                required property var modelData
                required property int index

                readonly property bool isOnline: modelData.online === true

                width: col.width
                height: 32
                radius: body.root.cornerRadius
                color: peerMouse.containsMouse
                       ? Qt.rgba(body.root.ink.r, body.root.ink.g, body.root.ink.b, 0.06)
                       : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    id: osIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.os === "self" ? "\uF0C1"
                         : modelData.os === "macOS" ? "\uF179"
                         : modelData.os === "iOS" ? "\uF179"
                         : modelData.os === "windows" ? "\uF17A"
                         : modelData.os === "android" ? "\uF17B"
                         : "\uF109"
                    color: isOnline ? body.root.accent : body.root.inkDeep
                    font.family: body.root.mono
                    font.pixelSize: 14
                }
                Text {
                    anchors.left: osIcon.right
                    anchors.right: ipArea.left
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.name
                    elide: Text.ElideRight
                    color: isOnline ? body.root.fg : body.root.inkDeep
                    font.family: body.root.mono
                    font.pixelSize: 11
                    font.weight: isOnline ? Font.Medium : Font.Normal
                    opacity: isOnline ? 1.0 : 0.6
                }
                Item {
                    id: ipArea
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 90
                    height: 14
                    clip: true

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.ip
                        color: body.root.inkDeep
                        font.family: body.root.mono
                        font.pixelSize: 9
                        font.letterSpacing: 0.5
                        opacity: body._copiedQuickIdx === index ? 0 : (isOnline ? 0.8 : 0.4)
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\u2713  COPIED"
                        color: body.root.green
                        font.family: body.root.mono
                        font.pixelSize: 9
                        font.letterSpacing: 1
                        font.weight: Font.Medium
                        opacity: body._copiedQuickIdx === index ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }
                }
                MouseArea {
                    id: peerMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (body.root) {
                            body.root.copyToClipboard(modelData.ip);
                            body._copiedQuickIdx = index;
                            quickCopiedTimer.restart();
                        }
                    }
                }
            }
        }

    }
}
