import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Bleeding-heart music wallpaper. A glowing parametric heart sits at
// the centre of the screen and pulses with the bass like a heartbeat.
// Drops of accent colour form at the heart's bottom point, fall under
// gravity, and feed a luminous pool at the foot of the screen. The
// bass-transient detector spawns burst-drops on every kick, so the
// bleeding intensifies with rhythm; a slow drip continues at silence so
// the wallpaper is never completely still.
ShellRoot {
    id: root

    // ---------- Theme palette ----------
    readonly property string colorsPath: Quickshell.env("HOME") + "/.config/omarchy/current/theme/colors.toml"
    property color accent: "#c4746e"
    property color bgColor: "#15151c"

    // ---------- Audio state ----------
    property var bands: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property var smoothBands: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property real bass: 0
    property real mids: 0
    property real highs: 0
    property real energy: 0

    // Bass-transient detector (adaptive baseline)
    property real bassEnv: 0
    property real bassPrev: 0
    property real lastBeatMs: 0

    // Continuous time, in seconds — drives the resting micro-motion.
    property real time: 0

    // ---------- Heart geometry (recomputed each tick) ----------
    property real heartCenterX: 0
    property real heartCenterY: 0
    property real heartScale: 0
    readonly property real heartBottomY: heartCenterY + 16.5 * heartScale

    // ---------- Drops + pool ----------
    // Each drop: { x, y, vx, vy, r, age, life }. Mutated in place from
    // the timer; the canvas reads it directly on each paint.
    property var drops: []
    property real poolLevel: 0   // 0..1.4, decays slowly to 0

    function parseColors(text) {
        const re = /^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*"([^"]+)"/;
        const lines = text.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const m = lines[i].match(re);
            if (!m) continue;
            if (m[1] === "color1")          root.accent  = m[2];
            else if (m[1] === "background") root.bgColor = m[2];
        }
    }

    function spawnDrop(cx, cy, vigour) {
        root.drops.push({
            x: cx + (Math.random() - 0.5) * 6 * Math.max(1, root.heartScale * 0.7),
            y: cy + Math.random() * 3,
            vx: (Math.random() - 0.5) * 0.45,
            vy: 0.15 + Math.random() * 0.55,
            r: 3.5 + Math.random() * 3.5 + vigour * 2.8,
            age: 0,
            life: 4500 + Math.random() * 2200,
        });
        // Hard cap so very long tracks don't blow memory.
        if (root.drops.length > 160) root.drops.shift();
    }

    FileView {
        id: paletteFile
        path: root.colorsPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.parseColors(paletteFile.text())
    }

    // ---------- cliamp visstream feeder ----------
    Process {
        id: vis
        command: ["cliamp", "visstream", "--fps", "30"]
        running: true
        stdout: SplitParser {
            onRead: function(line) {
                if (!line || line[0] !== "{") return;
                try {
                    const f = JSON.parse(line);
                    if (f && f.ok && Array.isArray(f.bands) && f.bands.length > 0)
                        root.bands = f.bands;
                } catch (e) { /* drop malformed frame */ }
            }
        }
        onRunningChanged: if (!running) restartTimer.start()
    }
    Timer {
        id: restartTimer
        interval: 3000; repeat: false
        onTriggered: vis.running = true
    }

    // ---------- 60 fps tick ----------
    // Single timer handles: band smoothing, transient detection, heart
    // geometry update, drop physics, pool decay, and paint kick.
    Timer {
        interval: 16
        running: true
        repeat: true
        onTriggered: {
            // ----- Band smoothing -----
            const n = root.bands.length;
            if (n) {
                const prev = root.smoothBands;
                const out = new Array(n);
                const splitMidLo = Math.max(1, Math.floor(n * 0.3));
                const splitMidHi = Math.max(splitMidLo + 1, Math.floor(n * 0.7));
                let lo = 0, mi = 0, hi = 0, sum = 0;
                for (let i = 0; i < n; i++) {
                    const t = root.bands[i] || 0;
                    const p = prev[i] || 0;
                    const nxt = t > p ? p + (t - p) * 0.45 : p + (t - p) * 0.10;
                    out[i] = nxt;
                    sum += nxt;
                    if (i < splitMidLo)      lo += nxt;
                    else if (i < splitMidHi) mi += nxt;
                    else                     hi += nxt;
                }
                root.smoothBands = out;
                root.energy = sum / n;
                root.bass   = lo / splitMidLo;
                root.mids   = mi / (splitMidHi - splitMidLo);
                root.highs  = hi / (n - splitMidHi);
            }

            // ----- Heart geometry -----
            // Recomputed here so the spawner and the paint pass agree on
            // where the heart is, including its current beat-scaled size.
            if (canvas.width > 0 && canvas.height > 0) {
                root.heartCenterX = canvas.width / 2;
                root.heartCenterY = canvas.height * 0.46;
                const baseScale = canvas.height * 0.011;
                // Heartbeat: bass pumps the heart by up to +9%, plus a
                // tiny resting breath so it isn't dead-still at silence.
                root.heartScale = baseScale
                    * (1.0 + root.bass * 0.09 + Math.sin(root.time * 1.2) * 0.006);
            }

            // ----- Bass-transient detector -----
            root.bassEnv = root.bassEnv * 0.985 + root.bass * 0.015;
            const now = Date.now();
            const threshold = Math.max(0.32, root.bassEnv * 1.55);
            const isBeat =
                   root.bass > threshold
                && root.bass > root.bassPrev + 0.05
                && now - root.lastBeatMs > 180;
            root.bassPrev = root.bass;

            // ----- Drop spawn -----
            if (root.heartScale > 0) {
                const hx = root.heartCenterX;
                const hy = root.heartBottomY;
                if (isBeat) {
                    root.lastBeatMs = now;
                    const burst = 2 + Math.floor(root.bass * 4);
                    for (let k = 0; k < burst; k++) root.spawnDrop(hx, hy, root.bass);
                }
                // Steady gentle drip even between beats, scaled by energy.
                if (Math.random() < 0.022 + root.energy * 0.28)
                    root.spawnDrop(hx, hy, root.energy * 0.6);
            }

            // ----- Drop physics -----
            const list = root.drops;
            const H = canvas.height || 1;
            const poolTop = H * 0.92;
            let i = 0;
            while (i < list.length) {
                const d = list[i];
                d.vy += 0.18;        // gravity
                d.vx *= 0.995;       // tiny horizontal damping
                d.x += d.vx;
                d.y += d.vy;
                d.age += 16;
                if (d.y >= poolTop || d.age > d.life) {
                    if (d.y >= poolTop)
                        root.poolLevel = Math.min(1.4, root.poolLevel + 0.025);
                    list.splice(i, 1);
                } else {
                    i++;
                }
            }
            // Slow pool drainage so it doesn't pin forever after loud passages.
            root.poolLevel = Math.max(0, root.poolLevel - 0.0025);

            // ----- Advance time & paint -----
            root.time += 0.016;
            if (canvas.available) canvas.requestPaint();
        }
    }

    // ---------- Wallpaper surface ----------
    PanelWindow {
        id: wp
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "music-wallpaper"
        exclusionMode: ExclusionMode.Ignore
        mask: Region {}

        // 1) Vertical gradient base — slightly darker at the bottom so
        //    the pool reads as light rising up from the floor.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.darker(root.bgColor, 1.05) }
                GradientStop { position: 1.0; color: Qt.darker(root.bgColor, 1.50) }
            }
        }

        // 2) Soft accent halo behind the heart. Painted as a plain Quick
        //    Item (not in canvas) so the canvas only redraws the moving
        //    bits and the halo can ride bass directly via property binding.
        Rectangle {
            id: halo
            property real r: Math.min(parent.width, parent.height) * (0.36 + root.bass * 0.16)
            anchors.horizontalCenter: parent.horizontalCenter
            // Aligned with the heart centre, not the window centre
            y: root.heartCenterY - r
            width: r * 2; height: r * 2; radius: r
            color: root.accent
            opacity: 0.05 + root.bass * 0.10
            antialiasing: true
        }

        // 3) Canvas: heart body, drops, pool. Repainted by the same 60 fps
        //    timer that drives the smoother, so reactivity and continuous
        //    flow share a single clock.
        Canvas {
            id: canvas
            anchors.fill: parent
            renderTarget: Canvas.FramebufferObject
            antialiasing: true
            smooth: true

            // Build the parametric heart path centred on the origin in
            // the heart's own unit coords. The caller is expected to have
            // already translated/scaled.
            function tracePath(ctx) {
                ctx.beginPath();
                const steps = 96;
                for (let i = 0; i <= steps; i++) {
                    const t = (i / steps) * Math.PI * 2;
                    const x =  16 * Math.pow(Math.sin(t), 3);
                    const y = -(13 * Math.cos(t)
                              -  5 * Math.cos(2 * t)
                              -  2 * Math.cos(3 * t)
                              -      Math.cos(4 * t));
                    if (i === 0) ctx.moveTo(x, y);
                    else         ctx.lineTo(x, y);
                }
                ctx.closePath();
            }

            function fillHeart(ctx, cx, cy, scale, fill, alpha) {
                ctx.save();
                ctx.translate(cx, cy);
                ctx.scale(scale, scale);
                tracePath(ctx);
                ctx.globalAlpha = alpha;
                ctx.fillStyle = fill;
                ctx.fill();
                ctx.globalAlpha = 1;
                ctx.restore();
            }

            onPaint: {
                const ctx = getContext("2d");
                const w = width, h = height;
                ctx.clearRect(0, 0, w, h);

                const ar = root.accent.r, ag = root.accent.g, ab = root.accent.b;
                const cx = root.heartCenterX;
                const cy = root.heartCenterY;
                const s  = root.heartScale;

                // ----- Heart glow (concentric soft halos, back to front) -----
                fillHeart(ctx, cx, cy, s * 1.55,
                          Qt.rgba(ar, ag, ab, 1), 0.05 + root.bass * 0.06);
                fillHeart(ctx, cx, cy, s * 1.28,
                          Qt.rgba(ar, ag, ab, 1), 0.09 + root.bass * 0.08);
                fillHeart(ctx, cx, cy, s * 1.10,
                          Qt.rgba(ar, ag, ab, 1), 0.16 + root.bass * 0.10);

                // ----- Heart body: vertical gradient (lighter top, deeper bottom) -----
                const grad = ctx.createLinearGradient(
                    cx, cy - 6 * s,
                    cx, cy + 17 * s
                );
                grad.addColorStop(0.0, Qt.rgba(
                    Math.min(1, ar + 0.10),
                    Math.min(1, ag + 0.06),
                    Math.min(1, ab + 0.06),
                    0.93));
                grad.addColorStop(0.55, Qt.rgba(ar, ag, ab, 0.88));
                grad.addColorStop(1.0, Qt.rgba(ar * 0.65, ag * 0.65, ab * 0.65, 0.96));
                fillHeart(ctx, cx, cy, s, grad, 1.0);

                // ----- Specular highlight (the "wet" gloss on the top-left lobe) -----
                ctx.save();
                ctx.translate(cx - 5.2 * s, cy - 8.4 * s);
                ctx.scale(1.6, 0.7);
                ctx.beginPath();
                ctx.arc(0, 0, 3.0 * s, 0, Math.PI * 2);
                ctx.fillStyle = Qt.rgba(1, 1, 1, 0.16 + root.bass * 0.06);
                ctx.fill();
                ctx.restore();

                // ----- Drops -----
                const list = root.drops;
                for (let i = 0; i < list.length; i++) {
                    const d = list[i];
                    const lifeT = d.age / d.life;
                    // Fade in over first 70ms, fade out in the last quarter of life.
                    const fadeIn  = Math.min(1, d.age / 70);
                    const fadeOut = lifeT > 0.75 ? Math.max(0, 1 - (lifeT - 0.75) / 0.25) : 1;
                    const a = fadeIn * fadeOut;
                    if (a <= 0) continue;

                    // Trailing streak above the drop — short gradient ribbon
                    // that fades upward, suggesting the drop's recent travel.
                    const tailH = d.r * 4.5;
                    const tg = ctx.createLinearGradient(d.x, d.y - tailH, d.x, d.y);
                    tg.addColorStop(0.0, Qt.rgba(ar, ag, ab, 0));
                    tg.addColorStop(1.0, Qt.rgba(ar, ag, ab, a * 0.40));
                    ctx.fillStyle = tg;
                    ctx.fillRect(d.x - d.r * 0.28, d.y - tailH, d.r * 0.56, tailH);

                    // Outer halo around the drop (vertical pill via scale).
                    ctx.save();
                    ctx.translate(d.x, d.y);
                    ctx.scale(1.0, 1.55);
                    ctx.beginPath();
                    ctx.arc(0, 0, d.r * 1.55, 0, Math.PI * 2);
                    ctx.fillStyle = Qt.rgba(ar, ag, ab, a * 0.22);
                    ctx.fill();

                    // Core drop body.
                    ctx.beginPath();
                    ctx.arc(0, 0, d.r * 0.95, 0, Math.PI * 2);
                    ctx.fillStyle = Qt.rgba(ar, ag, ab, a * 0.92);
                    ctx.fill();

                    // Tiny specular dot on each drop — sells the "liquid" feel.
                    ctx.beginPath();
                    ctx.arc(-d.r * 0.30, -d.r * 0.45, d.r * 0.22, 0, Math.PI * 2);
                    ctx.fillStyle = Qt.rgba(1, 1, 1, a * 0.40);
                    ctx.fill();
                    ctx.restore();
                }

                // ----- Pool at the bottom -----
                const poolH = h * 0.10 * (0.45 + Math.min(1, root.poolLevel));
                const poolYTop = h - poolH;
                const poolA = Math.min(0.70, 0.18 + root.poolLevel * 0.50);

                // Wavy upper edge — two interfering sinusoids for organic ripple.
                ctx.beginPath();
                const samples = Math.max(80, Math.min(220, Math.round(w / 9)));
                for (let i = 0; i <= samples; i++) {
                    const u = i / samples;
                    const x = u * w;
                    const wob = Math.sin(u * 8.0 + root.time * 1.30) * 3.0
                              + Math.sin(u * 17.0 - root.time * 0.70) * 1.4;
                    const y = poolYTop + wob;
                    if (i === 0) ctx.moveTo(x, y);
                    else         ctx.lineTo(x, y);
                }
                ctx.lineTo(w, h);
                ctx.lineTo(0, h);
                ctx.closePath();

                const pg = ctx.createLinearGradient(0, poolYTop, 0, h);
                pg.addColorStop(0.0, Qt.rgba(ar, ag, ab, poolA * 0.35));
                pg.addColorStop(1.0, Qt.rgba(ar, ag, ab, poolA));
                ctx.fillStyle = pg;
                ctx.fill();
            }
        }

        // 4) Top + bottom vignette overlay — frames the heart and keeps
        //    composition tight. Sits above the canvas, never animated.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.30) }
                GradientStop { position: 0.5; color: Qt.rgba(0, 0, 0, 0.00) }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.20) }
            }
        }
    }
}
