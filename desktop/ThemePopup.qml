import QtQuick
import Quickshell
import Quickshell.Io

CardWindow {
    id: themePopup
    property var root: ({})

    theme: root
    revealed: root.themeVisible
    cardWidth: 420
    layerNamespace: "omarchy-themes"
    title: "THEMES"
    footer: "\u25C0 / \u25B6 BROWSE  \u00B7  \u23CE APPLY  \u00B7  ESC / Q CLOSE"
    anchorEdge: "top"
    anchorBarX: themePopup.width / 2
    anchorGap: 1

    onDismiss: root.themeVisible = false
    onRevealedChanged: {
        if (revealed) {
            probeProc.running = false;
            probeProc.running = true;
        }
    }
    onKeyPressed: function(event) {
        const k = event.key;
        const n = themePopup._themes.length;
        if (n === 0) return;
        if (k === Qt.Key_Left) {
            themePopup._selectedIndex = (themePopup._selectedIndex - 1 + n) % n;
            event.accepted = true;
        } else if (k === Qt.Key_Right) {
            themePopup._selectedIndex = (themePopup._selectedIndex + 1) % n;
            event.accepted = true;
        } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
            const t = themePopup._themes[themePopup._selectedIndex];
            if (t) themePopup._apply(t);
            event.accepted = true;
        } else if (k === Qt.Key_Q) {
            root.themeVisible = false;
            event.accepted = true;
        }
    }

    property var _themes: []
    property int _selectedIndex: 0

    function _apply(t) {
        root.run("omarchy-theme-set " + t.name);
        root.themeVisible = false;
    }

    function _preview(i) {
        const t = themePopup._themes;
        if (i < 0 || i >= t.length || !t[i].preview) return "";
        return "file://" + t[i].preview;
    }

    function _prevIdx() {
        const n = themePopup._themes.length;
        return n > 1 ? (themePopup._selectedIndex - 1 + n) % n : -1;
    }

    function _nextIdx() {
        const n = themePopup._themes.length;
        return n > 1 ? (themePopup._selectedIndex + 1) % n : -1;
    }

    Process {
        id: probeProc
        running: false
        command: ["sh", "-c",
              "cur=$(cat \"$HOME/.config/omarchy/current/theme/colors.toml\" 2>/dev/null); "
            + "for d in \"$OMARCHY_PATH/themes\"/*/ \"$HOME/.local/share/omarchy/themes\"/*/ \"$HOME/.config/omarchy/themes\"/*/; do "
            + "  [ -d \"$d\" ] || continue; "
            + "  name=$(basename \"$d\"); "
            + "  prev=''; "
            + "  if [ -f \"$d/preview.png\" ]; then prev=\"$d/preview.png\"; "
            + "  elif [ -f \"$d/preview.jpg\" ]; then prev=\"$d/preview.jpg\"; "
            + "  elif [ -d \"$d/backgrounds\" ]; then "
            + "    prev=$(find \"$d/backgrounds\" -maxdepth 1 -type f -size +0c \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.avif' \\) 2>/dev/null | sort | head -n1); "
            + "  fi; "
            + "  c=$(cat \"$d/colors.toml\" 2>/dev/null); "
            + "  active=''; [ -n \"$c\" ] && [ \"$c\" = \"$cur\" ] && active='*'; "
            + "  printf '%s\t%s\t%s\n' \"$name\" \"$prev\" \"$active\"; "
            + "done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = (this.text || "").split("\n").filter(l => l);
                const out = [];
                const seen = {};
                for (let i = 0; i < lines.length; i++) {
                    const parts = lines[i].split("\t");
                    if (parts.length < 2) continue;
                    const name = parts[0];
                    if (!name) continue;
                    const preview = parts[1] || "";
                    const active = parts[2] === "*";
                    const entry = { name, preview, active };
                    const idx = seen[name];
                    if (idx !== undefined) out[idx] = entry;
                    else { seen[name] = out.length; out.push(entry); }
                }
                out.sort((a, b) => {
                    if (a.active !== b.active) return a.active ? -1 : 1;
                    return a.name.localeCompare(b.name);
                });
                themePopup._themes = out;
                const ai = out.findIndex(e => e.active);
                if (ai >= 0) themePopup._selectedIndex = ai;
                else themePopup._selectedIndex = 0;
            }
        }
    }

    Item {
        width: parent.width
        height: childrenRect.height

        Column {
            anchors { left: parent.left; right: parent.right }
            spacing: 10

            Rectangle {
                id: previewArea
                width: parent.width
                height: _centerW * 9 / 16
                radius: root.cornerRadius
                clip: true
                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.05)

                readonly property real _stripW: 45
                readonly property real _centerW: parent.width - 2 * _stripW

                Row {
                    anchors.fill: parent
                    spacing: 0

                    Item {
                        width: previewArea._stripW
                        height: parent.height
                        clip: true
                        visible: themePopup._themes.length > 1

                        Image {
                            width: previewArea._centerW + previewArea._stripW
                            x: -(previewArea._centerW)
                            height: parent.height
                            source: themePopup._preview(themePopup._prevIdx())
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            opacity: 0.5
                        }

                        Rectangle {
                            anchors.fill: parent
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.rgba(root.bg.r, root.bg.g, root.bg.b, 0.6) }
                                GradientStop { position: 1.0; color: "transparent" }
                            }
                        }
                    }

                    Item {
                        width: previewArea._centerW
                        height: parent.height
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: themePopup._preview(themePopup._selectedIndex)
                            fillMode: Image.PreserveAspectCrop
                            sourceSize { width: Math.ceil(previewArea._centerW); height: Math.ceil(parent.height) }
                            asynchronous: true
                        }
                    }

                    Item {
                        width: previewArea._stripW
                        height: parent.height
                        clip: true
                        visible: themePopup._themes.length > 1

                        Image {
                            width: previewArea._centerW + previewArea._stripW
                            height: parent.height
                            source: themePopup._preview(themePopup._nextIdx())
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            opacity: 0.5
                        }

                        Rectangle {
                            anchors.fill: parent
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 1.0; color: Qt.rgba(root.bg.r, root.bg.g, root.bg.b, 0.6) }
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: root.sep
                    border.width: 1
                    radius: root.cornerRadius
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 6
                    text: "\u25C0"
                    color: root.ink
                    font.pixelSize: 20
                    font.family: root.mono
                    opacity: 0.35
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    text: "\u25B6"
                    color: root.ink
                    font.pixelSize: 20
                    font.family: root.mono
                    opacity: 0.35
                }

                Text {
                    anchors.centerIn: parent
                    text: themePopup._themes.length > 0 && themePopup._themes[themePopup._selectedIndex].preview ? "" : "no preview"
                    color: root.inkDeep
                    font.family: root.mono
                    font.pixelSize: 11
                    font.letterSpacing: 1.5
                    visible: !(themePopup._themes.length > 0 && themePopup._themes[themePopup._selectedIndex].preview)
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: themePopup._themes.length > 0
                        ? themePopup._themes[themePopup._selectedIndex].name
                        : ""
                    color: root.ink
                    font.family: root.mono
                    font.pixelSize: 14
                    font.letterSpacing: 2
                    font.weight: Font.Medium
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: themePopup._themes.length > 0 && themePopup._themes[themePopup._selectedIndex].active
                    width: 8
                    height: 8
                    radius: 4
                    color: root.green
                }
            }
        }
    }
}
