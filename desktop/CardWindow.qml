import QtQuick
import Quickshell
import Quickshell.Wayland

// Tier-B popup chrome. Full-screen overlay PanelWindow + centered card with
// the OmniMenu visual language: mono-caps header (title + status subtitle),
// drop-from-top reveal, click-outside dismiss, Esc dismiss, optional
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
    property bool plain: false
    // Right-side header content (chevrons, refresh buttons, etc.). The
    // inline Component is instantiated as a Loader child; lexical scope
    // means ids declared in the popup file are reachable from inside.
    property Component headerRight: null

    // Anchored placement. anchorEdge "" (default) centres the card; "top"/
    // "bottom"/"left"/"right" hugs the bar's inner edge and centres on
    // (anchorBarX, anchorBarY) along the parallel axis, clamped on-screen.
    // The Scale origin tracks the trigger so a clamped card still feels
    // rooted in the icon the user clicked.
    property string anchorEdge: ""
    property real   anchorBarX: 0
    property real   anchorBarY: 0
    property real   anchorGap: 0
    readonly property bool _anchored: anchorEdge === "top"  || anchorEdge === "bottom"
                                   || anchorEdge === "left" || anchorEdge === "right"

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
            duration: card.plain ? 0 : (card.revealed ? 180 : 100)
            easing.type: card.revealed ? Easing.OutCubic : Easing.InCubic
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: card.dismiss()
    }

    // Clipping viewport — for top-anchored cards the clip hides any part of
    // the card above the bar's bottom edge during the drop-from-top animation.
    Item {
        id: cardViewport
        clip: card.anchorEdge === "top"
        x: {
            if (!card._anchored) return (cardViewport.parent.width - card.cardWidth) / 2;
            if (card.anchorEdge === "left")  return card.theme.barHeight + card.anchorGap;
            if (card.anchorEdge === "right") return cardViewport.parent.width - card.theme.barHeight - card.cardWidth - card.anchorGap;
            return Math.max(card.anchorGap,
                            Math.min(cardViewport.parent.width - card.cardWidth - card.anchorGap,
                                     card.anchorBarX - card.cardWidth / 2));
        }
        y: {
            if (card.anchorEdge === "top")    return card.theme.barHeight + card.anchorGap;
            if (card.anchorEdge === "bottom") return cardViewport.parent.height - card.theme.barHeight - surface.height - card.anchorGap;
            if (card._anchored) {
                return Math.max(card.anchorGap,
                                Math.min(cardViewport.parent.height - surface.height - card.anchorGap,
                                         card.anchorBarY - surface.height / 2));
            }
            return (cardViewport.parent.height - surface.height) / 2;
        }
        width: card.cardWidth
        height: surface.height

        Rectangle {
            id: surface
            x: 0
            width: parent.width
            height: card.cardHeight > 0 ? card.cardHeight : (bodyCol.implicitHeight + 34)
            color: card.theme.bg
            border.color: card.theme.sep
            border.width: 1
            radius: card.plain ? 0 : card.theme.cornerRadius

            opacity: card.plain ? 1 : 0.3 + 0.7 * card._reveal
            Behavior on opacity {
                NumberAnimation {
                    duration: card.plain ? 0 : 100
                    easing.type: Easing.OutCubic
                }
            }

            transform: Translate {
                y: card.plain ? 0 : (1 - card._reveal) * -(surface.height + 24)
            }

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
            anchors.margins: card.plain ? 14 : 17
            spacing: card.plain ? 10 : 12

            Item {
                width: parent.width
                height: 43
                visible: card.title.length > 0 || card.subtitle.length > 0 || card.headerRight !== null

                Column {
                    anchors.left: parent.left
                    anchors.right: headerRightLoader.left
                    anchors.rightMargin: card.headerRight ? 12 : 0
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text {
                        visible: card.title.length > 0
                        text: card.title
                        color: card.theme.ink
                        font.family: card.theme.mono
                        font.pixelSize: card.plain ? 15 : 19
                        font.letterSpacing: card.plain ? 3 : 4
                        font.weight: Font.Medium
                    }
                    Text {
                        visible: card.subtitle.length > 0
                        width: parent.width
                        elide: Text.ElideRight
                        text: card.subtitle
                        color: card.theme.inkDeep
                        font.family: card.theme.mono
                        font.pixelSize: 11
                        font.letterSpacing: 2
                    }
                }

                Loader {
                    id: headerRightLoader
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    sourceComponent: card.headerRight
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
                color: card.theme.inkDeep
                font.family: card.theme.mono
                font.pixelSize: 10
                font.letterSpacing: 2
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                opacity: 0.7
            }
        }
    }
}
}
