import QtQuick
import Quickshell
import Quickshell.Io

CardWindow {
    id: wpPopup
    property var root: ({})

    theme: root
    revealed: root.wallpaperVisible
    cardWidth: 440
    layerNamespace: "omarchy-wallpaper"
    title: "WALLPAPERS"
    footer: "\u25C0 / \u25B6 BROWSE  \u00B7  \u23CE APPLY  \u00B7  ESC / Q CLOSE"
    anchorEdge: "top"
    anchorBarX: wpPopup.width / 2
    anchorGap: 1

    onDismiss: root.wallpaperVisible = false
    onRevealedChanged: {
        if (revealed) {
            probeProc.running = false;
            probeProc.running = true;
        }
    }
    onKeyPressed: function(event) {
        const k = event.key;
        const n = wpPopup._items.length;
        if (n === 0) return;
        if (k === Qt.Key_Left) {
            wpPopup._selectedIndex = (wpPopup._selectedIndex - 1 + n) % n;
            event.accepted = true;
        } else if (k === Qt.Key_Right) {
            wpPopup._selectedIndex = (wpPopup._selectedIndex + 1) % n;
            event.accepted = true;
        } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
            const it = wpPopup._items[wpPopup._selectedIndex];
            if (it) wpPopup._apply(it);
            event.accepted = true;
        } else if (k === Qt.Key_Q) {
            root.wallpaperVisible = false;
            event.accepted = true;
        }
    }

    property var _items: []
    property int _selectedIndex: 0

    function _apply(it) {
        root.run("omarchy-theme-bg-set " + it.path);
        root.wallpaperVisible = false;
    }

    function _preview(i) {
        if (i < 0 || i >= wpPopup._items.length) return "";
        return "file://" + wpPopup._items[i].path;
    }

    function _prevIdx() {
        const n = wpPopup._items.length;
        return n > 1 ? (wpPopup._selectedIndex - 1 + n) % n : -1;
    }

    function _nextIdx() {
        const n = wpPopup._items.length;
        return n > 1 ? (wpPopup._selectedIndex + 1) % n : -1;
    }

    function _prettyName(name) {
        return name
            .replace(/^[0-9]+-/, "")
            .replace(/\.[^.]+$/, "")
            .replace(/[-_]/g, " ")
            .replace(/\b\w/g, function(c) { return c.toUpperCase(); });
    }

    Process {
        id: probeProc
        running: false
        command: ["sh", "-c",
              "THEME_NAME=$(cat \"$HOME/.config/omarchy/current/theme.name\" 2>/dev/null); "
            + "THEME_DIR=\"$HOME/.config/omarchy/current/theme/backgrounds/\"; "
            + "USER_DIR=\"$HOME/.config/omarchy/backgrounds/$THEME_NAME/\"; "
            + "CURRENT=$(readlink \"$HOME/.config/omarchy/current/background\" 2>/dev/null); "
            + "for dir in \"$THEME_DIR\" \"$USER_DIR\"; do "
            + "  [ -d \"$dir\" ] || continue; "
            + "  find \"$dir\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.webp' \\) 2>/dev/null; "
            + "done | sort -u | while IFS= read -r f; do "
            + "  [ -n \"$f\" ] || continue; "
            + "  name=$(basename \"$f\"); "
            + "  active=''; [ \"$f\" = \"$CURRENT\" ] && active='*'; "
            + "  printf '%s\t%s\t%s\n' \"$f\" \"$name\" \"$active\"; "
            + "done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = (this.text || "").split("\n").filter(l => l);
                const out = [];
                const seen = {};
                for (let i = 0; i < lines.length; i++) {
                    const parts = lines[i].split("\t");
                    if (parts.length < 2) continue;
                    const path = parts[0];
                    const name = parts[1] || "";
                    const active = parts[2] === "*";
                    if (!path || !name) continue;
                    // User dir wins over theme dir for same basename
                    const idx = seen[name];
                    const entry = { path, name, active };
                    if (idx !== undefined) out[idx] = entry;
                    else { seen[name] = out.length; out.push(entry); }
                }
                out.sort((a, b) => {
                    if (a.active !== b.active) return a.active ? -1 : 1;
                    return a.name.localeCompare(b.name);
                });
                wpPopup._items = out;
                const ai = out.findIndex(e => e.active);
                if (ai >= 0) wpPopup._selectedIndex = ai;
                else wpPopup._selectedIndex = 0;
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
                        visible: wpPopup._items.length > 1

                        Image {
                            width: previewArea._centerW + previewArea._stripW
                            x: -(previewArea._centerW)
                            height: parent.height
                            source: wpPopup._preview(wpPopup._prevIdx())
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
                            source: wpPopup._preview(wpPopup._selectedIndex)
                            fillMode: Image.PreserveAspectCrop
                            sourceSize { width: Math.ceil(previewArea._centerW); height: Math.ceil(parent.height) }
                            asynchronous: true
                        }
                    }

                    Item {
                        width: previewArea._stripW
                        height: parent.height
                        clip: true
                        visible: wpPopup._items.length > 1

                        Image {
                            width: previewArea._centerW + previewArea._stripW
                            height: parent.height
                            source: wpPopup._preview(wpPopup._nextIdx())
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
                    text: wpPopup._items.length > 0 ? "" : "no wallpapers found"
                    color: root.inkDeep
                    font.family: root.mono
                    font.pixelSize: 11
                    font.letterSpacing: 1.5
                    visible: wpPopup._items.length === 0
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: wpPopup._items.length > 0
                        ? wpPopup._prettyName(wpPopup._items[wpPopup._selectedIndex].name)
                        : ""
                    color: root.ink
                    font.family: root.mono
                    font.pixelSize: 14
                    font.letterSpacing: 2
                    font.weight: Font.Medium
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: wpPopup._items.length > 0 && wpPopup._items[wpPopup._selectedIndex].active
                    width: 8
                    height: 8
                    radius: 4
                    color: root.green
                }
            }
        }
    }
}
