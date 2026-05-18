import QtQuick
import Quickshell
import Quickshell.Wayland

// Same shell as calendar/screenshots: full-screen transparent overlay
// with a centred card that scales up from its centre. Sliders, a row of
// four warmth presets, monitor cycle controls, and a reset chevron.
PanelWindow {
    id: displayPopup
    required property var root

    visible: root.displayVisible || reveal > 0.001
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-display"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property real reveal: root.displayVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: displayPopup.root.displayVisible ? 220 : 140
            easing.type: displayPopup.root.displayVisible ? Easing.OutCubic : Easing.InCubic
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: displayPopup.root.displayVisible = false
    }

    Rectangle {
        id: displayCard
        anchors.centerIn: parent
        width: 480
        height: dispCol.implicitHeight + 34
        color: displayPopup.root.bg
        border.color: displayPopup.root.sep
        border.width: 1
        radius: 0

        transformOrigin: Item.Center
        scale: displayPopup.reveal

        focus: displayPopup.root.displayVisible
        Keys.onPressed: function(event) {
            const r = displayPopup.root;
            const k = event.key;
            if (k === Qt.Key_Escape || k === Qt.Key_Q) {
                r.displayVisible = false;
            } else if (k === Qt.Key_Down || k === Qt.Key_J) {
                r.displayRow = Math.min(6, r.displayRow + 1);
            } else if (k === Qt.Key_Up || k === Qt.Key_K) {
                r.displayRow = Math.max(0, r.displayRow - 1);
            } else if (k === Qt.Key_Left || k === Qt.Key_H) {
                if (r.displayRow === 0)      r.setWarmth(r.warmthK - 250);
                else if (r.displayRow === 1) r.setBrightness(r.brightnessPct - 5);
                else if (r.displayRow === 2) r.setGamma(r.gammaPct - 5);
                else if (r.displayRow === 3) {
                    const n = r.displayPresets.length;
                    r.selectedPreset = (r.selectedPreset - 1 + n) % n;
                }
            } else if (k === Qt.Key_Right || k === Qt.Key_L) {
                if (r.displayRow === 0)      r.setWarmth(r.warmthK + 250);
                else if (r.displayRow === 1) r.setBrightness(r.brightnessPct + 5);
                else if (r.displayRow === 2) r.setGamma(r.gammaPct + 5);
                else if (r.displayRow === 3) {
                    r.selectedPreset = (r.selectedPreset + 1) % r.displayPresets.length;
                }
            } else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) {
                if (r.displayRow === 3) {
                    r.applyPreset(r.displayPresets[r.selectedPreset]);
                } else if (r.displayRow === 4) {
                    r.run("omarchy-launch-editor ~/.config/hypr/monitors.lua");
                    r.displayVisible = false;
                } else if (r.displayRow === 5) r.blankScreen();
                else if (r.displayRow === 6) r.resetDisplay();
            } else if (k >= Qt.Key_1 && k <= Qt.Key_4) {
                const idx = k - Qt.Key_1;
                if (idx < r.displayPresets.length) {
                    r.selectedPreset = idx;
                    r.applyPreset(r.displayPresets[idx]);
                }
            } else if (k === Qt.Key_R) {
                r.resetDisplay();
            } else if (k === Qt.Key_B) {
                r.blankScreen();
            } else if (k === Qt.Key_E) {
                r.run("omarchy-launch-editor ~/.config/hypr/monitors.lua");
                r.displayVisible = false;
            } else {
                return;
            }
            event.accepted = true;
        }

        // Swallow clicks so the card body doesn't bubble to the outer
        // dismiss MouseArea.
        MouseArea { anchors.fill: parent }

        Column {
            id: dispCol
            anchors.fill: parent
            anchors.margins: 17
            spacing: 12

            Item {
                width: parent.width
                height: 43

                Column {
                    anchors.left: parent.left
                    anchors.right: displayReset.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text {
                        text: "DISPLAY"
                        color: displayPopup.root.ink
                        font.family: displayPopup.root.mono
                        font.pixelSize: 19
                        font.letterSpacing: 4
                        font.weight: Font.Medium
                    }
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: Math.round(displayPopup.root.warmthK) + "K  ·  BR " + displayPopup.root.brightnessPct
                              + "  ·  γ " + Math.round(displayPopup.root.gammaPct)
                              + "  ·  " + displayPopup.root.monitorRate.toFixed(0) + "HZ"
                        color: displayPopup.root.sumi
                        font.family: displayPopup.root.mono
                        font.pixelSize: 11
                        font.letterSpacing: 2
                    }
                }

                CalendarChevron {
                    id: displayReset
                    root: displayPopup.root
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: displayPopup.root.icoRefresh
                    restColor: displayPopup.root.sumi
                    font.pixelSize: 22
                    onTriggered: displayPopup.root.resetDisplay()
                }
            }

            Rectangle { width: parent.width; height: 1; color: displayPopup.root.sep }

            Repeater {
                model: [
                    { label: "WARMTH",     valKey: "warmthK",       lo: 1000, hi: 6500, unit: "K", row: 0 },
                    { label: "BRIGHTNESS", valKey: "brightnessPct", lo: 1,    hi: 100,  unit: "%", row: 1 },
                    { label: "GAMMA",      valKey: "gammaPct",      lo: 50,   hi: 150,  unit: "",  row: 2 }
                ]
                delegate: DisplaySlider {
                    required property var modelData
                    root: displayPopup.root
                    width: dispCol.width
                    label: modelData.label
                    value: displayPopup.root[modelData.valKey]
                    minV: modelData.lo
                    maxV: modelData.hi
                    unit: modelData.unit
                    selected: displayPopup.root.displayRow === modelData.row
                    onCommit: function(v) {
                        if      (modelData.row === 0) displayPopup.root.setWarmth(v);
                        else if (modelData.row === 1) displayPopup.root.setBrightness(v);
                        else                          displayPopup.root.setGamma(v);
                    }
                    onFocusRequested: displayPopup.root.displayRow = modelData.row
                }
            }

            Rectangle { width: parent.width; height: 1; color: displayPopup.root.sep }

            Item {
                width: parent.width
                height: 38

                Text {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    text: "PRESETS"
                    color: displayPopup.root.displayRow === 3 ? displayPopup.root.seal : displayPopup.root.sumi
                    font.family: displayPopup.root.mono
                    font.pixelSize: 10
                    font.letterSpacing: 2
                    Behavior on color { ColorAnimation { duration: 140 } }
                }

                Row {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    spacing: 6

                    Repeater {
                        model: displayPopup.root.displayPresets
                        delegate: DisplayChip {
                            required property var modelData
                            required property int index
                            root: displayPopup.root
                            label: modelData.label
                            selected: displayPopup.root.selectedPreset === index
                            onActivated: {
                                displayPopup.root.selectedPreset = index;
                                displayPopup.root.displayRow = 3;
                                displayPopup.root.applyPreset(modelData);
                            }
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: displayPopup.root.sep }

            // Scale / rate / VRR are read-only — Hyprland's lua parser
            // refuses runtime `keyword monitor` ("Use eval."). The EDIT
            // chip below opens monitors.lua for persistent edits.
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: "MONITOR · " + displayPopup.root.monitorName + " · " + displayPopup.root.monitorRes
                      + " · ×" + displayPopup.root.monitorScale.toFixed(2)
                color: displayPopup.root.sumi
                font.family: displayPopup.root.mono
                font.pixelSize: 10
                font.letterSpacing: 2
            }

            Item {
                width: parent.width
                height: 26
                DisplayChip {
                    root: displayPopup.root
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    label: "EDIT MONITORS"
                    selected: displayPopup.root.displayRow === 4
                    onActivated: {
                        displayPopup.root.displayRow = 4;
                        displayPopup.root.run("omarchy-launch-editor ~/.config/hypr/monitors.lua");
                        displayPopup.root.displayVisible = false;
                    }
                }
                DisplayChip {
                    root: displayPopup.root
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    label: displayPopup.root.icoPower + " BLANK"
                    selected: displayPopup.root.displayRow === 5
                    onActivated: { displayPopup.root.displayRow = 5; displayPopup.root.blankScreen(); }
                }
                DisplayChip {
                    root: displayPopup.root
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    label: "RESET"
                    selected: displayPopup.root.displayRow === 6
                    onActivated: { displayPopup.root.displayRow = 6; displayPopup.root.resetDisplay(); }
                }
            }

            Rectangle { width: parent.width; height: 1; color: displayPopup.root.sep; opacity: 0.5 }

            Text {
                width: parent.width
                text: "↑↓ ROW · ←→ ADJUST · 1-4 PRESET · R RESET · B BLANK · E EDIT · ESC"
                color: displayPopup.root.sumi
                font.family: displayPopup.root.mono
                font.pixelSize: 9
                font.letterSpacing: 1
                opacity: 0.55
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }
    }
}
