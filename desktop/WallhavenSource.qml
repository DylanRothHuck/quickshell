import QtQuick
import Quickshell
import Quickshell.Io

// Live results from wallhaven.cc. Driven by `query` (empty -> SFW toplist
// of the last month, otherwise -> relevance search). Picking an item
// downloads the full image into aether's wallpaper directory and runs
// `aether --generate` to build a theme.
//
// Parameters mirror the omarchy-theme-from-wallhaven defaults: purity=100
// (SFW), categories=100 (General). Anonymous API access — no key needed.
Item {
    id: source

    required property var navbar  // for navbar.run(cmd) and HOME env

    property var  items: []
    property int  page: 1
    property int  selectedIndex: -1
    property bool loading: false
    property string query: ""

    // Toggled by AetherPopup so this source only fetches while in
    // wallhaven mode. First flip from false→true kicks the cold-open.
    property bool active: false

    readonly property string url: {
        const q = source.query.trim();
        const base = "https://wallhaven.cc/api/v1/search"
                   + "?sorting=" + (q === "" ? "toplist" : "relevance")
                   + "&topRange=1M&purity=100&categories=100"
                   + "&page=" + source.page;
        return q === "" ? base : base + "&q=" + encodeURIComponent(q);
    }

    function loadPage(n) {
        source.page = Math.max(1, n);
        source.loading = true;
        probe.running = false;
        probe.running = true;
    }

    function refresh() {
        source.loadPage(source.page);
    }

    function moveSelection(delta) {
        const n = source.items.length;
        if (n === 0) { source.selectedIndex = -1; return; }
        const cur = source.selectedIndex < 0 ? 0 : source.selectedIndex;
        let next = cur + delta;
        if (next < 0) next = 0;
        else if (next >= n) next = n - 1;
        source.selectedIndex = next;
    }

    // Download into aether's wallpaper dir (matches omarchy convention
    // so the picked image also shows up in `aether --list-wallpapers`)
    // and hand the local path to `aether --generate`. Caching means
    // re-applying a previously-picked image skips the network.
    function applyItem(item) {
        if (!item || !item.path) return;
        const url = item.path;
        const fname = url.split("/").pop();
        const dest = Quickshell.env("HOME") + "/.local/share/aether/wallpapers/" + fname;
        source.navbar.run(
            "mkdir -p \"$(dirname " + JSON.stringify(dest) + ")\""
            + " && { [ -f " + JSON.stringify(dest) + " ]"
            + "       || curl -fsSL --max-time 60 -o " + JSON.stringify(dest) + " " + JSON.stringify(url) + "; }"
            + " && aether --generate " + JSON.stringify(dest)
        );
    }

    // 300ms debounce so each keystroke doesn't fire a wallhaven request.
    Timer {
        id: queryDebounce
        interval: 300
        repeat: false
        onTriggered: {
            source.page = 1;
            source.loadPage(1);
        }
    }

    onQueryChanged: {
        if (source.active) queryDebounce.restart();
    }

    onActiveChanged: {
        if (active && items.length === 0 && !loading) source.loadPage(1);
    }

    Process {
        id: probe
        running: false
        command: ["curl", "-fsS", "--max-time", "15", source.url]
        stdout: StdioCollector {
            onStreamFinished: {
                source.loading = false;
                let arr = [];
                try {
                    const obj = JSON.parse(this.text);
                    arr = (obj.data || []).map(d => ({
                        id: d.id,
                        path: d.path,
                        thumb: (d.thumbs && d.thumbs.large) || "",
                        colors: d.colors || [],
                        resolution: d.resolution || "",
                        ratio: d.ratio || ""
                    })).filter(d => d.thumb && d.path);
                } catch (_) { arr = []; }
                source.items = arr;
                source.selectedIndex = arr.length > 0 ? 0 : -1;
            }
        }
    }
}
