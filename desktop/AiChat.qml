import QtQuick
import Quickshell.Io
import "omni/Format.js" as Fmt

Item {
    id: aiChat

    required property string model
    required property string prompt
    required property bool active
    property var palette: ({ink: "#ccc", inkDeep: "#999", indigo: "#69f", seal: "#f90", paper: "#222"})

    property var items: []
    property string previewText: ""
    property string previewRaw: ""
    property bool submitted: false
    readonly property bool running: chatProc.running
    property var messages: []
    property string _accumulating: ""
    property string _error: ""
    property int _gen: 0

    signal promptSubmitted()

    function clear() {
        aiChat.items = [];
        aiChat.previewText = "";
        aiChat.previewRaw = "";
        aiChat.submitted = false;
        aiChat.messages = [];
        aiChat._accumulating = "";
        aiChat._error = "";
        aiChat._gen += 1;
        chatProc.running = false;
        aiChat.refreshItems();
    }

    function submit(msg) {
        if (!msg || msg.length === 0) return;
        aiChat.messages.push({role: "user", content: msg});
        aiChat.submitted = true;
        aiChat._accumulating = "";
        aiChat._error = "";
        aiChat._gen += 1;
        chatProc.gen = aiChat._gen;
        aiChat._buildPreview();

        const body = JSON.stringify({
            model: aiChat.model,
            messages: aiChat.messages,
            stream: true,
            options: { num_predict: 1024 }
        });
        chatProc.command = ["curl", "-sN",
            "http://dylans-mac-mini:11434/api/chat",
            "-d", body];
        chatProc.running = false;
        chatProc.running = true;
        aiChat.refreshItems();
        aiChat.promptSubmitted();
    }

    function _buildPreview() {
        const p = aiChat.palette;
        const userBg = Fmt.hex(p.indigo);
        const userFg = Fmt.hex(p.paper);
        const aiBg  = Fmt.hex(p.paper);
        const aiFg  = Fmt.hex(p.ink);

        let html = "";
        let raw = "";

        for (const m of aiChat.messages) {
            raw += "# " + (m.role === "user" ? "You:" : "AI:") + "\n";
            raw += m.content + "\n\n";

            if (m.role === "user") {
                html += '<div style="text-align: right; margin: 4px 0 10px 0;">'
                      + '<span style="background-color: ' + userBg + '; color: ' + userFg
                      + '; padding: 10px 18px;">'
                      + Fmt.esc(m.content) + '</span></div>';
            } else {
                html += '<div style="text-align: left; margin: 4px 0 10px 0;">'
                      + '<span style="background-color: ' + aiBg + '; color: ' + aiFg
                      + '; padding: 10px 18px;">'
                      + Fmt.formatChatHtml(m.content, p, null) + '</span></div>';
            }
        }

        if (aiChat._accumulating.length > 0) {
            raw += "# AI:\n" + aiChat._accumulating;
            html += '<div style="text-align: left; margin: 4px 0 10px 0;">'
                  + '<span style="background-color: ' + aiBg + '; color: ' + aiFg
                  + '; padding: 10px 18px;">'
                  + Fmt.formatChatHtml(aiChat._accumulating, p, null) + '</span></div>';
        }

        if (aiChat._error.length > 0) {
            raw += "# Error:\n" + aiChat._error;
            html += '<div style="text-align: left; margin: 4px 0 10px 0;">'
                  + '<span style="background-color: ' + Fmt.hex(p.seal) + '; color: ' + userFg
                  + '; padding: 10px 18px;">Error: '
                  + Fmt.esc(aiChat._error) + '</span></div>';
        }

        aiChat.previewRaw = raw;
        aiChat.previewText = html;
    }

    function refreshItems() {
        if (!aiChat.active) { aiChat.items = []; return; }
        const lastMsg = aiChat.messages.length > 0
            ? aiChat.messages[aiChat.messages.length - 1].content
            : (aiChat.prompt || "");
        aiChat.items = [{
            title: "AI: " + aiChat.model,
            comment: lastMsg || "type a message",
            keywords: "",
            category: "AI",
            icon: "󱚤",
            rawCategory: true,
            isAiChat: true,
            modelName: aiChat.model
        }];
    }

    onActiveChanged: {
        if (aiChat.active) {
            aiChat.refreshItems();
        } else {
            aiChat.items = [];
        }
    }

    onPromptChanged: {
        if (!aiChat.active) return;
        aiChat.refreshItems();
    }

    Process {
        id: chatProc
        running: false
        command: ["true"]
        property int gen: 0
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function (data) {
                if (chatProc.gen !== aiChat._gen) return;
                if (!data || data.length === 0) return;
                try {
                    const obj = JSON.parse(data);
                    if (obj.error) {
                        aiChat._error = obj.error;
                        aiChat._buildPreview();
                        return;
                    }
                    if (obj.done) {
                        if (aiChat._accumulating.length > 0) {
                            aiChat.messages.push({
                                role: "assistant",
                                content: aiChat._accumulating
                            });
                            aiChat._accumulating = "";
                            aiChat._buildPreview();
                        }
                        return;
                    }
                    if (typeof obj.message?.content === "string"
                        && obj.message.content.length > 0) {
                        aiChat._accumulating += obj.message.content;
                        aiChat._buildPreview();
                    }
                } catch (e) {}
            }
        }
        onExited: (code, status) => {
            if (chatProc.gen !== aiChat._gen) return;
            if (aiChat._error.length > 0) return;
            if (code !== 0 && aiChat._accumulating.length === 0
                && aiChat.messages.filter(m => m.role === "assistant").length === 0) {
                aiChat._error = "Process exited with code " + code;
                aiChat._buildPreview();
            }
        }
    }
}
