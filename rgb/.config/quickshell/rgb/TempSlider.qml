import QtQuick

// White balance: warm (2000 K) to cool (10000 K), like WLED's temperature bar.
Item {
    id: s
    property real value: 0.3    // 0 warm .. 1 cool
    // released is false while dragging, true on release
    signal picked(color color, bool released)

    implicitHeight: 20

    // Tanner Helland's blackbody approximation
    function colorAt(r) {
        var t = (2000 + r * 8000) / 100
        function clamp(v) { return Math.max(0, Math.min(255, v)) / 255 }
        var red = t <= 66 ? 255 : 329.698727446 * Math.pow(t - 60, -0.1332047592)
        var green = t <= 66 ? 99.4708025861 * Math.log(t) - 161.1195681661
                            : 288.1221695283 * Math.pow(t - 60, -0.0755148492)
        var blue = t >= 66 ? 255 : t <= 19 ? 0 : 138.5177312231 * Math.log(t - 10) - 305.0447927307
        return Qt.rgba(clamp(red), clamp(green), clamp(blue), 1)
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        radius: 3
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: s.colorAt(0.0) }
            GradientStop { position: 0.2; color: s.colorAt(0.2) }
            GradientStop { position: 0.4; color: s.colorAt(0.4) }
            GradientStop { position: 0.6; color: s.colorAt(0.6) }
            GradientStop { position: 0.8; color: s.colorAt(0.8) }
            GradientStop { position: 1.0; color: s.colorAt(1.0) }
        }
    }

    Rectangle {
        width: 16
        height: 16
        radius: 8
        color: Colors.text
        anchors.verticalCenter: parent.verticalCenter
        x: s.value * (s.width - width)
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        function pick(mx, released) {
            s.value = Math.max(0, Math.min(1, (mx - 8) / (s.width - 16)))
            s.picked(s.colorAt(s.value), released)
        }
        onPressed: mouse => pick(mouse.x, false)
        onPositionChanged: mouse => { if (pressed) pick(mouse.x, false) }
        onReleased: mouse => pick(mouse.x, true)
    }
}
