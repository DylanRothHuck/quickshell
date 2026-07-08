import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

Item {
    id: trayRoot
    required property var root

    Layout.alignment: root.isHorizontal ? Qt.AlignVCenter : Qt.AlignHCenter
    Layout.leftMargin: 2
    implicitWidth: trayRow.width + Layout.leftMargin + Layout.rightMargin
    Layout.preferredHeight: root.isHorizontal ? root.barHeight : -1

    Row {
        id: trayRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        leftPadding: 2
        rightPadding: 2

        Repeater {
            model: SystemTray.items

            delegate: Item {
                id: delegateItem
                required property SystemTrayItem modelData

                width: 20
                height: root.barHeight

                readonly property string tipText: {
                    const t = modelData.tooltipTitle || modelData.title || "";
                    const d = modelData.tooltipDescription || "";
                    return d ? t + " - " + d : t;
                }

                Timer {
                    id: tipDelay
                    interval: 320
                    onTriggered: {
                        if (!tipText) return;
                        const p = item.mapToItem(null, item.width / 2, item.height / 2);
                        root.showTooltip(tipText, p.x, p.y);
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 3
                    radius: root.cornerRadius
                    color: mouseArea.containsMouse ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08) : "transparent"
                    Behavior on color { ColorAnimation { duration: 180 } }
                }

                IconImage {
                    id: iconImage
                    anchors.centerIn: parent
                    implicitSize: 14
                    source: modelData.icon
                }

                QsMenuOpener {
                    id: menuOpener
                    menu: modelData.menu
                }

                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    cursorShape: Qt.PointingHandCursor
                    onEntered: {
                        if (tipText) tipDelay.restart();
                    }
                    onExited: {
                        tipDelay.stop();
                        root.hideTooltip(tipText);
                    }
                    onClicked: {
                        tipDelay.stop();
                        root.hideTooltip(tipText);
                        modelData.activate();
                    }
                }

                MouseArea {
                    id: rcArea
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton
                    onClicked: {
                        tipDelay.stop();
                        root.hideTooltip(tipText);
                        if (!modelData.hasMenu) {
                            modelData.secondaryActivate();
                            return;
                        }
                        const g = delegateItem.mapToGlobal(0, 0);
                        menuWindow.x = g.x;
                        menuWindow.y = g.y + delegateItem.height;
                        menuWindow.currentOpener = menuOpener;
                        menuWindow.visible = true;
                    }
                }
            }
        }
    }

    Window {
        id: menuWindow
        flags: Qt.Popup
        visible: false
        width: 200
        height: Math.min(menuColumn.height + 12, 400)
        transientParent: trayRoot.Window.window

        property QsMenuOpener currentOpener: null

        onVisibleChanged: {
            if (visible) {
                requestActivate();
            } else {
                currentOpener = null;
            }
        }

        Rectangle {
            id: menuBg
            anchors.fill: parent
            color: root.bg
            border.color: root.sep
            border.width: 1
            radius: root.cornerRadius

            Column {
                id: menuColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 4
                spacing: 0

                Repeater {
                    id: menuRepeater
                    model: menuWindow.currentOpener ? menuWindow.currentOpener.children : null

                    delegate: Item {
                        id: menuItem
                        required property var modelData

                        readonly property bool isSep: modelData.isSeparator || false
                        readonly property bool isEnabled: modelData.enabled !== false
                        readonly property string label: modelData.text || ""

                        height: isSep ? 12 : 28
                        width: menuBg.width - 8

                        Rectangle {
                            anchors.fill: parent
                            radius: root.cornerRadius - 1
                            color: {
                                if (isSep) return "transparent";
                                if (itemMouse.containsMouse && isEnabled)
                                    return Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08);
                                return "transparent";
                            }
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            height: 1
                            color: root.sep
                            visible: isSep
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: label.toUpperCase()
                            color: isEnabled ? root.ink : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.4)
                            font.pixelSize: 10
                            font.family: root.mono
                            font.letterSpacing: 2
                            font.weight: Font.Medium
                            visible: !isSep
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            enabled: isEnabled && !isSep
                            hoverEnabled: true
                            onClicked: {
                                try {
                                    modelData.triggered();
                                } catch(e) {}
                                menuWindow.visible = false;
                            }
                        }
                    }
                }
            }
        }
    }
}
