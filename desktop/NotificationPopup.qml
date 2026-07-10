import QtQuick
import QtQuick.Layouts

// Individual notification toast card. Displays app name, summary (title),
// body (description), optional inline image, and action buttons.
// Lives inside NotificationStack.qml's Column and manages its own
// enter/exit animations and auto-dismiss timer.
Rectangle {
    id: popup

    required property var root
    property var notification: null
    property string notifId: ""
    property string appName: ""
    property string summary: ""
    property string body: ""
    property string image: ""
    property int urgency: 1   // 0=Low, 1=Normal, 2=Critical
    property var actions: []
    property real timeout: 5000

    signal dismissed()
    signal actionClicked(string identifier)

    width: 360
    height: contentCol.implicitHeight + 28
    radius: root.cornerRadius
    color: root.bg
    border.color: urgency === 2 ? root.seal : root.sep
    border.width: urgency === 2 ? 1.5 : 1
    opacity: _reveal

    // --- Reveal animation ---
    property real _reveal: 0
    property bool _entered: false
    property bool _exiting: false

    function enter() {
        _entered = true;
        _reveal = 1;
        dismissTimer.restart();
    }

    function exit() {
        if (_exiting) return;
        _exiting = true;
        _reveal = 0;
        exitTimer.restart();
    }

    Behavior on _reveal {
        NumberAnimation {
            duration: _reveal > 0 ? 180 : 100
            easing.type: _reveal > 0 ? Easing.OutCubic : Easing.InCubic
        }
    }

    // Slide in from right
    transform: Translate {
        x: popup._entered ? 0 : (1 - popup._reveal) * 60
    }

    Timer {
        id: dismissTimer
        interval: popup.timeout
        onTriggered: popup.exit()
    }

    Timer {
        id: exitTimer
        interval: 120
        onTriggered: popup.dismissed()
    }

    // Click anywhere to dismiss
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            dismissTimer.stop();
            popup.exit();
        }
    }

    Column {
        id: contentCol
        anchors.fill: parent
        anchors.margins: 14
        spacing: 6

        // App name header row
        Row {
            spacing: 6
            width: parent.width

            // App icon (from appIcon path or fallback glyph)
            Text {
                visible: popup.appName.length > 0
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf0f3"
                color: root.seal
                font.family: root.mono
                font.pixelSize: 11
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - (popup.appName.length > 0 ? 20 : 0)
                text: popup.appName.toUpperCase()
                elide: Text.ElideRight
                color: root.inkDeep
                font.family: root.mono
                font.pixelSize: 9
                font.letterSpacing: 2
                font.weight: Font.Medium
            }
        }

        // Summary (title)
        Text {
            visible: popup.summary.length > 0
            width: parent.width
            text: popup.summary
            elide: Text.ElideRight
            maximumLineCount: 2
            wrapMode: Text.WordWrap
            color: root.ink
            font.family: root.mono
            font.pixelSize: 13
            font.weight: Font.Bold
        }

        // Body (description)
        Text {
            visible: popup.body.length > 0
            width: parent.width
            text: popup.body
            elide: Text.ElideRight
            maximumLineCount: 3
            wrapMode: Text.WordWrap
            color: root.fg
            font.family: root.mono
            font.pixelSize: 11
            lineHeight: 1.3
        }

        // Inline image
        Image {
            visible: popup.image.length > 0
            width: parent.width
            height: Math.min(120, sourceSize.height > 0 ? sourceSize.height * (parent.width / sourceSize.width) : 120)
            fillMode: Image.PreserveAspectFit
            source: popup.image
            asynchronous: true
            cache: true
            mipmap: true
            Rectangle {
                anchors.fill: parent
                radius: root.cornerRadius
                color: "transparent"
                border.color: root.sep
                border.width: 1
            }
        }

        // Action buttons row
        Row {
            visible: popup.actions.length > 0
            spacing: 6
            width: parent.width

            Repeater {
                model: popup.actions

                Rectangle {
                    required property var modelData
                    required property int index

                    width: actionText.implicitWidth + 16
                    height: 24
                    radius: root.cornerRadius
                    color: actionMouse.containsMouse
                           ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.20)
                           : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)
                    border.color: root.sep
                    border.width: 1

                    Text {
                        id: actionText
                        anchors.centerIn: parent
                        text: (modelData.text || "Action").toUpperCase()
                        color: root.ink
                        font.family: root.mono
                        font.pixelSize: 9
                        font.letterSpacing: 1
                    }

                    MouseArea {
                        id: actionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            popup.dismissTimer.stop();
                            popup.actionClicked(modelData.identifier);
                            popup.exit();
                        }
                    }
                }
            }
        }
    }
}
