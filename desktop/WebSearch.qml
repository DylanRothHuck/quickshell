import QtQuick
import Quickshell.Io
import "Data.js" as Data

// Web search drill. Default engine is a self-hosted omni search
// — the synthetic "Search with omni for …" entry opens the query
// in the browser at omniSearchUrl. DuckDuckGo's Instant Answer API
// runs in the background (no key needed) to surface inline snippets
// when available. SearXNG and Google are additional backup entries.
Item {
    id: webSearch

    required property string query
    required property bool active
    required property var selectedItem

    property string omniSearchUrl:   "http://dylans-mac-mini:8087/search?q="
    property string searxngSearchUrl: "http://dylans-mac-mini:8080/search?q="

    property var items: []
    property string previewUrl: ""
    property string previewTitle: ""
    property string previewDomain: ""
    property string previewSnippet: ""
    readonly property bool running: searchProc.running

    function clear() {
        webSearch.items = [];
        webSearch.previewUrl = "";
        webSearch.previewTitle = "";
        webSearch.previewDomain = "";
        webSearch.previewSnippet = "";
        webDebounce.stop();
    }
    function restart() {
        if (!webSearch.active) return;
        webDebounce.stop();
        webDebounce.triggered();
    }

    function updatePreview() {
        if (!webSearch.active) return;
        const it = webSearch.selectedItem;
        const url = (it && it.path) || "";
        if (url === webSearch.previewUrl) return;
        webSearch.previewUrl = url;
        webSearch.previewTitle = (it && it.title) || "";
        webSearch.previewDomain = (it && it.category) || "";
        webSearch.previewSnippet = (it && it.comment) || "";
    }

    function extractDomain(url) {
        if (!url) return "";
        const m = url.match(/^https?:\/\/([^\/]+)/);
        return m ? m[1] : "";
    }

    function synthEntries(q) {
        const out = [];
        const seen = {};
        if (q.length === 0) return { out, seen };
        const omniUrl = webSearch.omniSearchUrl + encodeURIComponent(q);
        out.push({
            title: "Search with omni for \"" + q + "\"",
            comment: "Open query in your omni search instance",
            keywords: "", category: "omni", icon: "󰖟",
            path: omniUrl, exec: Data.openUrl(omniUrl), rawCategory: true
        });
        seen[omniUrl] = true;
        const searxngUrl = webSearch.searxngSearchUrl + encodeURIComponent(q);
        out.push({
            title: "Search with SearXNG for \"" + q + "\"",
            comment: "Open query in SearXNG",
            keywords: "", category: "SearXNG", icon: "󰖟",
            path: searxngUrl, exec: Data.openUrl(searxngUrl), rawCategory: true
        });
        seen[searxngUrl] = true;
        const googleUrl = "https://www.google.com/search?q=" + encodeURIComponent(q);
        out.push({
            title: "Search Google for \"" + q + "\"",
            comment: "Open query in Google Search (backup)",
            keywords: "", category: "Google", icon: "󰖟",
            path: googleUrl, exec: Data.openUrl(googleUrl), rawCategory: true
        });
        seen[googleUrl] = true;
        for (const m of [["gemma4:e2b","gemma4:e2b"],["nemotron-3-super:cloud","nemotron-3-super:cloud"]]) {
            out.push({
                title: "Ask " + m[1] + " \"" + q + "\"",
                comment: "Open an inline chat with " + m[0],
                keywords: "", category: "AI", icon: "󱚤",
                rawCategory: true, isAiChat: true, modelName: m[0]
            });
        }
        return { out, seen };
    }

    function parseResults(text) {
        try {
            const data = JSON.parse(text || "{}");
            const q = webSearch.query.trim();
            const s = webSearch.synthEntries(q);
            const out = s.out;
            const seen = s.seen;

            function push(url, title, snippet) {
                if (!url || seen[url]) return;
                seen[url] = true;
                out.push({
                    title: title || "Untitled",
                    comment: (snippet || "").substring(0, 300),
                    keywords: "",
                    category: webSearch.extractDomain(url),
                    icon: "󰖟",
                    path: url,
                    exec: Data.openUrl(url),
                    rawCategory: true
                });
            }

            function splitText(text) {
                if (!text) return ["", ""];
                const dash = text.indexOf(" - ");
                if (dash < 0) return [text, ""];
                return [text.substring(0, dash), text.substring(dash + 3)];
            }

            const results = data.Results || [];
            for (let i = 0; i < results.length; i++) {
                const r = results[i];
                const [title, snippet] = splitText(r.Text);
                push(r.FirstURL, title, snippet);
            }

            const topics = data.RelatedTopics || [];
            for (let i = 0; i < topics.length; i++) {
                const t = topics[i];
                if (t.Name && t.Topics) {
                    for (let j = 0; j < t.Topics.length; j++) {
                        const sub = t.Topics[j];
                        if (!sub.FirstURL) continue;
                        const [title, snippet] = splitText(sub.Text);
                        push(sub.FirstURL, title, snippet);
                    }
                } else if (t.FirstURL) {
                    const [title, snippet] = splitText(t.Text);
                    push(t.FirstURL, title, snippet);
                }
            }

            return out;
        } catch (_) {
            return [];
        }
    }

    onQueryChanged: { if (webSearch.active) webDebounce.restart(); }
    onActiveChanged: { if (!webSearch.active) webSearch.clear(); }
    onSelectedItemChanged: { if (webSearch.active) webSearch.updatePreview(); }
    onItemsChanged: { if (webSearch.active) webSearch.updatePreview(); }

    Timer {
        id: webDebounce
        interval: 300
        repeat: false
        onTriggered: {
            const q = webSearch.query.trim();
            if (!webSearch.active || q.length === 0) {
                webSearch.items = [];
                webSearch.updatePreview();
                return;
            }
            // Show synthetic entries (browse + AI) immediately.
            webSearch.items = webSearch.synthEntries(q).out;
            // Fire DuckDuckGo lookup in background; results merged on arrival.
            searchProc.command = ["sh", "-c",
                "curl -sL -A 'Omarchy/1.0' \"$1\" 2>/dev/null || true",
                "sh", "https://api.duckduckgo.com/?q="
                      + encodeURIComponent(q)
                      + "&format=json&no_html=1&skip_disambig=1"];
            searchProc.running = false;
            searchProc.running = true;
        }
    }

    Process {
        id: searchProc
        running: false
        command: ["true"]
        stdout: StdioCollector {
            onStreamFinished: {
                webSearch.items = webSearch.parseResults(this.text);
            }
        }
    }
}
