import QtQuick

// Notification center — a CardWindow panel showing notification history.
// Accessible from the bar notification module or IPC. Follows the same
// visual language as BluetoothPopup / WifiPopup.
CardWindow {
    id: ncPopup
    property var root: ({})

    theme: root
    revealed: root.notificationCenterVisible
    cardWidth: 380
    layerNamespace: "omarchy-notification-center"
    title: "NOTIFICATIONS"
    subtitle: {
        const n = root.notificationHistory.length;
        if (n === 0) return "NO NOTIFICATIONS";
        const dnd = root.notificationDnd ? "  \u00b7  DND" : "";
        return n + " NOTIFICATION" + (n !== 1 ? "S" : "") + dnd;
    }

    anchorEdge: root.barEdge
    anchorBarX: root.popupAnchorX
    anchorBarY: root.popupAnchorY

    headerRight: Row {
        spacing: 8
        QuickButton {
            root: ncPopup.root
            glyph: root.notificationDnd ? "󰂛" : "󰂚"
            selected: root.notificationDnd
            padH: 10
            onClicked: root.toggleNotificationDnd()
        }
        QuickButton {
            root: ncPopup.root
            glyph: "󰩬"
            padH: 10
            onClicked: root.clearAllNotifications()
        }
    }

    onDismiss: root.notificationCenterVisible = false
    onKeyPressed: function(event) {
        if (event.key === Qt.Key_Q) {
            root.notificationCenterVisible = false;
            event.accepted = true;
        }
    }

    onRevealedChanged: {
        if (revealed) root.notificationUnread = 0;
    }

    Column {
        width: parent.width
        spacing: 8

        Repeater {
            model: root.notificationHistory

            delegate: Rectangle {
                required property var modelData
                required property int index

                width: parent.width
                height: notifCol.implicitHeight + 20
                radius: root.cornerRadius
                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.04)
                border.color: modelData.urgency === 2 ? root.seal : "transparent"
                border.width: modelData.urgency === 2 ? 1 : 0

                Column {
                    id: notifCol
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 4

                    // Header row: app name + relative time
                    Row {
                        width: parent.width
                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - timeText.implicitWidth - 8
                            text: modelData.appName ? modelData.appName.toUpperCase() : "UNKNOWN"
                            elide: Text.ElideRight
                            color: root.inkDeep
                            font.family: root.mono
                            font.pixelSize: 9
                            font.letterSpacing: 1.5
                            font.weight: Font.Medium
                        }

                        Text {
                            id: timeText
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.timeStr || ""
                            color: root.muted
                            font.family: root.mono
                            font.pixelSize: 8
                            font.letterSpacing: 1
                        }
                    }

                    // Summary (title)
                    Text {
                        visible: modelData.summary && modelData.summary.length > 0
                        width: parent.width
                        text: modelData.summary || ""
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.WordWrap
                        color: root.ink
                        font.family: root.mono
                        font.pixelSize: 12
                        font.weight: Font.Bold
                    }

                    // Body (description)
                    Text {
                        visible: modelData.body && modelData.body.length > 0
                        width: parent.width
                        text: modelData.body || ""
                        elide: Text.ElideRight
                        maximumLineCount: 3
                        wrapMode: Text.WordWrap
                        color: root.fg
                        font.family: root.mono
                        font.pixelSize: 10
                        lineHeight: 1.25
                    }

                    // Inline image
                    Image {
                        visible: modelData.image && modelData.image.length > 0
                        width: parent.width
                        height: Math.min(100, sourceSize.height > 0 ? sourceSize.height * (parent.width / sourceSize.width) : 100)
                        fillMode: Image.PreserveAspectFit
                        source: modelData.image || ""
                        asynchronous: true
                        cache: true
                        mipmap: true
                    }

                    // Action buttons
                    Row {
                        visible: modelData.actions && modelData.actions.length > 0
                        spacing: 6

                        Repeater {
                            model: modelData.actions || []

                            Rectangle {
                                required property var modelData
                                required property int index

                                width: ncActionText.implicitWidth + 12
                                height: 22
                                radius: root.cornerRadius
                                color: ncActionMouse.containsMouse
                                       ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.20)
                                       : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)
                                border.color: root.sep
                                border.width: 1

                                Text {
                                    id: ncActionText
                                    anchors.centerIn: parent
                                    text: (modelData.text || "Action").toUpperCase()
                                    color: root.ink
                                    font.family: root.mono
                                    font.pixelSize: 8
                                    font.letterSpacing: 1
                                }

                                MouseArea {
                                    id: ncActionMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.invokeNotificationAction(modelData.identifier)
                                }
                            }
                        }
                    }
                }

                // Left-click invokes first action; right-click dismisses
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function(mouse) {
                        if (mouse.button === Qt.RightButton) {
                            root.dismissNotification(modelData.notifId);
                        } else if (modelData.actions && modelData.actions.length > 0) {
                            root.invokeNotificationAction(modelData.actions[0].identifier);
                            root.dismissNotification(modelData.notifId);
                        }
                    }
                }
            }
        }

        Text {
            visible: root.notificationHistory.length === 0
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "NO NOTIFICATIONS"
            color: root.inkDeep
            font.family: root.mono
            font.pixelSize: 10
            font.letterSpacing: 2
            opacity: 0.6
        }
    }

    footer: root.notificationHistory.length > 0
            ? "LEFT-CLICK ACTION  \u00b7  RIGHT-CLICK DISMISS  \u00b7  ESC CLOSE"
            : ""
}
