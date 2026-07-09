import QtQuick

Item {
    id: body
    required property var root
    required property var nav
    width: parent ? parent.width : 0

    signal close()

    implicitHeight: col.implicitHeight + 8

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
            model: body.nav ? body.nav.tailscalePeers : []

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
                    text: modelData.os === "macOS" ? "\uF179"
                         : modelData.os === "iOS" ? "\uF14A"
                         : modelData.os === "windows" ? "\uF17A"
                         : modelData.os === "android" ? "\uF17B"
                         : "\uF109"
                    color: isOnline ? body.root.accent : body.root.inkDeep
                    font.family: body.root.mono
                    font.pixelSize: 14
                }
                Text {
                    anchors.left: osIcon.right
                    anchors.right: ipText.left
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
                Text {
                    id: ipText
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.ip
                    color: body.root.inkDeep
                    font.family: body.root.mono
                    font.pixelSize: 9
                    font.letterSpacing: 0.5
                    opacity: isOnline ? 0.8 : 0.4
                }
                MouseArea {
                    id: peerMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (body.root) body.root.copyToClipboard(modelData.ip);
                    }
                }
            }
        }

        Text {
            visible: body.nav && body.nav.tailscaleOnline && body.nav.tailscalePeers.length === 0
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "NO PEERS"
            color: body.root.inkDeep
            font.family: body.root.mono
            font.pixelSize: 10
            font.letterSpacing: 2
            opacity: 0.6
        }
    }
}
