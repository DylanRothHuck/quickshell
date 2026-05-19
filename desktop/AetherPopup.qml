import QtQuick

// Quick-handle picker: scrollable list of saved blueprints with their
// first 8 swatches and a light/dark glyph. Clicking a row applies it
// via the CLI; OPEN GUI and RANDOM REGEN chips cover the heavy actions
// so the popup remains the single left-click entry point.
CardWindow {
    id: aetherPopup
    required property var root

    theme: root
    revealed: root.aetherVisible
    cardWidth: 460
    layerNamespace: "omarchy-aether"

    title: "AETHER"
    subtitle: {
        const r = aetherPopup.root;
        if (r.aetherLoading) return "LOADING…";
        const total = r.aetherBlueprints.length;
        if (total === 0) return "NO BLUEPRINTS";
        const shown = r.aetherFiltered.length;
        if (r.aetherQuery === "") return total + " BLUEPRINTS";
        return shown === 0
            ? "NO MATCHES"
            : shown + " / " + total + " MATCH" + (shown === 1 ? "" : "ES");
    }
    footer: "TYPE TO FILTER  ·  TAB ↑↓ NAV  ·  ↵ APPLY  ·  ESC CLOSE"

    onDismiss: aetherPopup.root.aetherVisible = false

    // Popup doubles as a search field — Esc is handled by CardWindow;
    // every printable key feeds the query so single-letter mnemonics
    // (g, r) land in the filter instead of firing actions.
    onKeyPressed: function(event) {
        const r = aetherPopup.root;
        const k = event.key;
        const mods = event.modifiers;
        if (k === Qt.Key_Down
            || (k === Qt.Key_Tab && !(mods & Qt.ShiftModifier))) {
            r.moveAetherSelection(1, true);
            aetherList.positionViewAtIndex(r.selectedAether, ListView.Contain);
        } else if (k === Qt.Key_Up
                   || k === Qt.Key_Backtab
                   || (k === Qt.Key_Tab && (mods & Qt.ShiftModifier))) {
            r.moveAetherSelection(-1, true);
            aetherList.positionViewAtIndex(r.selectedAether, ListView.Contain);
        } else if (k === Qt.Key_PageDown) {
            r.moveAetherSelection(8, false);
            aetherList.positionViewAtIndex(r.selectedAether, ListView.Contain);
        } else if (k === Qt.Key_PageUp) {
            r.moveAetherSelection(-8, false);
            aetherList.positionViewAtIndex(r.selectedAether, ListView.Contain);
        } else if (k === Qt.Key_Home) {
            if (r.aetherFiltered.length > 0) {
                r.selectedAether = 0;
                aetherList.positionViewAtIndex(0, ListView.Beginning);
            }
        } else if (k === Qt.Key_End) {
            const n = r.aetherFiltered.length;
            if (n > 0) {
                r.selectedAether = n - 1;
                aetherList.positionViewAtIndex(n - 1, ListView.End);
            }
        } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
            const e = r.aetherFiltered[r.selectedAether];
            if (e) r.applyAetherBlueprint(e.name);
        } else if (k === Qt.Key_Backspace) {
            if (r.aetherQuery.length > 0)
                r.aetherQuery = r.aetherQuery.slice(0, -1);
        } else if (event.text && event.text.length === 1) {
            const ch = event.text;
            if (ch.charCodeAt(0) >= 32 && ch.charCodeAt(0) !== 127) {
                r.aetherQuery += ch;
            } else {
                return;
            }
        } else {
            return;
        }
        event.accepted = true;
    }

    // Body
    Column {
        width: parent.width
        spacing: 12

        Item {
            width: parent.width
            height: 28

            Text {
                id: aetherSearchGlyph
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: aetherPopup.root.icoSearch
                color: aetherPopup.root.seal
                font.family: aetherPopup.root.mono
                font.pixelSize: 14
            }

            Text {
                id: aetherQueryText
                anchors.left: aetherSearchGlyph.right
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: aetherPopup.root.aetherQuery.length === 0
                      ? "Filter blueprints…"
                      : aetherPopup.root.aetherQuery
                color: aetherPopup.root.aetherQuery.length === 0
                       ? aetherPopup.root.inkDeep : aetherPopup.root.ink
                opacity: aetherPopup.root.aetherQuery.length === 0 ? 0.5 : 1.0
                font.family: aetherPopup.root.mono
                font.pixelSize: 12
                font.letterSpacing: 1
            }

            Rectangle {
                width: 2
                height: 14
                color: aetherPopup.root.seal
                anchors.verticalCenter: parent.verticalCenter
                x: aetherPopup.root.aetherQuery.length === 0
                   ? aetherSearchGlyph.x + aetherSearchGlyph.width + 10
                   : aetherQueryText.x + aetherQueryText.contentWidth + 2
                visible: aetherPopup.root.aetherVisible
                SequentialAnimation on opacity {
                    running: aetherPopup.root.aetherVisible
                    loops: Animation.Infinite
                    NumberAnimation { from: 1; to: 0.2; duration: 600; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 0.2; to: 1; duration: 600; easing.type: Easing.InOutSine }
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: aetherPopup.root.sep }

        ListView {
            id: aetherList
            width: parent.width
            height: 360
            clip: true
            model: aetherPopup.root.aetherFiltered
            spacing: 0
            currentIndex: aetherPopup.root.selectedAether
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: aeRow
                required property var modelData
                required property int index
                width: aetherList.width
                height: 34

                readonly property bool selected: aetherPopup.root.selectedAether === aeRow.index

                Rectangle {
                    anchors.fill: parent
                    color: rowMouse.containsMouse
                           ? Qt.rgba(aetherPopup.root.ink.r, aetherPopup.root.ink.g, aetherPopup.root.ink.b, 0.10)
                           : (aeRow.selected
                              ? Qt.rgba(aetherPopup.root.ink.r, aetherPopup.root.ink.g, aetherPopup.root.ink.b, 0.04)
                              : "transparent")
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                Rectangle {
                    visible: aeRow.selected
                    width: 2
                    height: parent.height - 10
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    color: aetherPopup.root.seal
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 175
                    elide: Text.ElideRight
                    text: aeRow.modelData.name
                    color: aeRow.selected ? aetherPopup.root.ink : aetherPopup.root.inkDeep
                    font.family: aetherPopup.root.mono
                    font.pixelSize: 11
                    font.letterSpacing: 1
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 190
                    anchors.verticalCenter: parent.verticalCenter
                    text: aeRow.modelData.lightMode ? "L" : "D"
                    color: aetherPopup.root.inkDeep
                    font.family: aetherPopup.root.mono
                    font.pixelSize: 9
                    font.letterSpacing: 1
                    opacity: 0.7
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Repeater {
                        model: (aeRow.modelData.colors || []).slice(0, 8)
                        delegate: Rectangle {
                            required property var modelData
                            width: 14
                            height: 14
                            color: modelData
                            border.color: Qt.rgba(0, 0, 0, 0.25)
                            border.width: 1
                        }
                    }
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: aetherPopup.root.selectedAether = aeRow.index
                    onClicked: aetherPopup.root.applyAetherBlueprint(aeRow.modelData.name)
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: aetherPopup.root.sep }

        Item {
            width: parent.width
            height: 26
            DisplayChip {
                root: aetherPopup.root
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                label: "OPEN GUI"
                onActivated: {
                    aetherPopup.root.run("aether");
                    aetherPopup.root.aetherVisible = false;
                }
            }
            DisplayChip {
                root: aetherPopup.root
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                label: "RANDOM REGEN"
                onActivated: {
                    aetherPopup.root.run("sh -c 'aether --generate \"$(aether --random-wallpaper)\"'");
                    aetherPopup.root.aetherVisible = false;
                }
            }
        }
    }
}
