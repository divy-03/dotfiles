import QtQuick

Rectangle {
    id: c
    property string label
    property bool active: false
    signal clicked

    implicitWidth: text.implicitWidth + 24
    implicitHeight: 28
    radius: 8
    color: active ? Colors.accent : mouse.containsMouse ? Colors.surface1 : Colors.surface0
    Behavior on color { ColorAnimation { duration: 100 } }

    Text {
        id: text
        anchors.centerIn: parent
        text: c.label
        color: c.active ? Colors.textOnAccent : Colors.text
        font.pixelSize: 12
        font.family: "JetBrainsMono Nerd Font"
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: c.clicked()
    }
}
