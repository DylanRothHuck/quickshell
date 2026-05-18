import QtQuick
import Quickshell
import Quickshell.Io
import "Data.js" as Data

// Persistent favourites + history backed by a single JSON file under
// $XDG_CACHE_HOME. Loads via Process at startup, writes via Process on
// each change. Each entry is a snapshot of the item at the moment it
// was starred or activated so the row can be re-rendered later without
// re-running the originating fd/gh search.
Item {
    id: bookmarks

    property var favourites: []
    property var history: []
    readonly property int historyCap: 50
    readonly property string statePath: Quickshell.env("HOME") + "/.cache/quickshell/omni-menu/state.json"

    readonly property var favouriteItems: Data.annotate(bookmarks.favourites)
    readonly property var historyItems: Data.annotate(bookmarks.history)

    // Stable identity per item. path (files/repos/PRs) is unique;
    // exec (apps/omarchy actions) is unique enough in practice; the
    // title+category fallback covers anything that has neither.
    function itemKey(item) {
        if (!item) return "";
        return item.path || item.exec || (item.title + "|" + item.category);
    }

    function snapshot(item) {
        return {
            title: item.title || "",
            icon: item.icon || "",
            category: item.category || "",
            exec: item.exec || "",
            path: item.path || "",
            keywords: item.keywords || "",
            rawCategory: !!item.rawCategory,
            tui: item.tui || ""
        };
    }

    function isFavourite(item) {
        const k = bookmarks.itemKey(item);
        if (!k) return false;
        for (let i = 0; i < bookmarks.favourites.length; i++) {
            if (bookmarks.itemKey(bookmarks.favourites[i]) === k) return true;
        }
        return false;
    }

    function toggleFavourite(item) {
        if (!item) return;
        const k = bookmarks.itemKey(item);
        if (!k) return;
        const next = [];
        let found = false;
        for (let i = 0; i < bookmarks.favourites.length; i++) {
            if (bookmarks.itemKey(bookmarks.favourites[i]) === k) found = true;
            else next.push(bookmarks.favourites[i]);
        }
        if (!found) next.unshift(bookmarks.snapshot(item));
        bookmarks.favourites = next;
        bookmarks.save();
    }

    function record(item) {
        // Skip drill-in nav rows — recording them would just rehash the
        // category list.
        if (!item || item.isCategory) return;
        const k = bookmarks.itemKey(item);
        if (!k) return;
        const next = [bookmarks.snapshot(item)];
        for (let i = 0; i < bookmarks.history.length && next.length < bookmarks.historyCap; i++) {
            if (bookmarks.itemKey(bookmarks.history[i]) !== k) {
                next.push(bookmarks.history[i]);
            }
        }
        bookmarks.history = next;
        bookmarks.save();
    }

    function clearHistory() {
        bookmarks.history = [];
        bookmarks.save();
    }

    function save() {
        const payload = JSON.stringify({
            favourites: bookmarks.favourites,
            history: bookmarks.history
        });
        // Positional argv keeps the path and JSON body argv-safe — no
        // shell escaping headaches even if a starred file path has
        // dollar signs or backticks in it.
        saveProc.command = ["sh", "-c",
            "mkdir -p \"$(dirname \"$1\")\" && printf '%s' \"$2\" > \"$1\"",
            "sh", bookmarks.statePath, payload];
        saveProc.running = false;
        saveProc.running = true;
    }

    Process { id: saveProc; running: false; command: ["true"] }

    Process {
        id: loadProc
        running: false
        command: ["sh", "-c", "cat \"$1\" 2>/dev/null", "sh", bookmarks.statePath]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!this.text) return;
                try {
                    const data = JSON.parse(this.text);
                    bookmarks.favourites = data.favourites || [];
                    bookmarks.history = data.history || [];
                } catch (_) {}
            }
        }
    }

    Component.onCompleted: loadProc.running = true
}
