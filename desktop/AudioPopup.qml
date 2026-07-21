import QtQuick

CardWindow {
    id: audioPopup
    property var root: ({})

    theme: root
    revealed: root.audioVisible
    cardWidth: 380
    layerNamespace: "omarchy-audio"
    title: "AUDIO"

    subtitle: {
        if (!root.audioSinks || root.audioSinks.length === 0) return "\u2014";
        const def = root.audioSinks.find(s => s.isDefault);
        if (def) return def.name;
        const first = root.audioSinks[0];
        return first ? first.name : "\u2014";
    }

    headerRight: Row {
        spacing: 8
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.audioMuted
                  ? "\uF0EE" + "  " + root.audioVol + "%"
                  : root.audioVol + "%"
            color: root.audioVol >= 100 ? root.accent : root.ink
            font.family: root.mono
            font.pixelSize: 10
            font.letterSpacing: 1.5
        }
        QuickButton {
            root: audioPopup.root
            glyph: "\u21BA"
            label: ""
            padH: 8
            onClicked: root.resetAudio()
        }
        QuickButton {
            root: audioPopup.root
            glyph: "\u2699"
            label: ""
            padH: 8
            onClicked: { root.run("omarchy-launch-audio"); root.audioVisible = false; }
        }
        QuickButton {
            root: audioPopup.root
            glyph: "\u23F7"
            label: ""
            padH: 8
            onClicked: { root.run("easyeffects"); root.audioVisible = false; }
        }
    }

    anchorEdge: root.barEdge
    anchorBarX: root.popupAnchorX
    anchorBarY: root.popupAnchorY

    onDismiss: root.audioVisible = false
    onKeyPressed: function(event) {
        const k = event.key;
        if (k === Qt.Key_Q) {
            root.audioVisible = false;
            event.accepted = true;
            return;
        }
        if (k === Qt.Key_Left && audioPopup.activeTab > 0) {
            audioPopup.activeTab--;
            event.accepted = true;
            return;
        }
        if (k === Qt.Key_Right && audioPopup.activeTab < 2) {
            audioPopup.activeTab++;
            event.accepted = true;
            return;
        }
        if (audioPopup._tabFns && audioPopup._tabFns[audioPopup.activeTab]) {
            if (audioPopup._tabFns[audioPopup.activeTab](k)) {
                event.accepted = true;
                return;
            }
        }
    }

    onRevealedChanged: {
        if (revealed) {
            audioPopup.activeTab = 0;
            root.refreshAudioSinks();
            root.refreshAudioSources();
            root.refreshPlaybackStreams();
        }
    }

    property int activeTab: 0
    property var _tabFns: [null, null, null]
    readonly property var _tabs: [
        { label: "PLAYBACK" },
        { label: "DEVICES" },
        { label: "RECORDING" }
    ]

    footer: "\u2190\u2192 TAB  \u00b7  \u2191\u2193 CYCLE  \u00b7  \u23CE SET  \u00b7  ESC CLOSE"

    Column {
        width: parent.width
        spacing: 10

        // Tab bar
        Rectangle {
            width: parent.width
            height: 1
            color: root.sep
        }

        Row {
            width: parent.width
            spacing: 0

            Repeater {
                model: audioPopup._tabs
                delegate: Item {
                    required property var modelData
                    required property int index
                    width: parent.width / audioPopup._tabs.length
                    height: 32

                    Rectangle {
                        anchors.fill: parent
                        color: mouseArea.containsMouse
                               ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.04)
                               : "transparent"
                    }
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 2
                        color: audioPopup.activeTab === index ? root.seal : "transparent"
                        Behavior on color { ColorAnimation { duration: 140 } }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        color: audioPopup.activeTab === index ? root.seal : root.inkDeep
                        font.family: root.mono
                        font.pixelSize: 10
                        font.letterSpacing: 2
                        font.weight: audioPopup.activeTab === index ? Font.Medium : Font.Normal
                    }
                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: audioPopup.activeTab = index
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: root.sep
        }

        // --- Tab 0: Playback ---
        Item {
            visible: audioPopup.activeTab === 0
            width: parent.width
            height: playbackCol.implicitHeight

            Column {
                id: playbackCol
                width: parent.width
                spacing: 12

                Item {
                    width: parent.width
                    height: 32

                    QuickButton {
                        id: muteBtn
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        root: audioPopup.root
                        glyph: root.audioMuted ? root.icoMute : root.audioIcon
                        label: root.audioMuted ? "UNMUTE" : "MUTE"
                        onClicked: root.toggleMute()
                    }
                    QuickSlider {
                        anchors.left: muteBtn.right
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 12
                        root: audioPopup.root
                        value: root.audioVol
                        min: 0; max: 150
                        onCommitted: (v) => root.setVolume(v)
                        label: root.audioMuted ? "MUTED" : root.audioVol + "%"
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: root.sep
                }

                Text {
                    text: "PROFILES"
                    color: root.inkDeep
                    font.family: root.mono
                    font.pixelSize: 10
                    font.letterSpacing: 2
                }

                Row {
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: [
                            { key: "speakers",   label: "SPEAKERS" },
                            { key: "headphones",  label: "HEADPHONES" },
                            { key: "bass-boost",  label: "BASS BOOST" },
                            { key: "flat",        label: "FLAT" }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            width: (parent.width - 18) / 4
                            height: 28
                            radius: root.cornerRadius
                            color: profileMouse.containsMouse
                                   ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.20)
                                   : "transparent"
                            border.color: profileMouse.containsMouse ? root.seal : "transparent"
                            border.width: profileMouse.containsMouse ? 1.5 : 0
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                color: profileMouse.containsMouse ? root.seal : root.ink
                                font.family: root.mono
                                font.pixelSize: 9
                                font.letterSpacing: 1
                            }
                            MouseArea {
                                id: profileMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setAudioProfile(modelData.key)
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: root.sep
                }

                Text {
                    text: "ACTIVE STREAMS"
                    color: root.inkDeep
                    font.family: root.mono
                    font.pixelSize: 10
                    font.letterSpacing: 2
                }

                Column {
                    width: parent.width
                    spacing: 4

                    Repeater {
                        model: root.playbackStreams || []

                        delegate: Item {
                            required property var modelData
                            required property int index

                            readonly property bool isFocused: audioPopup._playKbd === index

                            // Local mutable state — decoupled from the async
                            // probe so the slider tracks drags smoothly.
                            property real _vol: modelData.vol
                            property bool _mute: modelData.mute
                            function _syncModel() {
                                _vol = modelData.vol;
                                _mute = modelData.mute;
                            }
                            onModelDataChanged: _syncModel()

                            width: parent.width
                            height: 40

                            Rectangle {
                                anchors.fill: parent
                                radius: root.cornerRadius
                                color: isFocused
                                       ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.20)
                                       : (streamMouse.containsMouse
                                          ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)
                                          : "transparent")
                                border.color: isFocused ? root.seal : "transparent"
                                border.width: isFocused ? 1.5 : 0
                                Behavior on color { ColorAnimation { duration: 120 } }
                                Behavior on border.color { ColorAnimation { duration: 120 } }

                                Text {
                                    id: streamIcon
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: _mute ? root.icoMute : "\u266B"
                                    color: _mute ? root.seal : root.ink
                                    font.family: root.mono
                                    font.pixelSize: 12
                                }
                                Text {
                                    id: streamName
                                    anchors.left: streamIcon.right
                                    anchors.leftMargin: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 100
                                    text: modelData.name
                                    elide: Text.ElideRight
                                    color: _mute ? root.inkDeep : root.fg
                                    font.family: root.mono
                                    font.pixelSize: 11
                                }
                                QuickSlider {
                                    id: streamSlider
                                    anchors.left: streamName.right
                                    anchors.leftMargin: 8
                                    anchors.right: parent.right
                                    anchors.rightMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    root: audioPopup.root
                                    value: _vol
                                    min: 0; max: 100
                                    onCommitted: (v) => {
                                        _vol = Math.round(v);
                                        root.setStreamVolume(modelData.id, _vol);
                                    }
                                    label: _mute ? "MUTE" : Math.round(_vol) + "%"
                                }
                                MouseArea {
                                    id: streamMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.RightButton
                                    onClicked: {
                                        _mute = !_mute;
                                        root.toggleStreamMute(modelData.id);
                                    }
                                    onWheel: (wheel) => {
                                        audioPopup._playKbd = index;
                                        const delta = wheel.angleDelta.y > 0 ? 5 : -5;
                                        _vol = Math.max(0, Math.min(100, _vol + delta));
                                        root.setStreamVolume(modelData.id, _vol);
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: !root.playbackStreams || root.playbackStreams.length === 0
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: "NO ACTIVE STREAMS"
                    color: root.inkDeep
                    font.family: root.mono
                    font.pixelSize: 10
                    font.letterSpacing: 2
                    opacity: 0.6
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: root.sep
                }

                Item {
                    width: parent.width
                    height: 22
                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "OUTPUT"
                        color: root.inkDeep
                        font.family: root.mono
                        font.pixelSize: 10
                        font.letterSpacing: 2
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            if (!root.audioSinks || root.audioSinks.length === 0) return "\u2014";
                            const def = root.audioSinks.find(s => s.isDefault);
                            return def ? def.name : root.audioSinks[0].name;
                        }
                        elide: Text.ElideRight
                        color: root.inkDeep
                        font.family: root.mono
                        font.pixelSize: 10
                        font.letterSpacing: 1
                        opacity: 0.7
                    }
                }

                Component.onCompleted: {
                    audioPopup._tabFns[0] = function(k) {
                        const n = root.playbackStreams ? root.playbackStreams.length : 0;
                        if (n === 0) return false;
                        if (k === Qt.Key_Up) {
                            audioPopup._playKbd = (audioPopup._playKbd - 1 + n) % n;
                            return true;
                        }
                        if (k === Qt.Key_Down || k === Qt.Key_Tab) {
                            audioPopup._playKbd = (audioPopup._playKbd + 1) % n;
                            return true;
                        }
                        if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) {
                            const s = root.playbackStreams[audioPopup._playKbd];
                            if (s) root.toggleStreamMute(s.id);
                            return true;
                        }
                        return false;
                    };
                }
            }
        }

        // --- Tab 1: Devices ---
        Item {
            visible: audioPopup.activeTab === 1
            width: parent.width
            height: devCol.implicitHeight

            Column {
                id: devCol
                width: parent.width
                spacing: 6

                Text {
                    text: "OUTPUT DEVICES"
                    color: root.inkDeep
                    font.family: root.mono
                    font.pixelSize: 10
                    font.letterSpacing: 2
                }

                Column {
                    width: parent.width
                    spacing: 4

                    Repeater {
                        model: root.audioSinks || []
                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            readonly property bool isDefault: modelData.isDefault === true || modelData.isDefault === "1" || modelData.isDefault === 1
                            readonly property bool isFocused: audioPopup._devKbd === index

                            width: parent.width
                            height: 36
                            radius: root.cornerRadius
                            color: isDefault || isFocused
                                   ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.20)
                                   : (devMouse.containsMouse
                                      ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)
                                      : "transparent")
                            border.color: isDefault || isFocused ? root.seal : "transparent"
                            border.width: isDefault || isFocused ? 1.5 : 0
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: isDefault ? "\u2713" : " "
                                color: root.seal
                                font.family: root.mono
                                font.pixelSize: 11
                                font.weight: Font.Medium
                            }
                            Text {
                                anchors.left: parent.left
                                anchors.right: isDefault ? dot.left : parent.right
                                anchors.leftMargin: 30
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.name
                                elide: Text.ElideRight
                                color: isDefault ? root.ink : root.fg
                                font.family: root.mono
                                font.pixelSize: 11
                                font.weight: isDefault ? Font.Medium : Font.Normal
                            }
                            Text {
                                id: dot
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: "\u25CF"
                                color: root.seal
                                font.pixelSize: 8
                                visible: isDefault
                            }
                            MouseArea {
                                id: devMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    audioPopup._devKbd = index;
                                    root.setDefaultSink(modelData.id);
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: root.audioSinks.length === 0
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: "NO OUTPUT DEVICES"
                    color: root.inkDeep
                    font.family: root.mono
                    font.pixelSize: 10
                    font.letterSpacing: 2
                    opacity: 0.6
                }

                Component.onCompleted: {
                    audioPopup._tabFns[1] = function(k) {
                        const n = root.audioSinks.length;
                        if (n === 0) return false;
                        if (k === Qt.Key_Up) {
                            audioPopup._devKbd = (audioPopup._devKbd - 1 + n) % n;
                            return true;
                        }
                        if (k === Qt.Key_Down || k === Qt.Key_Tab) {
                            audioPopup._devKbd = (audioPopup._devKbd + 1) % n;
                            return true;
                        }
                        if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) {
                            const s = root.audioSinks[audioPopup._devKbd];
                            if (s) root.setDefaultSink(s.id);
                            return true;
                        }
                        return false;
                    };
                }
            }
        }

        // --- Tab 2: Recording ---
        Item {
            visible: audioPopup.activeTab === 2
            width: parent.width
            height: recCol.implicitHeight

            Column {
                id: recCol
                width: parent.width
                spacing: 6

                Text {
                    text: "INPUT DEVICES"
                    color: root.inkDeep
                    font.family: root.mono
                    font.pixelSize: 10
                    font.letterSpacing: 2
                }

                Column {
                    width: parent.width
                    spacing: 4

                    Repeater {
                        model: root.audioSources || []
                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            readonly property bool isDefault: modelData.isDefault === true || modelData.isDefault === "1" || modelData.isDefault === 1
                            readonly property bool isFocused: audioPopup._recKbd === index

                            width: parent.width
                            height: 36
                            radius: root.cornerRadius
                            color: isDefault || isFocused
                                   ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.20)
                                   : (srcMouse.containsMouse
                                      ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)
                                      : "transparent")
                            border.color: isDefault || isFocused ? root.seal : "transparent"
                            border.width: isDefault || isFocused ? 1.5 : 0
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: isDefault ? "\u2713" : " "
                                color: root.seal
                                font.family: root.mono
                                font.pixelSize: 11
                                font.weight: Font.Medium
                            }
                            Text {
                                anchors.left: parent.left
                                anchors.right: isDefault ? dot.left : parent.right
                                anchors.leftMargin: 30
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.name
                                elide: Text.ElideRight
                                color: isDefault ? root.ink : root.fg
                                font.family: root.mono
                                font.pixelSize: 11
                                font.weight: isDefault ? Font.Medium : Font.Normal
                            }
                            Text {
                                id: dot
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: "\u25CF"
                                color: root.seal
                                font.pixelSize: 8
                                visible: isDefault
                            }
                            MouseArea {
                                id: srcMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    audioPopup._recKbd = index;
                                    if (root.setDefaultSource) root.setDefaultSource(modelData.id);
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: !root.audioSources || root.audioSources.length === 0
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: "NO INPUT DEVICES"
                    color: root.inkDeep
                    font.family: root.mono
                    font.pixelSize: 10
                    font.letterSpacing: 2
                    opacity: 0.6
                }

                Component.onCompleted: {
                    audioPopup._tabFns[2] = function(k) {
                        const n = root.audioSources ? root.audioSources.length : 0;
                        if (n === 0) return false;
                        if (k === Qt.Key_Up) {
                            audioPopup._recKbd = (audioPopup._recKbd - 1 + n) % n;
                            return true;
                        }
                        if (k === Qt.Key_Down || k === Qt.Key_Tab) {
                            audioPopup._recKbd = (audioPopup._recKbd + 1) % n;
                            return true;
                        }
                        if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) {
                            const s = root.audioSources[audioPopup._recKbd];
                            if (s && root.setDefaultSource) root.setDefaultSource(s.id);
                            return true;
                        }
                        return false;
                    };
                }
            }
        }
    }

    property int _playKbd: 0
    property int _devKbd: 0
    property int _recKbd: 0
}
