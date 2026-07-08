import QtQuick
import QtQuick.Layouts

Item {
    id: wsCell
    required property var root

    property int wsId: 0
    property string label: ""
    property bool active: false
    property bool present: false
    signal activated()

    Layout.alignment: root.isHorizontal ? Qt.AlignVCenter : Qt.AlignHCenter
    Layout.preferredWidth:  root.isHorizontal ? 20 : root.barHeight
    Layout.preferredHeight: root.isHorizontal ? root.barHeight : 20

    Bloom { id: bloom; root: wsCell.root }

    Text {
        id: kanji
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        // -1 lift matches Module.qml so kanji optically align with icons.
        anchors.verticalCenterOffset: -1
        text: wsCell.label
        color: wsCell.active ? wsCell.root.seal : (wsCell.present ? wsCell.root.ink : wsCell.root.inkDeep)
        opacity: wsCell.active ? 1.0 : (wsCell.present ? 0.75 : 0.35)
        font.family: wsCell.root.serif
        font.pixelSize: wsCell.active ? 14 : 12
        font.weight: Font.Light
    }

    MouseArea {
        // Reach 2px into the 4px grid gap on every side so there are no dead
        // strips between adjacent numbers — each kanji owns the space up to
        // the midpoint between it and its neighbour, making clicks forgiving.
        anchors.fill: parent
        anchors.margins: -2
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: { console.log("[WS-DIAG hover] ws=" + wsCell.wsId); bloom.fire(mouseX, mouseY); }
        onClicked: { console.log("[WS-DIAG click] ws=" + wsCell.wsId); wsCell.activated(); }
    }
}
