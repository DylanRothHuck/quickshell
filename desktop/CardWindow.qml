import QtQuick
import Quickshell
import Quickshell.Wayland

// Tier-B popup chrome. Full-screen overlay PanelWindow + centered card with
// the OmniMenu visual language: mono-caps header (title + status subtitle),
// scale-from-center reveal, click-outside dismiss, Esc dismiss, optional
// footer hint line. Widgets put their own body inside as default children
// and listen to keyPressed() for widget-specific keyboard nav.
//
// Usage:
//   CardWindow {
//       theme: root
//       revealed: root.aetherVisible
//       onDismiss: root.aetherVisible = false
//       onKeyPressed: function(event) { ... widget keys ... }
//       title: "AETHER"
//       subtitle: "12 BLUEPRINTS"
//       footer: "↵ APPLY  ·  ESC CLOSE"
//       Item { ... body ... }
//   }
PanelWindow {
    id: card

    required property var theme

    property bool revealed: false
    property real cardWidth: 460
    // -1 -> auto-size from content implicit height; otherwise fixed.
    property real cardHeight: -1
    property string title: ""
    property string subtitle: ""
    property string footer: ""
    property string layerNamespace: "omarchy-card"

    signal dismiss()
    signal keyPressed(var event)

    default property alias bodyData: bodyContainer.data

    visible: revealed || _reveal > 0.001
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: layerNamespace
    WlrLayershell.keyboardFocus: revealed ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property real _reveal: revealed ? 1 : 0
    Behavior on _reveal {
        NumberAnimation {
            duration: card.revealed ? 220 : 140
            easing.type: card.revealed ? Easing.OutCubic : Easing.InCubic
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: card.dismiss()
    }

    Rectangle {
        id: surface
        anchors.centerIn: parent
        width: card.cardWidth
        height: card.cardHeight > 0 ? card.cardHeight : (bodyCol.implicitHeight + 34)
        color: card.theme.bg
        border.color: card.theme.sep
        border.width: 1
        radius: 0
        transformOrigin: Item.Center
        scale: card._reveal

        // Swallow clicks so the dismiss MouseArea doesn't fire on body taps.
        MouseArea { anchors.fill: parent }

        focus: card.revealed
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                card.dismiss();
                event.accepted = true;
                return;
            }
            card.keyPressed(event);
        }

        Column {
            id: bodyCol
            anchors.fill: parent
            anchors.margins: 17
            spacing: 12

            Item {
                width: parent.width
                height: 43
                visible: card.title.length > 0 || card.subtitle.length > 0

                Column {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text {
                        visible: card.title.length > 0
                        text: card.title
                        color: card.theme.ink
                        font.family: card.theme.mono
                        font.pixelSize: 19
                        font.letterSpacing: 4
                        font.weight: Font.Medium
                    }
                    Text {
                        visible: card.subtitle.length > 0
                        text: card.subtitle
                        color: card.theme.sumi
                        font.family: card.theme.mono
                        font.pixelSize: 11
                        font.letterSpacing: 2
                    }
                }
            }

            Rectangle {
                visible: card.title.length > 0 || card.subtitle.length > 0
                width: parent.width
                height: 1
                color: card.theme.sep
            }

            Item {
                id: bodyContainer
                width: parent.width
                height: childrenRect.height
            }

            Rectangle {
                visible: card.footer.length > 0
                width: parent.width
                height: 1
                color: card.theme.sep
                opacity: 0.5
            }

            Text {
                visible: card.footer.length > 0
                width: parent.width
                text: card.footer
                color: card.theme.sumi
                font.family: card.theme.mono
                font.pixelSize: 10
                font.letterSpacing: 2
                horizontalAlignment: Text.AlignHCenter
                opacity: 0.7
            }
        }
    }
}
