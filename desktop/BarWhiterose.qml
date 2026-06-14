import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// Plain White Rose bar face. It reuses the main bar's actions and state,
// but renders them as editorial rows: rectangular cells, icons, and borders
// for emphasis while still following the live omarchy theme palette.
PanelWindow {
    id: wr

    required property var root

    readonly property color bg: root.bg
    readonly property color text: root.ink
    readonly property color muted: root.inkDeep
    readonly property color faint: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.45)
    readonly property color line: root.sep
    readonly property color lineStrong: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.52)
    readonly property color surface: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)
    readonly property color musicAccent: root.green

    readonly property string faviconSource:
        "file://" + Quickshell.env("HOME") + "/Code/whiterose/site/assets/favicon-16.png"
    readonly property string icoCpu: String.fromCodePoint(0xf035b)

    function trunc(s, n) {
        if (!s) return "";
        return s.length > n ? s.slice(0, n - 2) + ".." : s;
    }

    function batteryTip() {
        let s = "Battery " + wr.root.batVal + "%";
        if (wr.root.batPower >= 0.05) {
            const sign = wr.root.batState === "Charging" ? "+"
                       : wr.root.batState === "Discharging" ? "-" : "";
            s += "  " + sign + wr.root.batPower.toFixed(1) + " W";
        }
        return s;
    }

    function claimAnchors() {
        wr.root.calendarAnchorItem = wr.root.isHorizontal ? clockItem : clockItemV;
        wr.root.weatherAnchorItem  = wr.root.isHorizontal ? weatherMod : weatherModV;
        wr.root.systemAnchorItem   = wr.root.isHorizontal ? systemMod : systemModV;
    }

    color: "transparent"
    anchors {
        top:    wr.root.barEdge !== "bottom"
        bottom: wr.root.barEdge !== "top"
        left:   wr.root.barEdge !== "right"
        right:  wr.root.barEdge !== "left"
    }
    implicitHeight: wr.root.isHorizontal ? wr.root.barHeight : 0
    implicitWidth:  wr.root.isHorizontal ? 0 : wr.root.barHeight
    exclusiveZone:  wr.root.barHeight

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "omarchy-menu"

    onVisibleChanged: if (visible) wr.claimAnchors()
    Connections {
        target: wr.root
        function onBarEdgeChanged() { if (wr.visible) wr.claimAnchors(); }
    }

    Rectangle {
        id: backplate
        anchors.fill: parent
        color: wr.bg
        opacity: 1.0
        states: State {
            name: "idle"
            when: wr.root.isIdle
            PropertyChanges { target: backplate; opacity: 0.72 }
        }
        transitions: [
            Transition { to: "idle";   NumberAnimation { property: "opacity"; duration: 6000; easing.type: Easing.OutQuart } },
            Transition { from: "idle"; NumberAnimation { property: "opacity"; duration: 6000; easing.type: Easing.OutQuad } }
        ]

        Rectangle {
            visible: wr.root.isHorizontal
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top:    wr.root.barEdge === "bottom" ? parent.top    : undefined
            anchors.bottom: wr.root.barEdge === "top"    ? parent.bottom : undefined
            height: 1
            color: wr.line
        }
        Rectangle {
            visible: !wr.root.isHorizontal
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: wr.root.barEdge === "left"  ? parent.right : undefined
            anchors.left:  wr.root.barEdge === "right" ? parent.left  : undefined
            width: 1
            color: wr.line
        }
    }

    Item {
        visible: wr.root.isHorizontal
        anchors.fill: parent

        Item {
            id: clockItem
            anchors.centerIn: parent
            width: clockText.implicitWidth + 18
            height: parent.height
            z: 10

            Rectangle {
                anchors.fill: parent
                anchors.margins: 3
                color: clockMouse.containsMouse ? wr.surface : "transparent"
                border.width: clockMouse.containsMouse ? 1 : 0
                border.color: wr.lineStrong
            }
            Text {
                id: clockText
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -1
                text: wr.root.hh + ":" + wr.root.mm
                color: wr.text
                font.family: wr.root.mono
                font.pixelSize: 12
                font.letterSpacing: 2
                font.weight: Font.Medium
            }
            Timer {
                id: clockTipDelay
                interval: 320
                onTriggered: {
                    const p = clockItem.mapToItem(null, clockItem.width / 2, clockItem.height / 2);
                    wr.root.showTooltip("Calendar", p.x, p.y);
                }
            }
            MouseArea {
                id: clockMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: clockTipDelay.restart()
                onExited: { clockTipDelay.stop(); wr.root.hideTooltip("Calendar"); }
                onClicked: {
                    clockTipDelay.stop();
                    wr.root.hideTooltip("Calendar");
                    if (wr.root.calendarVisible) wr.root.calendarVisible = false;
                    else wr.root.openCalendar();
                }
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 4

            WhiteRoseCell {
                root: wr.root
                imageSource: wr.faviconSource
                tooltip: "Menu"
                minWidth: 28
                maxWidth: 28
                iconSize: 14
                onActivated: wr.root.paletteToggleRequested()
                onRightActivated: wr.root.run("xdg-terminal-exec")
            }

            Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 14; Layout.alignment: Qt.AlignVCenter; color: wr.line }

            Repeater {
                model: 10
                delegate: WhiteRoseCell {
                    required property int index
                    root: wr.root
                    readonly property int wsId: index + 1
                    text: String(wsId).padStart(2, "0")
                    active: wr.root.activeWs === wsId
                    present: wr.root.existingWs.indexOf(wsId) !== -1
                    minWidth: 26
                    fontSize: 10
                    onActivated: wr.root.run("hyprctl dispatch workspace " + wsId)
                }
            }

            Item { Layout.fillWidth: true }

            WhiteRoseCell {
                root: wr.root
                visible: wr.root.musicTitle.length > 0
                glyph: wr.root.musicPlaying ? wr.root.icoMusic : wr.root.icoPause
                text: wr.trunc(wr.root.musicTitle, 18)
                tooltip: wr.root.musicArtist.length > 0
                         ? wr.root.musicTitle + " - " + wr.root.musicArtist
                         : wr.root.musicTitle
                strong: true
                accentColor: wr.musicAccent
                minWidth: 96
                maxWidth: 190
                onActivated: wr.root.musicToggle()
                onRightActivated: wr.root.musicNext()
            }

            Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 14; Layout.alignment: Qt.AlignVCenter; color: wr.line }

            WhiteRoseCell {
                id: weatherMod
                root: wr.root
                glyph: wr.root.weatherUnavailable ? "?"
                       : (wr.root.weatherLoaded ? wr.root.weatherIcon : ".")
                text: wr.root.weatherLoaded ? Math.round(wr.root.weatherTempC) + "C" : "--"
                tooltip: wr.root.weatherUnavailable
                         ? "Weather offline"
                         : (wr.root.weatherLoaded
                            ? wr.root.weatherDesc + " - " + Math.round(wr.root.weatherTempC) + "C"
                            : "Weather...")
                minWidth: 50
                maxWidth: 90
                ink: wr.root.weatherUnavailable ? wr.muted : wr.text
                onActivated: {
                    if (wr.root.weatherVisible) wr.root.weatherVisible = false;
                    else wr.root.openWeather();
                }
                onRightActivated: wr.root.refreshWeather()
            }

            Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 14; Layout.alignment: Qt.AlignVCenter; color: wr.line }

            WhiteRoseCell {
                id: systemMod
                root: wr.root
                glyph: wr.icoCpu
                text: Math.round(wr.root.cpuVal) + "/" + Math.round(wr.root.memVal)
                tooltip: "System - CPU " + Math.round(wr.root.cpuVal) + "% / MEM " + Math.round(wr.root.memVal) + "%"
                strong: wr.root.cpuVal > 80 || wr.root.memVal > 85
                minWidth: 62
                onActivated: {
                    if (wr.root.systemVisible) wr.root.systemVisible = false;
                    else wr.root.openSystem();
                }
                onRightActivated: wr.root.run("omarchy-launch-or-focus-tui btop")
            }
            WhiteRoseCell {
                root: wr.root
                glyph: wr.root.btIcon
                text: wr.root.btPowered ? (wr.root.btCount > 0 ? String(wr.root.btCount) : "ON") : "OFF"
                tooltip: {
                    if (!wr.root.btPowered) return "Bluetooth off";
                    return wr.root.btCount > 0
                        ? "Bluetooth - " + wr.root.btCount + " connected"
                        : "Bluetooth on";
                }
                ink: wr.root.btPowered ? wr.text : wr.muted
                minWidth: 46
                onActivated: wr.root.run("omarchy-launch-bluetooth")
            }
            WhiteRoseCell {
                root: wr.root
                glyph: wr.root.netIcon
                text: {
                    if (wr.root.netKind === "eth") return "ETH";
                    if (wr.root.netKind === "wifi") return String(wr.root.wifiSignal);
                    return "OFF";
                }
                tooltip: {
                    if (wr.root.netKind === "eth") return "Ethernet";
                    if (wr.root.netKind === "wifi") {
                        const name = wr.root.wifiSsid || "(hidden)";
                        return "Wi-Fi - " + name + " - " + wr.root.wifiSignal + "%";
                    }
                    return "Offline";
                }
                ink: wr.root.netKind === "none" ? wr.muted : wr.text
                minWidth: 50
                onActivated: wr.root.run("omarchy-launch-wifi")
            }
            WhiteRoseCell {
                root: wr.root
                glyph: wr.root.audioIcon
                text: wr.root.audioMuted ? "MUTE" : String(wr.root.audioVol)
                tooltip: wr.root.audioMuted
                         ? "Audio muted - " + wr.root.audioVol + "%"
                         : "Audio " + wr.root.audioVol + "%"
                strong: wr.root.audioMuted
                minWidth: 58
                onActivated: wr.root.run("omarchy-launch-audio")
                onRightActivated: wr.root.run("pamixer -t")
            }
            WhiteRoseCell {
                root: wr.root
                visible: wr.root.omarchyUpdateAvailable
                glyph: wr.root.icoUpdate
                text: "UPD"
                tooltip: wr.root.omarchyLatestTag
                         ? "Omarchy update available - " + wr.root.omarchyLatestTag
                         : "Omarchy update available"
                strong: true
                minWidth: 34
                onActivated: wr.root.openOmarchyUpdate()
            }
            WhiteRoseCell {
                root: wr.root
                glyph: wr.root.batteryIcon()
                text: wr.root.batVal + "%"
                tooltip: wr.batteryTip()
                strong: wr.root.batVal <= 10
                minWidth: 56
                onActivated: wr.root.run("omarchy-menu power")
            }
            WhiteRoseCell {
                root: wr.root
                text: wr.root.edgeArrow()
                tooltip: "Move bar"
                minWidth: 28
                onActivated: wr.root.cycleBarEdge()
            }
        }
    }

    ColumnLayout {
        visible: !wr.root.isHorizontal
        anchors.fill: parent
        anchors.topMargin: 6
        anchors.bottomMargin: 6
        spacing: 3

        WhiteRoseCell {
            root: wr.root
            imageSource: wr.faviconSource
            tooltip: "Menu"
            minWidth: 20
            maxWidth: 20
            iconSize: 13
            onActivated: wr.root.paletteToggleRequested()
            onRightActivated: wr.root.run("xdg-terminal-exec")
        }

        Rectangle { Layout.preferredWidth: 14; Layout.preferredHeight: 1; Layout.alignment: Qt.AlignHCenter; color: wr.line }

        Repeater {
            model: 10
            delegate: WhiteRoseCell {
                required property int index
                root: wr.root
                readonly property int wsId: index + 1
                text: String(wsId).padStart(2, "0")
                active: wr.root.activeWs === wsId
                present: wr.root.existingWs.indexOf(wsId) !== -1
                minWidth: 20
                fontSize: 9
                onActivated: wr.root.run("hyprctl dispatch workspace " + wsId)
            }
        }

        Item { Layout.fillHeight: true }

        Item {
            id: clockItemV
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: wr.root.barHeight
            Layout.preferredHeight: 30

            Rectangle {
                anchors.fill: parent
                anchors.margins: 3
                color: clockMouseV.containsMouse ? wr.surface : "transparent"
                border.width: clockMouseV.containsMouse ? 1 : 0
                border.color: wr.lineStrong
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.verticalCenter
                anchors.bottomMargin: 1
                text: wr.root.hh
                color: wr.text
                font.family: wr.root.mono
                font.pixelSize: 9
                font.weight: Font.Medium
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.verticalCenter
                anchors.topMargin: 1
                text: wr.root.mm
                color: wr.text
                font.family: wr.root.mono
                font.pixelSize: 9
                font.weight: Font.Medium
            }
            MouseArea {
                id: clockMouseV
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (wr.root.calendarVisible) wr.root.calendarVisible = false;
                    else wr.root.openCalendar();
                }
            }
        }

        Rectangle { Layout.preferredWidth: 14; Layout.preferredHeight: 1; Layout.alignment: Qt.AlignHCenter; color: wr.line }

        WhiteRoseCell {
            id: systemModV
            root: wr.root
            glyph: wr.icoCpu
            text: "SY"
            tooltip: "System - CPU " + Math.round(wr.root.cpuVal) + "% / MEM " + Math.round(wr.root.memVal) + "%"
            strong: wr.root.cpuVal > 80 || wr.root.memVal > 85
            minWidth: 20
            fontSize: 9
            onActivated: {
                if (wr.root.systemVisible) wr.root.systemVisible = false;
                else wr.root.openSystem();
            }
            onRightActivated: wr.root.run("omarchy-launch-or-focus-tui btop")
        }
        WhiteRoseCell {
            root: wr.root
            glyph: wr.root.netIcon
            text: wr.root.netKind === "none" ? "NO" : "NW"
            tooltip: {
                if (wr.root.netKind === "eth") return "Ethernet";
                if (wr.root.netKind === "wifi") return "Wi-Fi - " + (wr.root.wifiSsid || "(hidden)") + " - " + wr.root.wifiSignal + "%";
                return "Offline";
            }
            ink: wr.root.netKind === "none" ? wr.muted : wr.text
            minWidth: 20
            fontSize: 9
            onActivated: wr.root.run("omarchy-launch-wifi")
        }
        WhiteRoseCell {
            root: wr.root
            glyph: wr.root.audioIcon
            text: wr.root.audioMuted ? "MU" : "AU"
            tooltip: wr.root.audioMuted
                     ? "Audio muted - " + wr.root.audioVol + "%"
                     : "Audio " + wr.root.audioVol + "%"
            strong: wr.root.audioMuted
            minWidth: 20
            fontSize: 9
            onActivated: wr.root.run("omarchy-launch-audio")
            onRightActivated: wr.root.run("pamixer -t")
        }
        WhiteRoseCell {
            id: weatherModV
            root: wr.root
            glyph: wr.root.weatherUnavailable ? "?"
                   : (wr.root.weatherLoaded ? wr.root.weatherIcon : ".")
            text: wr.root.weatherUnavailable ? "?" : "WX"
            tooltip: wr.root.weatherUnavailable
                     ? "Weather offline"
                     : (wr.root.weatherLoaded
                        ? wr.root.weatherDesc + " - " + Math.round(wr.root.weatherTempC) + "C"
                        : "Weather...")
            ink: wr.root.weatherUnavailable ? wr.muted : wr.text
            minWidth: 20
            fontSize: 9
            onActivated: {
                if (wr.root.weatherVisible) wr.root.weatherVisible = false;
                else wr.root.openWeather();
            }
            onRightActivated: wr.root.refreshWeather()
        }
        WhiteRoseCell {
            root: wr.root
            glyph: wr.root.batteryIcon()
            text: String(wr.root.batVal)
            tooltip: wr.batteryTip()
            strong: wr.root.batVal <= 10
            minWidth: 20
            fontSize: 9
            onActivated: wr.root.run("omarchy-menu power")
        }

        Rectangle { Layout.preferredWidth: 14; Layout.preferredHeight: 1; Layout.alignment: Qt.AlignHCenter; color: wr.line }

        WhiteRoseCell {
            root: wr.root
            text: wr.root.edgeArrow()
            tooltip: "Move bar"
            minWidth: 20
            fontSize: 11
            onActivated: wr.root.cycleBarEdge()
        }
    }
}
