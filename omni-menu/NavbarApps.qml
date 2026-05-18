import QtQuick
import Quickshell.Io
import "Data.js" as Data

// Probes navbar's IPC surface and exposes one item per registered
// widget target. Probe re-runs on demand via probe() so widgets
// toggled at runtime don't show up stale.
Item {
    id: navbarApps

    // `category` slots each widget into an existing omarchy category so
    // it shows up where the user would already look: weather/display/
    // calendar under Toggle, screenshots/videos under Capture (next to
    // the take-a-screenshot row).
    readonly property var candidates: [
        { target: "weather",     title: "Weather",     icon: "󰖐", category: "Toggle",
          keywords: "weather forecast temperature rain sun wind cloud wttr" },
        { target: "display",     title: "Display",     icon: "󰍹", category: "Toggle",
          keywords: "display brightness warmth gamma night light monitor screen panel" },
        { target: "calendar",    title: "Calendar",    icon: "󰃭", category: "Toggle",
          keywords: "calendar date month day year week schedule planner today" },
        { target: "screenshots", title: "Screenshots", icon: "󰄀", category: "Capture",
          keywords: "screenshots browse view gallery thumbnails recent" },
        { target: "videos",      title: "Videos",      icon: "󰕧", category: "Capture",
          keywords: "videos browse view gallery thumbnails recordings recent screen record" }
    ]

    property var items: []

    function probe() {
        probeProc.running = false;
        probeProc.running = true;
    }

    Process {
        id: probeProc
        running: false
        command: ["sh", "-c", "qs -c navbar ipc show 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const available = {};
                const lines = (this.text || "").split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const m = lines[i].match(/^target (\S+)/);
                    if (m) available[m[1]] = true;
                }
                const out = [];
                const cs = navbarApps.candidates;
                for (let i = 0; i < cs.length; i++) {
                    if (!available[cs[i].target]) continue;
                    out.push({
                        title: cs[i].title,
                        icon: cs[i].icon,
                        category: cs[i].category,
                        keywords: cs[i].keywords,
                        exec: "qs -c navbar ipc call " + cs[i].target + " open"
                    });
                }
                navbarApps.items = Data.annotate(out);
            }
        }
    }

    Component.onCompleted: navbarApps.probe()
}
