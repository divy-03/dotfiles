import QtQuick

// Animated reveal shared by both popups: fades, slides down and scales up from
// the pill, and leaves again the same way. `shown` drives it; `active` stays
// true until the exit animation has finished so the window can be hidden then.
Item {
    id: root
    property bool shown: false
    readonly property bool active: shown || card.opacity > 0.01
    property alias contentItem: card
    default property alias content: card.data
    property int padding: 12
    property int radius: 14
    property color fill: Colors.crust
    property color edge: Colors.surface1

    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    Rectangle {
        id: card
        width: root.width
        height: root.height
        radius: root.radius
        color: root.fill
        border.color: root.edge
        border.width: 1
        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.92
        transformOrigin: Item.Top
        transform: Translate { y: root.shown ? 0 : -10; Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } } }
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
    }
}
