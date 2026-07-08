import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: bar
    property var root: ({})

    color: "transparent"
    // Anchors track barEdge — three sides anchored, the side opposite
    // the bar's edge is left free for the bar's thickness to extend.
    anchors {
        top:    bar.root.barEdge !== "bottom"
        bottom: bar.root.barEdge !== "top"
        left:   bar.root.barEdge !== "right"
        right:  bar.root.barEdge !== "left"
    }
    // Cloud mode: horizontal+round only. Vertical bars keep the original
    // slab geometry to avoid breaking the proven layout.
    readonly property int cloudPad: 2
    readonly property int cloudAir: 5
    readonly property int cloudInnerAir: 2
    readonly property bool cloudMode: bar.root.round && bar.root.isHorizontal
    readonly property int extraThickness: cloudMode ? 2 * cloudPad + cloudAir + cloudInnerAir : 0
    // innerSign tells which side gets the extra outer air (away from screen).
    readonly property int innerSign: bar.root.barEdge === "top" ? 1 : (bar.root.barEdge === "bottom" ? -1 : 0)

    implicitHeight: bar.root.isHorizontal
        ? (bar.root.barAutoHide && !bar.root.barReveal ? 1 : bar.root.barHeight + extraThickness)
        : 0
    implicitWidth:  bar.root.isHorizontal ? 0 : bar.root.barHeight
    exclusiveZone:  bar.root.barAutoHide && !bar.root.barReveal
                    ? 0
                    : (bar.root.isHorizontal ? bar.root.barHeight + extraThickness : bar.root.barHeight)

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "omarchy-menu"

    // Re-claim the popup anchors when this face becomes the visible one
    // (the sibling BarHacker registers its own items while it's up). Popups
    // read these at open time, so whoever is mapped must own them.
    onVisibleChanged: if (visible) {
        bar.root.calendarAnchorItem = clockItem;
        bar.root.weatherAnchorItem = weatherMod;
        bar.root.powerProfileAnchorItem = batteryMod;
        bar.root.wifiAnchorItem = netMod;
        bar.root.btAnchorItem = btMod;
        bar.root.audioAnchorItem = audioMod;
    }

    function handleNetBurst() {
        arc.t = 0;
        arcAnim.restart();
    }

    // Content wrapper — PanelWindow doesn't support transform, so clip
    // ensures children don't spill when the window is 1px auto-hide tall.
    Item {
        id: barContent
        anchors.fill: parent
        clip: true

        // HoverHandler coexists with child MouseAreas — receives hover
        // without blocking children, so the bar stays visible while the
        // cursor is over it (prevents hide timer from firing).
        HoverHandler {
            onHoveredChanged: {
                if (hovered) {
                    bar.root.barReveal = true;
                    bar.root._barTimerStop();
                } else {
                    bar.root._barTimerRestart();
                }
            }
        }

    // In cloud mode the slab bg is replaced by a single rounded backdrop
    // sized to match the inner bar (barHeight tall, with cloudAir margins
    // on each side along the bar axis, sliding toward the inner edge so
    // outer-side air sits between cloud and screen edge).
    Rectangle {
        id: cloudBg
        visible: bar.cloudMode
        x: bar.cloudAir
        y: bar.innerSign === 1 ? bar.cloudAir : bar.cloudInnerAir
        width: parent.width - 2 * bar.cloudAir
        height: bar.root.barHeight + 2 * bar.cloudPad
        radius: bar.root.cornerRadius
        color: bar.root.bg
        z: 0
        // Idle dim, slow 6s ease both ways. Driven by states/transitions rather
        // than a Behavior with an isIdle-bound duration: that bound duration is
        // re-evaluated in the same notify pass as the opacity write and lags one
        // toggle behind, so each direction could inherit the other's speed.
        // from/to pins each direction's duration.
        opacity: 1.0
        states: State {
            name: "idle"
            when: bar.root.isIdle
            PropertyChanges { target: cloudBg; opacity: 0.7 }
        }
        transitions: [
            Transition {
                to: "idle"
                NumberAnimation { property: "opacity"; duration: 6000; easing.type: Easing.OutQuart }
            },
            Transition {
                from: "idle"
                NumberAnimation { property: "opacity"; duration: 6000; easing.type: Easing.OutQuad }
            }
        ]
    }

    // Container for clock + modules + hairlines. In cloud mode the bg
    // becomes transparent so the cloud rectangle above shows through;
    // in slab mode this acts as the bar background.
    Rectangle {
        id: slabBg
        anchors.fill: parent
        color: bar.cloudMode ? "transparent" : bar.root.bg
        // Slab-mode idle dim (cloud mode keeps this transparent + opaque; the
        // cloudBg rectangle above handles the dim there). Same states/transitions
        // approach as cloudBg, slow 6s ease in both directions.
        opacity: 1.0
        states: State {
            name: "idle"
            when: bar.root.isIdle && !bar.cloudMode
            PropertyChanges { target: slabBg; opacity: 0.7 }
        }
        transitions: [
            Transition {
                to: "idle"
                NumberAnimation { property: "opacity"; duration: 6000; easing.type: Easing.OutQuart }
            },
            Transition {
                from: "idle"
                NumberAnimation { property: "opacity"; duration: 6000; easing.type: Easing.OutQuad }
            }
        ]

        // 静 (stillness) mark, parked in the bar's trailing corner.
        // Text {
        //     visible: !bar.cloudMode
        //     anchors.right:  bar.root.isHorizontal ? parent.right  : undefined
        //     anchors.bottom: bar.root.isHorizontal ? undefined     : parent.bottom
        //     anchors.rightMargin:  bar.root.isHorizontal ? 8 : 0
        //     anchors.bottomMargin: bar.root.isHorizontal ? 0 : 8
        //     anchors.verticalCenter:   bar.root.isHorizontal ? parent.verticalCenter   : undefined
        //     anchors.horizontalCenter: bar.root.isHorizontal ? undefined : parent.horizontalCenter
        //     text: "静"
        //     color: Qt.rgba(bar.root.ink.r, bar.root.ink.g, bar.root.ink.b, 0.07)
        //     font.family: bar.root.serif
        //     font.pixelSize: bar.root.barHeight + 6
        //     font.weight: Font.Light
        //     z: 0
        // }

        // Inner-edge hairline (facing the rest of the screen). Hidden in
        // cloud mode — the rounded backdrop replaces it visually.
        Rectangle {
            visible: !bar.cloudMode && bar.root.isHorizontal
            anchors.left:   parent.left
            anchors.right:  parent.right
            anchors.top:    bar.root.barEdge === "bottom" ? parent.top    : undefined
            anchors.bottom: bar.root.barEdge === "top"    ? parent.bottom : undefined
            height: 1
            color: bar.root.sep
        }
        Rectangle {
            visible: !bar.cloudMode && !bar.root.isHorizontal
            anchors.top:    parent.top
            anchors.bottom: parent.bottom
            anchors.right:  bar.root.barEdge === "left"  ? parent.right : undefined
            anchors.left:   bar.root.barEdge === "right" ? parent.left  : undefined
            width: 1
            color: bar.root.sep
        }

        // Centre cluster: clock + omarchy indicator buttons.
        // The clock itself is a clickable Item with its own tight MouseArea;
        // indicators sit beside it as separate clickable buttons so calendar
        // and indicator clicks never conflict. Vertical bars drop indicators
        // and stack HH/MM.
        Item {
            id: centerGroup
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter:   parent.verticalCenter
            z: 10

            implicitWidth:  bar.root.isHorizontal
                            ? clockItem.implicitWidth + 14
                            : Math.max(clockHH.implicitWidth, clockMM.implicitWidth) + 8
            implicitHeight: bar.root.isHorizontal
                            ? clockItem.implicitHeight + 8
                            : (clockHH.implicitHeight + clockMM.implicitHeight + 6)

            Bloom { id: clockBloom; root: bar.root }

            // Horizontal: clock centred independently; indicators anchor to its
            // right edge so they never push the clock off-centre.
            Item {
                id: clockItem
                visible: bar.root.isHorizontal
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -1
                implicitWidth: bar.root.osdActive ? 250 : clockOneLine.implicitWidth
                implicitHeight: clockOneLine.implicitHeight + 8
                Component.onCompleted: bar.root.calendarAnchorItem = clockItem

                Text {
                    id: clockOneLine
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -1
                    text: bar.root.hh + ":" + bar.root.mm
                    visible: !bar.root.osdActive
                    color: clockMouse.containsMouse ? bar.root.seal : bar.root.ink
                    font.family: bar.root.mono
                    font.pixelSize: 12
                    font.letterSpacing: 2
                    font.weight: Font.Light
                    Behavior on color { ColorAnimation { duration: 180 } }
                }

                // OSD progress bar — replaces the clock briefly
                Rectangle {
                    id: osdBar
                    visible: bar.root.osdActive
                    anchors.centerIn: parent
                    width: 250; height: 4; radius: 2
                    color: Qt.rgba(bar.root.seal.r, bar.root.seal.g, bar.root.seal.b, 0.15)
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width * (bar.root.osdPct / 100)
                        radius: parent.radius
                        color: bar.root.seal
                        Behavior on width { NumberAnimation { duration: 120 } }
                    }
                }

                Timer {
                    id: clockTipDelay
                    interval: 320
                    onTriggered: {
                        const p = clockItem.mapToItem(null, clockItem.width / 2, clockItem.height / 2);
                        bar.root.showTooltip("Calendar", p.x, p.y);
                    }
                }

                MouseArea {
                    id: clockMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onEntered: { clockBloom.fire(mouseX, mouseY); clockTipDelay.restart(); }
                    onExited:  { clockTipDelay.stop(); bar.root.hideTooltip("Calendar"); }
                    onClicked: (e) => {
                        clockTipDelay.stop();
                        bar.root.hideTooltip("Calendar");
                        if (e.button === Qt.RightButton) {
                            bar.root.run("rencal");
                        } else if (bar.root.calendarVisible) {
                            bar.root.calendarVisible = false;
                        } else {
                            bar.root.openCalendar();
                        }
                    }
                }
            }

            // Voxtype indicator button — to the right of the clock
            Item {
                id: voxtypeIndicator
                anchors.left: clockItem.right
                anchors.leftMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                width: visible ? 16 : 0
                height: bar.root.barHeight
                visible: bar.root.isHorizontal && bar.root.voxtypeStatus !== "idle"

                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -1
                    text: bar.root.voxtypeStatus === "recording" ? "󰍬" : "󰔟"
                    color: voxtypeMouse.containsMouse ? bar.root.seal : bar.root.ink
                    font.family: bar.root.mono
                    font.pixelSize: 9
                    Behavior on color { ColorAnimation { duration: 180 } }
                }
                Rectangle {
                    anchors.fill: parent; anchors.margins: 2; radius: 2
                    color: voxtypeMouse.containsMouse ? Qt.rgba(bar.root.seal.r, bar.root.seal.g, bar.root.seal.b, 0.12) : "transparent"
                    Behavior on color { ColorAnimation { duration: 180 } }
                }
                MouseArea {
                    id: voxtypeMouse
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (e) => {
                        if (e.button === Qt.RightButton) bar.root.run("omarchy-voxtype-config");
                        else bar.root.run("omarchy-voxtype-model");
                    }
                }
            }

            // Screen recording indicator — to the right of voxtype
            Item {
                id: scrIndicator
                anchors.left: voxtypeIndicator.right
                anchors.leftMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                width: visible ? 16 : 0
                height: bar.root.barHeight
                visible: bar.root.isHorizontal && bar.root.screenRecording

                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -1
                    text: "󰻂"
                    color: scrMouse.containsMouse ? bar.root.seal : bar.root.ink
                    font.family: bar.root.mono
                    font.pixelSize: 9
                    Behavior on color { ColorAnimation { duration: 180 } }
                }
                Rectangle {
                    anchors.fill: parent; anchors.margins: 2; radius: 2
                    color: scrMouse.containsMouse ? Qt.rgba(bar.root.seal.r, bar.root.seal.g, bar.root.seal.b, 0.12) : "transparent"
                    Behavior on color { ColorAnimation { duration: 180 } }
                }
                MouseArea {
                    id: scrMouse
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { bar.root.run("omarchy-capture-screenrecording"); bar.root.refreshScreenRecording(); }
                }
            }

            // Idle disabled indicator — to the right of screen recording
            Item {
                id: idleIndicator
                anchors.left: scrIndicator.right
                anchors.leftMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                width: visible ? 16 : 0
                height: bar.root.barHeight
                visible: bar.root.isHorizontal && bar.root.idleDisabled

                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -1
                    text: "󱫖"
                    color: idleMouse.containsMouse ? bar.root.seal : bar.root.ink
                    font.family: bar.root.mono
                    font.pixelSize: 9
                    Behavior on color { ColorAnimation { duration: 180 } }
                }
                Rectangle {
                    anchors.fill: parent; anchors.margins: 2; radius: 2
                    color: idleMouse.containsMouse ? Qt.rgba(bar.root.seal.r, bar.root.seal.g, bar.root.seal.b, 0.12) : "transparent"
                    Behavior on color { ColorAnimation { duration: 180 } }
                }
                MouseArea {
                    id: idleMouse
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { bar.root.run("omarchy-toggle-idle"); bar.root.refreshIdleIndicator(); }
                }
            }

            // Notification silencing indicator — to the right of idle disabled
            Item {
                id: notifIndicator
                anchors.left: idleIndicator.right
                anchors.leftMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                width: visible ? 16 : 0
                height: bar.root.barHeight
                visible: bar.root.isHorizontal && bar.root.notificationSilencing

                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -1
                    text: "󰂛"
                    color: notifMouse.containsMouse ? bar.root.seal : bar.root.ink
                    font.family: bar.root.mono
                    font.pixelSize: 9
                    Behavior on color { ColorAnimation { duration: 180 } }
                }
                Rectangle {
                    anchors.fill: parent; anchors.margins: 2; radius: 2
                    color: notifMouse.containsMouse ? Qt.rgba(bar.root.seal.r, bar.root.seal.g, bar.root.seal.b, 0.12) : "transparent"
                    Behavior on color { ColorAnimation { duration: 180 } }
                }
                MouseArea {
                    id: notifMouse
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { bar.root.run("omarchy-toggle-notification-silencing"); bar.root.refreshNotificationSilencing(); }
                }
            }

            // Vertical: stacked HH and MM (no indicators in vertical mode)
            Text {
                id: clockHH
                visible: !bar.root.isHorizontal
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.verticalCenter
                anchors.bottomMargin: 1
                text: bar.root.hh
                color: bar.root.ink
                font.family: bar.root.mono
                font.pixelSize: 11
                font.weight: Font.Light
            }
            Text {
                id: clockMM
                visible: !bar.root.isHorizontal
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.verticalCenter
                anchors.topMargin: 1
                text: bar.root.mm
                color: bar.root.ink
                font.family: bar.root.mono
                font.pixelSize: 11
                font.weight: Font.Light
            }
        }

        // Now-playing pill, anchored to the bar's right edge so it sits
        // outside (to the right of) the system-icons cluster. The
        // GridLayout reserves room for it via an enlarged rightMargin when
        // visible so the icons stop short and don't overlap. Sits above
        // the GridLayout (same z trick the clockItem uses).
        Item {
            id: musicItem
            // `present` is the logical "show the pill" state; the item lingers
            // a beat past it (openW > 0.5) so the closing slide can finish
            // before it leaves the layout.
            readonly property bool present: bar.root.isHorizontal && bar.root.musicTitle.length > 0
            // Natural pill width (icon + label + 12px padding). The +8 folds
            // in the gap to the icon cluster so the reservation below tracks a
            // single animated number — no 8px snap when the pill maps/unmaps.
            readonly property real contentW: musicRow.width + 12
            property real openW: present ? contentW : 0
            // One Behavior drives all three motions: slide open on track
            // start, ease between widths on a title change, slide shut on
            // stop. 220ms OutCubic — a short, settled glide.
            Behavior on openW { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            visible: present || openW > 0.5
            anchors.right: parent.right
            anchors.rightMargin: 0
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: openW
            z: 10

            readonly property string tipText: bar.root.musicArtist.length > 0
                                              ? bar.root.musicTitle + " - " + bar.root.musicArtist
                                              : bar.root.musicTitle

            Rectangle {
                id: musicPill
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width
                radius: 0
                color: bar.root.accent
                clip: true
                opacity: musicMouse.containsMouse ? 1.0 : 0.9
                Behavior on opacity { NumberAnimation { duration: 180 } }

                Row {
                    id: musicRow
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        id: musicIcon
                        anchors.verticalCenter: parent.verticalCenter
                        text: bar.root.icoMusic
                        color: bar.root.paper
                        font.family: bar.root.mono
                        font.pixelSize: 9
                    }

                    Text {
                        id: musicLabel
                        anchors.verticalCenter: parent.verticalCenter
                        // Hard cap on the text portion; outer Item width
                        // tracks this + 12px of pill padding. The font is
                        // monospace, so we truncate to the exact character
                        // count that fits 140px and append ".." rather than
                        // letting a half-glyph bleed under the fade.
                        readonly property int maxChars:
                            Math.max(2, Math.floor(140 / chMetric.advanceWidth))
                        readonly property bool truncated:
                            bar.root.musicTitle.length > maxChars
                        text: truncated
                              ? bar.root.musicTitle.slice(0, maxChars - 2) + ".."
                              : bar.root.musicTitle
                        color: bar.root.paper
                        font.family: bar.root.mono
                        font.pixelSize: 10
                        font.weight: Font.Medium

                        // One monospace cell, used to convert the 140px cap
                        // into a character count.
                        TextMetrics {
                            id: chMetric
                            font: musicLabel.font
                            text: "0"
                        }
                    }
                }

                // Right-edge fade: only when the title is actually clipped.
                // A horizontal transparent->accent gradient layered over the
                // text tail dissolves it into the pill. Sits inside the pill
                // so it inherits the hover opacity, and Qt.rgba(...,0) fades
                // alpha only (no dark tint mid-gradient). Runs flush to the
                // pill's right edge; matching radius keeps the rounded corner
                // clean (the left corners round under the transparent stop).
                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height
                    width: 40
                    radius: parent.radius
                    visible: musicLabel.truncated
                    // Front-loaded ramp: alpha climbs fast, then the right
                    // ~40% sits fully on accent, so the tail reads as solidly
                    // dissolved rather than a gentle wash.
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Qt.rgba(bar.root.accent.r, bar.root.accent.g, bar.root.accent.b, 0) }
                        GradientStop { position: 0.6; color: bar.root.accent }
                        GradientStop { position: 1.0; color: bar.root.accent }
                    }
                }
            }

            Timer {
                id: musicTipDelay
                interval: 320
                onTriggered: {
                    const p = musicItem.mapToItem(null, musicItem.width / 2, musicItem.height / 2);
                    bar.root.showTooltip(musicItem.tipText, p.x, p.y);
                }
            }

            MouseArea {
                id: musicMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                onEntered: musicTipDelay.restart()
                onExited:  { musicTipDelay.stop(); bar.root.hideTooltip(musicItem.tipText); }
                onClicked: (e) => {
                    musicTipDelay.stop();
                    bar.root.hideTooltip(musicItem.tipText);
                    if (e.button === Qt.RightButton)       bar.root.musicNext();
                    else if (e.button === Qt.MiddleButton) bar.root.musicPrev();
                    else                                    bar.root.musicToggle();
                }
            }
        }

        GridLayout {
            anchors.fill: parent
            anchors.leftMargin:   bar.root.isHorizontal ? (bar.cloudMode ? bar.cloudAir + bar.cloudPad : 10) : 0
            anchors.rightMargin:  bar.root.isHorizontal
                                  ? ((bar.cloudMode ? bar.cloudAir + bar.cloudPad : 10)
                                     + musicItem.openW)
                                  : 0
            anchors.topMargin:    bar.root.isHorizontal
                                  ? (bar.cloudMode
                                     ? (bar.root.barEdge === "top" ? bar.cloudAir + bar.cloudPad : bar.cloudInnerAir + bar.cloudPad)
                                     : 0)
                                  : 10
            anchors.bottomMargin: bar.root.isHorizontal
                                  ? (bar.cloudMode
                                     ? (bar.root.barEdge === "top" ? bar.cloudInnerAir + bar.cloudPad : bar.cloudAir + bar.cloudPad)
                                     : 0)
                                  : 10
            flow: bar.root.isHorizontal ? GridLayout.LeftToRight : GridLayout.TopToBottom
            rowSpacing: 4
            columnSpacing: 4
            columns: bar.root.isHorizontal ? -1 : 1
            rows:    bar.root.isHorizontal ? 1  : -1

            Module {
                root: bar.root
                glyph: bar.root.icoOmarchy
                tooltip: "Menu"
                color: bar.root.seal
                fontFamily: "omarchy"
                fontSize: 14
                onActivated: bar.root.paletteToggleRequested()
                onRightActivated: bar.root.run("xdg-terminal-exec")
            }

            Separator { root: bar.root }

            Repeater {
                model: 5
                delegate: Workspace {
                    required property int index
                    root: bar.root
                    wsId: index + 1
                    label: bar.root.indexKanji(index + 1)
                    active: bar.root.activeWs === (index + 1)
                    present: bar.root.existingWs.indexOf(index + 1) !== -1
                    onActivated: { console.log("[WS-ACT fired] ws=" + (index + 1) + " runType=" + (typeof (bar.root && bar.root.run))); bar.root.run("hyprctl dispatch workspace " + (index + 1)); }
                }
            }

            Item {
                Layout.fillWidth:  bar.root.isHorizontal
                Layout.fillHeight: !bar.root.isHorizontal
            }

            // Running-app tray icons sit to the left of the weather
            // separator so they bridge workspace labels and the
            // pop-up / status cluster.
            SystemTray { root: bar.root }

            Separator { root: bar.root }

            // Pop-up / overlay openers sit on the inside of the right
            // cluster — weather, display tweaks, screenshots browser.
            Module {
                id: weatherMod
                root: bar.root
                Component.onCompleted: bar.root.weatherAnchorItem = weatherMod
                // Muted middle dot stands in until the first wttr fetch
                // lands; a "?" marks an unreachable network.
                glyph: bar.root.weatherUnavailable ? "?"
                       : (bar.root.weatherLoaded ? bar.root.weatherIcon : "·")
                tooltip: bar.root.weatherUnavailable
                         ? "Weather offline"
                         : (bar.root.weatherLoaded
                            ? bar.root.weatherTempC + "°C"
                            : "Weather…")
                color: bar.root.weatherUnavailable ? bar.root.inkDeep : bar.root.ink
                fontSize: 13
                onActivated: {
                    if (bar.root.weatherVisible) bar.root.weatherVisible = false;
                    else bar.root.openWeather();
                }
                onRightActivated: bar.root.refreshWeather()
            }

            // Aether / Display / Screenshots / Videos moved into the
            // OmniMenu Quick panel (Alt+Space). The bar keeps only the
            // always-glanced status indicators on the right.

            Separator { root: bar.root }

            // System indicators read right-to-left as
            //   battery · sound · wifi · bluetooth · cpu · [edge]
            // so the most-glanced item (battery) sits adjacent to the
            // bar-position chevron.
            Module {
                root: bar.root
                glyph: bar.root.kbdLayout
                tooltip: "Click to switch layout"
                fontSize: 9
                glyphYOffset: 0
                onActivated: bar.root.cycleKbdLayout()
            }

            Module {
                root: bar.root
                glyph: "󰍛"
                tooltip: "CPU " + Math.round(bar.root.cpuVal) + "%  MEM " + Math.round(bar.root.memVal) + "%"
                color: bar.root.powerProfile === "power-saver" ? bar.root.green
                       : bar.root.powerProfile === "performance" ? bar.root.accent
                       : (bar.root.cpuVal > 80 ? bar.root.seal : bar.root.ink)
                onActivated: bar.root.run("omarchy-launch-or-focus-tui btop")
            }

            Module {
                id: btMod
                root: bar.root
                glyph: bar.root.btIcon
                tooltip: bar.root.btTooltip
                color: bar.root.btPowered ? bar.root.accent : bar.root.ink
                onActivated: bar.root.openBluetooth()
            }

            Module {
                id: netMod
                root: bar.root
                glyph: bar.root.netIcon
                color: bar.root.netKind === "wifi" ? bar.root.accent : bar.root.ink
                tooltip: {
                    if (bar.root.netKind === "eth") return "Ethernet";
                    if (bar.root.netKind === "wifi") {
                        const name = bar.root.wifiSsid || "(hidden)";
                        return "Wi-Fi · " + name + " · " + bar.root.wifiSignal + "%";
                    }
                    return "Offline";
                }
                onActivated: bar.root.openWifi()

                // Network-burst dot: traverses the wifi glyph's outermost
                // arc once when a heavy rx+tx burst is detected.
                // Geometry is eyeballed for the Nerd Font wifi icon
                // rendered at fontSize 12 inside the 24x26 Module slot.
                Item {
                    id: arc
                    anchors.fill: parent
                    property real t: 0
                    property real op: 0
                    readonly property real cx: width / 2
                    readonly property real cy: 17
                    readonly property real r:  6

                    Rectangle {
                        width: 3
                        height: 3
                        radius: 1.5
                        color: Qt.lighter(bar.root.seal, 1.7)
                        antialiasing: true
                        opacity: arc.op
                        x: arc.cx - arc.r * Math.cos(Math.PI * arc.t) - width / 2
                        y: arc.cy - arc.r * Math.sin(Math.PI * arc.t) - height / 2
                    }

                    ParallelAnimation {
                        id: arcAnim
                        NumberAnimation {
                            target: arc; property: "t"
                            from: 0; to: 1
                            duration: 700
                            easing.type: Easing.InOutQuad
                        }
                        SequentialAnimation {
                            NumberAnimation { target: arc; property: "op"; from: 0; to: 1; duration: 120; easing.type: Easing.OutQuad }
                            PauseAnimation { duration: 380 }
                            NumberAnimation { target: arc; property: "op"; to: 0; duration: 200; easing.type: Easing.InCubic }
                        }
                    }

                    // connected via Navbar.qml Loader onLoaded → root.netBurst.connect(item.handleNetBurst)
                }
            }

            Module {
                id: audioMod
                root: bar.root
                glyph: bar.root.audioIcon
                color: bar.root.audioVol >= 100 ? bar.root.accent : bar.root.ink
                tooltip: bar.root.audioMuted
                         ? "Audio muted · " + bar.root.audioVol + "%"
                         : "Audio " + bar.root.audioVol + "%"
                onActivated: bar.root.openAudio()
                onRightActivated: bar.root.run("pamixer -t")
                onWheelActivated: (delta, mx, my) => {
                    bar.root.setVolume(bar.root.audioVol + (delta > 0 ? 2 : -2));
                    const tip = bar.root.audioMuted
                        ? "Audio muted · " + bar.root.audioVol + "%"
                        : "Audio " + bar.root.audioVol + "%";
                    const p = mapToItem(null, mx, my);
                    bar.root.showTooltip(tip, p.x, p.y);
                }
            }

            // Surfaces only when omarchy-update-available exits 0. Sits
            // beside the battery so it shares the system-status cluster's
            // line of sight without disturbing the existing icon cadence.
            Module {
                root: bar.root
                visible: bar.root.omarchyUpdateAvailable
                glyph: bar.root.icoUpdate
                tooltip: bar.root.omarchyLatestTag
                         ? "Omarchy update available · " + bar.root.omarchyLatestTag
                         : "Omarchy update available"
                color: bar.root.seal
                fontSize: 10
                onActivated: bar.root.openOmarchyUpdate()
            }

            Module {
                id: batteryMod
                root: bar.root
                glyph: bar.root.batteryIcon()
                // Hide power below 0.05 W: idle Full / Not charging
                // states often report a sub-noise trickle that just
                // adds chatter to the tooltip.
                tooltip: {
                    let s = "Battery " + bar.root.batVal + "%";
                    if (bar.root.batPower >= 0.05) {
                        const sign = bar.root.batState === "Charging"    ? "+"
                                   : bar.root.batState === "Discharging" ? "-"
                                   : "";
                        s += "  " + sign + bar.root.batPower.toFixed(1) + " W";
                    }
                    return s;
                }
                color: (bar.root.batState === "Charging" || bar.root.batState === "Full" || bar.root.batState === "Not charging")
                       ? bar.root.accent
                       : (bar.root.batVal <= 10 ? bar.root.seal : bar.root.batVal <= 20 ? bar.root.indigo : bar.root.ink)
                onActivated: bar.root.openPowerProfile()
            }

            // Auto-hide toggle: pin=always visible, unpin=slides away when idle.
            Module {
                root: bar.root
                glyph: "󰐃"
                tooltip: bar.root.barAutoHide
                         ? "Auto-hide on · Click to pin bar"
                         : "Auto-hide off · Click to hide bar when idle"
                color: bar.root.barAutoHide ? bar.root.seal : bar.root.ink
                onActivated: bar.root.toggleBarAutoHide()
            }

            // Module {
            //     root: bar.root
            //     glyph: bar.root.edgeArrow()
            //     tooltip: "Move bar"
            //     onActivated: bar.root.cycleBarEdge()
            // }
        }
    }
    }
}
