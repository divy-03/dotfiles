import QtQuick

Item {
    id: s
    property real from: 0
    property real to: 100
    property real value: 0
    property real step: 0
    property color fill: Colors.accent
    // released is false while dragging, true on release
    signal moved(real value, bool released)

    implicitHeight: 20

    readonly property real ratio: to > from ? Math.max(0, Math.min(1, (value - from) / (to - from))) : 0

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        radius: 3
        color: Colors.surface1

        Rectangle {
            width: s.ratio * parent.width
            height: parent.height
            radius: 3
            color: s.fill
        }
    }

    Rectangle {
        width: 16
        height: 16
        radius: 8
        color: Colors.text
        anchors.verticalCenter: parent.verticalCenter
        x: s.ratio * (s.width - width)
    }

    function pick(mx, released) {
        var r = Math.max(0, Math.min(1, (mx - 8) / (s.width - 16)))
        var v = s.from + r * (s.to - s.from)
        if (s.step > 0)
            v = Math.round(v / s.step) * s.step
        s.value = v
        s.moved(v, released)
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => s.pick(mouse.x, false)
        onPositionChanged: mouse => { if (pressed) s.pick(mouse.x, false) }
        onReleased: mouse => s.pick(mouse.x, true)
    }
}
