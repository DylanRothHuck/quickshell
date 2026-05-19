import QtQuick
import Quickshell

// Combined entry point: one Quickshell process hosting both the navbar and
// the omni-menu command palette. Both share the same Theme instance, so an
// omarchy theme swap propagates atomically to bar + popups + palette.
//
// Launch with:
//   qs -n -d -c desktop
//
// Toggle the palette from a Hyprland keybind:
//   bind = SUPER, SPACE, exec, qs -c desktop ipc call palette toggle
ShellRoot {
    id: root

    Theme { id: theme }

    Navbar {
        theme: theme
        onPaletteToggleRequested: omni.toggle()
    }
    OmniMenu { id: omni; theme: theme }
}
