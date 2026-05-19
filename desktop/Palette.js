.pragma library

// Parser for omarchy's colors.toml palette file.
//
// The TOML grammar is tiny: `key = "value"` lines, with optional whitespace,
// inside flat sections. We only care about six top-level keys, so a one-line
// regex per line is enough — no need for a real TOML parser.
//
// parse(text) returns a plain object with the six raw hex strings (any of
// which may be missing if the file is partial), keyed by their Kanagawa
// Dragon semantic name. Caller decides what to do with missing keys.

const WANTED = {
    background: "paper",
    foreground: "ink",
    color7:     "inkDeep",
    color8:     "sumi",
    accent:     "indigo",
    color1:     "sealRaw",
};

const LINE = /^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*"([^"]+)"/;

// All key=value pairs as-is (keys lowercased for case-insensitive lookup).
function parseAll(text) {
    const out = {};
    if (!text) return out;
    const lines = text.split("\n");
    for (let i = 0; i < lines.length; i++) {
        const m = lines[i].match(LINE);
        if (m) out[m[1].toLowerCase()] = m[2];
    }
    return out;
}

// Only the six keys this shell needs, mapped onto semantic slot names.
function parse(text) {
    const all = parseAll(text);
    const out = {};
    for (const key in WANTED) {
        if (all[key]) out[WANTED[key]] = all[key];
    }
    return out;
}

// Apply a parsed palette object onto a Theme.qml instance. Properties absent
// from the parsed object are left at their current value, so a partial
// colors.toml never blanks out the live palette.
function apply(theme, palette) {
    if (palette.paper)   theme.paper   = palette.paper;
    if (palette.ink)     theme.ink     = palette.ink;
    if (palette.inkDeep) theme.inkDeep = palette.inkDeep;
    if (palette.sumi)    theme.sumi    = palette.sumi;
    if (palette.indigo)  theme.indigo  = palette.indigo;
    if (palette.sealRaw) theme.sealRaw = palette.sealRaw;
}
