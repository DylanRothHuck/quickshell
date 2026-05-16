# quickshell

Personal [Quickshell](https://quickshell.outfoxxed.me) configs built for [omarchy](https://omarchy.org). They read the live omarchy palette at `~/.config/omarchy/current/theme/colors.toml`, so the bar and overlay restyle themselves whenever you run `omarchy theme set <name>`.

| Module | What it does |
| --- | --- |
| [`navbar/`](./navbar) | Minimal top bar. Kanagawa Dragon layout, kanji workspace markers, omarchy-theme-aware colors. |
| [`song-drop/`](./song-drop) | MPRIS notifier. Drops a liquid blob from the bar on track change, morphs into a song-title pill, holds, then retreats. |

Each module is a self-contained Quickshell config rooted at `shell.qml`.

## Quick start

```sh
git clone https://github.com/bjarneo/quickshell ~/.config/quickshell

# disable omarchy's waybar (one-shot toggle, also bound to SUPER+SHIFT+SPACE)
omarchy toggle waybar

# launch the bar
qs -n -d -c navbar

# launch the song-drop overlay
qs -n -d -c song-drop
```

`-c <name>` resolves to `~/.config/quickshell/<name>/shell.qml`. `-d` daemonizes, `-n` makes it idempotent.

For per-module setup (autostart hooks, theme reactivity details, customization knobs, troubleshooting), see [`navbar/README.md`](./navbar/README.md).

## Requirements

- quickshell
- hyprland
- omarchy (for the live theme palette and the `omarchy toggle waybar` flow)

navbar also wants `pamixer`, `bluetoothctl`, and `nmcli` for its telemetry tiles. song-drop only needs an MPRIS-capable player (mpv, spotify, etc.).

## License

MIT.
