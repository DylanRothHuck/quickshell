//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

// Combined entry point: one Quickshell process hosting both the navbar and
// the omni-menu command palette. Both share the same Theme instance, so an
// omarchy theme swap propagates atomically to bar + popups + palette.
//
// Launch with:
//   qs -n -d -c desktop
//
// Toggle the palette from a Hyprland keybind. The shell registers
// GlobalShortcut entries so the keypress is delivered to the running
// process directly (no `qs` client fork on the hot path):
//   bind = SUPER, SPACE, global, quickshell:palette-toggle
//   bind = ALT,   SPACE, global, quickshell:palette-quick
ShellRoot {
    id: root

    Theme { id: theme }

    Navbar {
        id: nav
        theme: theme
        onPaletteToggleRequested: omni.toggle()
    }
    OmniMenu { id: omni; theme: theme; navbar: nav }

    // ---------- Notification server ----------
    // Claims org.freedesktop.Notifications on D-Bus, replacing mako.
    NotificationServer {
        id: notifServer
        keepOnReload: false
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        imageSupported: true
        actionsSupported: true
        actionIconsSupported: false
        inlineReplySupported: false

        onNotification: (notification) => {
            nav.handleNotification(notification)
        }
    }

    // ---------- Toast stack ----------
    // A transparent overlay PanelWindow that hosts active notification
    // toast cards. Positioned top-right, only mapped when toasts exist.
    property var activeToasts: []

    function showNotificationToast(data) {
        const toast = toastComp.createObject(toastColumn, data);
        nav.activeToastData.push(toast);
        nav.activeToastDataChanged();
        toast.enter();
    }

    function removeToast(toast) {
        const idx = nav.activeToastData.indexOf(toast);
        if (idx !== -1) {
            nav.activeToastData.splice(idx, 1);
            nav.activeToastDataChanged();
        }
        toast.destroy();
    }

    Component {
        id: toastComp
        NotificationPopup {
            root: nav
            onDismissed: root.removeToast(this)
            onActionClicked: (id) => nav.invokeNotificationAction(id)
        }
    }

    PanelWindow {
        id: toastWindow
        visible: nav.activeToastData.length > 0
        color: "transparent"
        anchors { top: true; right: true }
        implicitWidth: 380
        implicitHeight: toastColumn.implicitHeight + 16
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "omarchy-notification-toast"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Column {
            id: toastColumn
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8
        }
    }

    NotificationCenter {
        id: ncPanel
        root: nav
    }
}
