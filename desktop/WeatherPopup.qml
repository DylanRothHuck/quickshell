import QtQuick
import Quickshell
import Quickshell.Wayland

// Card width matches the display popup so the visual cadence stays
// uniform when cycling through the bar's overlays.
PanelWindow {
    id: weatherPopup
    required property var root

    visible: root.weatherVisible || reveal > 0.001
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-weather"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property real reveal: root.weatherVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: weatherPopup.root.weatherVisible ? 220 : 140
            easing.type: weatherPopup.root.weatherVisible ? Easing.OutCubic : Easing.InCubic
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: weatherPopup.root.weatherVisible = false
    }

    Rectangle {
        id: weatherCard
        anchors.centerIn: parent
        width: 360
        height: weatherCol.implicitHeight + 34
        color: weatherPopup.root.bg
        border.color: weatherPopup.root.sep
        border.width: 1
        radius: 0

        transformOrigin: Item.Center
        scale: weatherPopup.reveal

        focus: weatherPopup.root.weatherVisible
        Keys.onPressed: function(event) {
            const k = event.key;
            if (k === Qt.Key_Escape || k === Qt.Key_Q) {
                weatherPopup.root.weatherVisible = false;
            } else if (k === Qt.Key_R) {
                weatherPopup.root.refreshWeather();
            } else {
                return;
            }
            event.accepted = true;
        }

        MouseArea { anchors.fill: parent }

        Column {
            id: weatherCol
            anchors.fill: parent
            anchors.margins: 17
            spacing: 12

            Item {
                width: parent.width
                height: 43

                Column {
                    anchors.left: parent.left
                    anchors.right: weatherRefresh.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text {
                        text: "WEATHER"
                        color: weatherPopup.root.ink
                        font.family: weatherPopup.root.mono
                        font.pixelSize: 19
                        font.letterSpacing: 4
                        font.weight: Font.Medium
                    }
                    // Subtitle pulls double duty as the "edit location"
                    // affordance — hover paints it seal so the click
                    // target reads, click opens the location file.
                    Text {
                        id: weatherSubtitle
                        width: parent.width
                        elide: Text.ElideRight
                        text: {
                            const r = weatherPopup.root;
                            const src = r.weatherLocation === "" ? "AUTO" : "MANUAL";
                            if (r.weatherUnavailable) return src + "  ·  UNAVAILABLE";
                            if (!r.weatherLoaded) return src + "  ·  FETCHING…";
                            return r.weatherPlace.toUpperCase()
                                   + "  ·  " + src
                                   + "  ·  " + r.weatherUpdatedAt;
                        }
                        color: subMouse.containsMouse ? weatherPopup.root.seal : weatherPopup.root.sumi
                        font.family: weatherPopup.root.mono
                        font.pixelSize: 11
                        font.letterSpacing: 2
                        Behavior on color { ColorAnimation { duration: 140 } }

                        MouseArea {
                            id: subMouse
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: weatherPopup.root.editWeatherLocation()
                        }
                    }
                }

                CalendarChevron {
                    id: weatherRefresh
                    root: weatherPopup.root
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: weatherPopup.root.icoRefresh
                    restColor: weatherPopup.root.sumi
                    font.pixelSize: 22
                    onTriggered: weatherPopup.root.refreshWeather()
                }
            }

            Rectangle { width: parent.width; height: 1; color: weatherPopup.root.sep }

            // Collapses to a muted single-line placeholder when the
            // network drops so the card doesn't pretend to know anything
            // it doesn't.
            Item {
                width: parent.width
                height: 86
                visible: weatherPopup.root.weatherLoaded

                Text {
                    id: heroGlyph
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: weatherPopup.root.weatherIcon
                    color: weatherPopup.root.seal
                    font.family: weatherPopup.root.mono
                    font.pixelSize: 56
                }

                Column {
                    anchors.left: heroGlyph.right
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                        text: weatherPopup.root.fmtTemp(weatherPopup.root.weatherTempC) + "C"
                        color: weatherPopup.root.ink
                        font.family: weatherPopup.root.mono
                        font.pixelSize: 38
                        font.weight: Font.Light
                        font.letterSpacing: 2
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                        // Multi-line descriptions like "Light drizzle,
                        // mist" wrap to two rows rather than eliding the
                        // second clause out of existence.
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        text: weatherPopup.root.weatherDesc.toUpperCase()
                        color: weatherPopup.root.inkDeep
                        font.family: weatherPopup.root.mono
                        font.pixelSize: 11
                        font.letterSpacing: 3
                    }
                }
            }

            // Placeholder so the card never reads empty before the first
            // fetch lands.
            Text {
                width: parent.width
                height: 86
                visible: !weatherPopup.root.weatherLoaded
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: weatherPopup.root.weatherUnavailable ? "WTTR.IN UNREACHABLE" : "FETCHING…"
                color: weatherPopup.root.sumi
                font.family: weatherPopup.root.mono
                font.pixelSize: 11
                font.letterSpacing: 3
                opacity: 0.6
            }

            // Two rows of two so each label/value pair stays readable
            // without squashing the wind direction into the humidity.
            Grid {
                width: parent.width
                columns: 2
                rowSpacing: 4
                columnSpacing: 0
                visible: weatherPopup.root.weatherLoaded

                Repeater {
                    model: [
                        { label: "FEELS",    value: weatherPopup.root.fmtTemp(weatherPopup.root.weatherFeelsC) + "C" },
                        { label: "WIND",     value: weatherPopup.root.weatherWindKmh + " KM/H " + weatherPopup.root.weatherWindDir },
                        { label: "HUMIDITY", value: weatherPopup.root.weatherHumidity + "%" },
                        { label: "UV INDEX", value: String(weatherPopup.root.weatherUv) }
                    ]
                    delegate: Item {
                        required property var modelData
                        width: weatherCol.width / 2
                        height: 20
                        Text {
                            id: metricLabel
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            color: weatherPopup.root.sumi
                            font.family: weatherPopup.root.mono
                            font.pixelSize: 10
                            font.letterSpacing: 2
                        }
                        Text {
                            anchors.left: metricLabel.right
                            anchors.leftMargin: 8
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignRight
                            elide: Text.ElideRight
                            text: modelData.value
                            color: weatherPopup.root.ink
                            font.family: weatherPopup.root.mono
                            font.pixelSize: 11
                            font.letterSpacing: 1
                            font.weight: Font.Medium
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width; height: 1; color: weatherPopup.root.sep
                visible: weatherPopup.root.weatherLoaded
            }

            // Today: hi/lo + sun arc. Sunrise/sunset come from wttr's
            // astronomy block so they reflect the queried location, not
            // the laptop's timezone — handy when travelling.
            Item {
                width: parent.width
                height: 36
                visible: weatherPopup.root.weatherLoaded

                Column {
                    anchors.left: parent.left
                    anchors.right: todayHiLo.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    Text {
                        text: "TODAY"
                        color: weatherPopup.root.sumi
                        font.family: weatherPopup.root.mono
                        font.pixelSize: 10
                        font.letterSpacing: 2
                    }
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: String.fromCodePoint(0xe34c) + " " + weatherPopup.root.weatherSunrise
                              + "   " + String.fromCodePoint(0xe34d) + " " + weatherPopup.root.weatherSunset
                        color: weatherPopup.root.inkDeep
                        font.family: weatherPopup.root.mono
                        font.pixelSize: 10
                        font.letterSpacing: 1
                    }
                }

                Row {
                    id: todayHiLo
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    Text {
                        text: "↑ " + weatherPopup.root.fmtTemp(weatherPopup.root.weatherHighC)
                        color: weatherPopup.root.seal
                        font.family: weatherPopup.root.mono
                        font.pixelSize: 13
                        font.letterSpacing: 1
                        font.weight: Font.Medium
                    }
                    Text {
                        text: "↓ " + weatherPopup.root.fmtTemp(weatherPopup.root.weatherLowC)
                        color: weatherPopup.root.indigo
                        font.family: weatherPopup.root.mono
                        font.pixelSize: 13
                        font.letterSpacing: 1
                        font.weight: Font.Medium
                    }
                }
            }

            Rectangle {
                width: parent.width; height: 1; color: weatherPopup.root.sep
                visible: weatherPopup.root.weatherLoaded && weatherPopup.root.weatherForecast.length > 0
            }

            Text {
                visible: weatherPopup.root.weatherLoaded && weatherPopup.root.weatherForecast.length > 0
                text: "FORECAST"
                color: weatherPopup.root.sumi
                font.family: weatherPopup.root.mono
                font.pixelSize: 10
                font.letterSpacing: 2
            }

            Repeater {
                model: weatherPopup.root.weatherForecast
                delegate: Item {
                    required property var modelData
                    width: weatherCol.width
                    height: 26

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.day
                        color: weatherPopup.root.ink
                        font.family: weatherPopup.root.mono
                        font.pixelSize: 11
                        font.letterSpacing: 3
                        font.weight: Font.Medium
                    }
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 60
                        anchors.verticalCenter: parent.verticalCenter
                        text: weatherPopup.root.weatherGlyph(modelData.code, false)
                        color: weatherPopup.root.inkDeep
                        font.family: weatherPopup.root.mono
                        font.pixelSize: 18
                    }
                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        Text {
                            text: "↑ " + weatherPopup.root.fmtTemp(modelData.high)
                            color: weatherPopup.root.seal
                            font.family: weatherPopup.root.mono
                            font.pixelSize: 12
                            font.letterSpacing: 1
                        }
                        Text {
                            text: "↓ " + weatherPopup.root.fmtTemp(modelData.low)
                            color: weatherPopup.root.indigo
                            font.family: weatherPopup.root.mono
                            font.pixelSize: 12
                            font.letterSpacing: 1
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: weatherPopup.root.sep; opacity: 0.5 }

            Text {
                width: parent.width
                text: "WTTR.IN · CLICK SUBTITLE TO EDIT LOCATION · R REFRESH · ESC"
                color: weatherPopup.root.sumi
                font.family: weatherPopup.root.mono
                font.pixelSize: 9
                font.letterSpacing: 1
                opacity: 0.55
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }
    }
}
