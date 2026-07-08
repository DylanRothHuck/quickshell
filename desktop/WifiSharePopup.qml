import QtQuick

CardWindow {
    id: sharePopup
    property var root: ({})

    theme: root
    revealed: root.shareVisible && root.shareSsid.length > 0
    cardWidth: 340
    layerNamespace: "omarchy-wifi-share"
    title: "SHARE WI-FI"
    subtitle: root.shareSsid
    footer: "ESC CLOSE"

    anchorEdge: root.barEdge
    anchorBarX: root.popupAnchorX
    anchorBarY: root.popupAnchorY

    onDismiss: root.shareVisible = false

    Column {
        width: parent.width
        spacing: 16

        Rectangle {
            width: 240
            height: 240
            radius: root.cornerRadius
            color: "white"
            anchors.horizontalCenter: parent.horizontalCenter

            Image {
                anchors.centerIn: parent
                width: 220
                height: 220
                source: root.shareVisible
                        ? "file:///tmp/wifi-qr-share.png?_=" + (new Date().getTime())
                        : ""
                fillMode: Image.PreserveAspectFit
                cache: false
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Password: " + root.sharePassword
            color: root.ink
            font.family: root.mono
            font.pixelSize: 11
            font.weight: Font.Medium
        }
    }
}
