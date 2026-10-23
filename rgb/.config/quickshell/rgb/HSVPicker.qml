import QtQuick

Item {
    id: p
    property real hue: 0
    property real sat: 1
    property real val: 1
    property bool dragging: false
    readonly property color color: Qt.hsva(hue, sat, val, 1)
    // released is false while dragging, true on release
    signal picked(bool released)

    implicitHeight: sv.height + 10 + bar.height

    function setColor(c) {
        if (c.hsvHue >= 0)
            hue = c.hsvHue
        sat = c.hsvSaturation
        val = c.hsvValue
    }

    Rectangle {
        id: sv
        width: parent.width
        height: 120
        radius: 8
        color: Qt.hsva(p.hue, 1, 1, 1)

        Rectangle {
            anchors.fill: parent
            radius: 8
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 1) }
                GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0) }
            }
        }
        Rectangle {
            anchors.fill: parent
            radius: 8
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0) }
                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 1) }
            }
        }
        Rectangle {
            width: 14
            height: 14
            radius: 7
            color: p.color
            border.width: 2
            border.color: "white"
            x: p.sat * sv.width - 7
            y: (1 - p.val) * sv.height - 7
        }
        MouseArea {
            anchors.fill: parent
            function pick(m, released) {
                p.sat = Math.max(0, Math.min(1, m.x / width))
                p.val = 1 - Math.max(0, Math.min(1, m.y / height))
                p.picked(released)
            }
            onPressed: mouse => { p.dragging = true; pick(mouse, false) }
            onPositionChanged: mouse => { if (pressed) pick(mouse, false) }
            onReleased: mouse => { p.dragging = false; pick(mouse, true) }
        }
    }

    Rectangle {
        id: bar
        anchors.top: sv.bottom
        anchors.topMargin: 10
        width: parent.width
        height: 14
        radius: 7
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.000; color: Qt.hsva(0.000, 1, 1, 1) }
            GradientStop { position: 0.167; color: Qt.hsva(0.167, 1, 1, 1) }
            GradientStop { position: 0.333; color: Qt.hsva(0.333, 1, 1, 1) }
            GradientStop { position: 0.500; color: Qt.hsva(0.500, 1, 1, 1) }
            GradientStop { position: 0.667; color: Qt.hsva(0.667, 1, 1, 1) }
            GradientStop { position: 0.833; color: Qt.hsva(0.833, 1, 1, 1) }
            GradientStop { position: 1.000; color: Qt.hsva(1.000, 1, 1, 1) }
        }
        Rectangle {
            width: 6
            height: 18
            radius: 3
            anchors.verticalCenter: parent.verticalCenter
            color: Qt.hsva(p.hue, 1, 1, 1)
            border.width: 2
            border.color: "white"
            x: p.hue * (bar.width - width)
        }
        MouseArea {
            anchors.fill: parent
            function pick(m, released) {
                p.hue = Math.max(0, Math.min(1, (m.x - 3) / (width - 6)))
                p.picked(released)
            }
            onPressed: mouse => { p.dragging = true; pick(mouse, false) }
            onPositionChanged: mouse => { if (pressed) pick(mouse, false) }
            onReleased: mouse => { p.dragging = false; pick(mouse, true) }
        }
    }
}
