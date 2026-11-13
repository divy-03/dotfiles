import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// CPU + RAM pill (right of the clock). Hover for the top processes.
PanelWindow {
    id: win
    required property var shell

    readonly property int pillW: 150
    readonly property int popW: 250
    readonly property var st: shell.stats
    property bool hovered: false

    function fmtMem(b) {
        var g = b / 1073741824
        return g >= 1 ? g.toFixed(1) + " GB" : Math.round(b / 1048576) + " MB"
    }

    anchors { top: true; right: true }
    margins.right: shell.rightReserve
    implicitWidth: Math.max(pillW, popW)
    implicitHeight: shell.pillTop + shell.pillH + 8 + pop.implicitHeight + 10
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "bar-sys"
    visible: shell.visibleBar

    mask: Region { item: hit }

    // Hover lives on the window's content item, an ancestor of both the pill and
    // the popup. On the sibling `hit` item it lost hover whenever a hoverEnabled
    // button above it took the pointer, which closed and reopened the popup.
    HoverHandler {
        onHoveredChanged: {
            if (hovered) { closeTimer.stop(); win.hovered = true }
            else closeTimer.restart()
        }
    }
    Timer { id: closeTimer; interval: 250; onTriggered: win.hovered = false }

    Item {
        id: hit
        y: 0
        width: pop.active ? win.popW : win.pillW
        x: win.width - width
        height: shell.pillTop + shell.pillH + (pop.active ? 8 + pop.height + 10 : 0)
    }

    Rectangle {
        x: win.width - win.pillW; y: shell.pillTop
        width: win.pillW; height: shell.pillH
        radius: 8
        color: Colors.crust
        Row {
            anchors.centerIn: parent
            spacing: 14
            Row {
                spacing: 6
                Text { text: "󰻠"; color: Colors.accent; font.family: shell.font; font.pixelSize: 15; anchors.verticalCenter: parent.verticalCenter }
                Text { text: Math.round(win.st.cpu) + "%"; color: Colors.accent; font.family: shell.font; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
            }
            Row {
                spacing: 6
                Text { text: "󰍛"; color: Colors.green; font.family: shell.font; font.pixelSize: 15; anchors.verticalCenter: parent.verticalCenter }
                Text { text: Math.round(win.st.memUsed / win.st.memTotal * 100) + "%"; color: Colors.green; font.family: shell.font; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }

    Popup {
        id: pop
        shown: win.hovered
        x: win.width - win.popW
        y: shell.pillTop + shell.pillH + 8
        width: win.popW
        implicitHeight: col.implicitHeight + 28
        height: implicitHeight
        visible: active

        Column {
            id: col
            x: 14; y: 14
            width: pop.width - 28
            spacing: 14

            Repeater {
                model: [
                    { title: "CPU", icon: "󰻠", col: Colors.accent, key: "cpu" },
                    { title: "Memory", icon: "󰍛", col: Colors.green, key: "mem" }
                ]
                delegate: Column {
                    id: sec
                    required property var modelData
                    readonly property bool isCpu: modelData.key === "cpu"
                    readonly property var rows: isCpu ? win.st.topCpu : win.st.topMem
                    width: col.width
                    spacing: 5

                    RowLayout {
                        width: parent.width
                        Text { text: sec.modelData.icon + "  " + sec.modelData.title; color: sec.modelData.col; font.family: shell.font; font.pixelSize: 13; font.bold: true }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: sec.isCpu ? win.st.cpu.toFixed(0) + "% of " + win.st.cores + " cores"
                                            : win.fmtMem(win.st.memUsed) + " / " + win.fmtMem(win.st.memTotal)
                            color: Colors.subtext0; font.family: shell.font; font.pixelSize: 11
                        }
                    }

                    Repeater {
                        model: sec.rows
                        delegate: Item {
                            required property var modelData
                            width: sec.width; height: 20
                            // CPU rows are % of one core (can exceed 100); scale to all cores.
                            readonly property real frac: sec.isCpu
                                ? Math.min(1, modelData.v / (100 * win.st.cores))
                                : Math.min(1, modelData.v / win.st.memTotal)
                            Rectangle {
                                anchors.fill: parent; radius: 5
                                color: Colors.surface0; opacity: 0.55
                            }
                            Rectangle {
                                height: parent.height; radius: 5
                                width: Math.max(6, parent.width * Math.min(1, parent.frac * (sec.isCpu ? 4 : 2.2)))
                                color: sec.modelData.col; opacity: 0.30
                                Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                            }
                            Text {
                                x: 8; anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 62; elide: Text.ElideRight
                                text: parent.modelData.name
                                color: Colors.text; font.family: shell.font; font.pixelSize: 12
                            }
                            Text {
                                anchors.right: parent.right; anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: sec.isCpu ? parent.modelData.v.toFixed(1) + "%" : win.fmtMem(parent.modelData.v)
                                color: sec.modelData.col; font.family: shell.font; font.pixelSize: 12
                            }
                        }
                    }
                }
            }
        }
    }
}
