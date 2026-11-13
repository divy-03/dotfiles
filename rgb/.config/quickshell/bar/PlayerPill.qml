import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Wayland

// The "now playing" pill (left of the clock). Hover to list every player.
PanelWindow {
    id: win
    required property var shell

    readonly property int pillW: 330
    readonly property int popW: 340
    // playerctld is a proxy that mirrors whichever player is active, so it would
    // show every song twice.
    readonly property var players: Mpris.players.values.filter(p => p.dbusName.indexOf("playerctld") < 0
        // a player with no track (idle browser, closed tab) is nothing to show
        && (p.trackTitle !== "" || p.isPlaying))
    property string pinned: ""   // identity the user last picked from the popup

    // Active player: the pinned one, else the first one playing, else the first.
    readonly property var active: {
        var ps = players, i
        if (pinned) for (i = 0; i < ps.length; i++) if (ps[i].dbusName === pinned) return ps[i]
        for (i = 0; i < ps.length; i++) if (ps[i].isPlaying) return ps[i]
        return ps.length ? ps[0] : null
    }

    property bool hovered: false
    onPlayersChanged: if (!players.length) hovered = false

    anchors { top: true; right: true }
    margins.right: shell.rightReserve + 150 + shell.gap
    margins.top: 0
    implicitWidth: Math.max(pillW, popW)
    implicitHeight: shell.pillTop + shell.pillH + 8 + pop.implicitHeight + 10
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "bar-player"
    visible: players.length > 0 && shell.visibleBar

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
        width: win.players.length === 0 ? 0 : (pop.active ? win.popW : win.pillW)
        x: win.width - width
        height: win.players.length === 0 ? 0 : shell.pillTop + shell.pillH + (pop.active ? 8 + pop.height + 10 : 0)

    }

    // ---- pill ---------------------------------------------------------
    Rectangle {
        id: pill
        visible: win.players.length > 0
        x: win.width - win.pillW; y: shell.pillTop
        width: win.pillW; height: shell.pillH
        radius: 8
        color: Colors.crust
        clip: true

        // cava bars painted behind the title, only while something plays
        property var levels: []
        Row {
            anchors.fill: parent
            anchors.margins: 0
            spacing: 0
            Repeater {
                model: 34
                Rectangle {
                    width: pill.width / 34
                    height: Math.max(2, (pill.levels[index] || 0) / 7 * pill.height * 0.9)
                    anchors.bottom: parent.bottom
                    color: Colors.accent
                    opacity: 0.22
                    Behavior on height { NumberAnimation { duration: 60 } }
                }
            }
        }

        Process {
            running: win.active !== null && win.active.isPlaying
            command: ["cava", "-p", Quickshell.env("HOME") + "/.config/cava/waybar-config"]
            stdout: SplitParser {
                onRead: data => pill.levels = data.split(";").slice(0, 34).map(Number)
            }
            onRunningChanged: if (!running) pill.levels = []
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12; anchors.rightMargin: 12
            spacing: 8
            Text {
                text: win.active && win.active.isPlaying ? "▶" : "⏸"
                color: win.active && win.active.isPlaying ? Colors.green : Colors.accent
                font.family: shell.font; font.pixelSize: 12
            }
            Text {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: win.active ? (win.active.trackTitle || win.active.identity) +
                      (win.active.trackArtist ? "  -  " + win.active.trackArtist : "") : ""
                color: win.active && win.active.isPlaying ? Colors.green : Colors.subtext0
                font.family: shell.font; font.pixelSize: 13
                font.italic: win.active && !win.active.isPlaying
            }
            Text {
                visible: win.players.length > 1
                text: win.players.length
                color: Colors.overlay0
                font.family: shell.font; font.pixelSize: 11
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: m => {
                if (!win.active) return
                if (m.button === Qt.LeftButton) win.active.togglePlaying()
                else if (m.button === Qt.RightButton) win.active.next()
                else Hyprland.dispatch("togglespecialworkspace spotify")
            }
            onWheel: w => {
                if (win.active && win.active.volumeSupported)
                    win.active.volume = Math.max(0, Math.min(1, win.active.volume + (w.angleDelta.y > 0 ? 0.05 : -0.05)))
            }
        }
    }

    // ---- popup --------------------------------------------------------
    Popup {
        id: pop
        shown: win.hovered && win.players.length > 0
        x: win.width - win.popW
        y: shell.pillTop + shell.pillH + 8
        width: win.popW
        implicitHeight: list.implicitHeight + 24
        height: implicitHeight
        visible: active && win.players.length > 0

        Column {
            id: list
            x: 12; y: 12
            width: pop.width - 24
            spacing: 10

            Repeater {
                model: win.players
                delegate: Rectangle {
                    id: card
                    required property var modelData
                    readonly property bool isActive: modelData === win.active
                    width: list.width
                    height: 84
                    radius: 10
                    color: isActive ? Colors.surface0 : Colors.mantle
                    border.color: isActive ? Colors.accent : "transparent"
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }

                    // free-running position clock for the progress bar
                    property real pos: 0
                    Timer {
                        interval: 500; repeat: true; triggeredOnStart: true
                        running: pop.shown && card.modelData.playbackState === MprisPlaybackState.Playing
                        onTriggered: { card.modelData.positionChanged(); card.pos = card.modelData.position }
                    }
                    Connections {
                        target: card.modelData
                        function onPositionChanged() { card.pos = card.modelData.position }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: win.pinned = card.modelData.dbusName
                    }

                    Rectangle {
                        id: art
                        x: 8; y: 8; width: 68; height: 68; radius: 8
                        color: Colors.surface1
                        clip: true
                        Image {
                            anchors.fill: parent
                            source: card.modelData.trackArtUrl
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: status === Image.Ready
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: !card.modelData.trackArtUrl
                            text: "󰎆"
                            color: Colors.overlay0; font.family: shell.font; font.pixelSize: 26
                        }
                    }

                    Column {
                        x: 88; y: 8
                        width: card.width - 88 - 8
                        spacing: 1
                        Text {
                            width: parent.width; elide: Text.ElideRight
                            text: card.modelData.trackTitle || "Nothing playing"
                            color: Colors.text; font.family: shell.font; font.pixelSize: 13; font.bold: true
                        }
                        Text {
                            width: parent.width; elide: Text.ElideRight
                            text: card.modelData.trackArtist
                            color: Colors.subtext0; font.family: shell.font; font.pixelSize: 11
                            visible: text !== ""
                        }
                        Text {
                            width: parent.width; elide: Text.ElideRight
                            text: card.modelData.identity
                            color: Colors.overlay0; font.family: shell.font; font.pixelSize: 10
                        }
                    }

                    // controls
                    Row {
                        x: 88; y: 52
                        spacing: 4
                        Repeater {
                            model: [
                                { ic: "󰒮", en: card.modelData.canGoPrevious, fn: 0 },
                                { ic: card.modelData.isPlaying ? "󰏤" : "󰐊", en: card.modelData.canTogglePlaying, fn: 1 },
                                { ic: "󰒭", en: card.modelData.canGoNext, fn: 2 }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                width: 30; height: 22; radius: 6
                                color: ma.containsMouse ? Colors.surface1 : "transparent"
                                opacity: modelData.en ? 1 : 0.35
                                Behavior on color { ColorAnimation { duration: 120 } }
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.ic
                                    color: Colors.accent; font.family: shell.font; font.pixelSize: 15
                                }
                                MouseArea {
                                    id: ma
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        var p = card.modelData
                                        if (!parent.modelData.en) return
                                        if (parent.modelData.fn === 0) p.previous()
                                        else if (parent.modelData.fn === 1) p.togglePlaying()
                                        else p.next()
                                    }
                                }
                            }
                        }
                    }

                    // progress / seek
                    Rectangle {
                        x: 88 + 3 * 34 + 6; y: 62
                        width: card.width - x - 10; height: 4; radius: 2
                        color: Colors.surface1
                        visible: card.modelData.lengthSupported && card.modelData.length > 0
                        Rectangle {
                            width: parent.width * Math.min(1, card.pos / Math.max(1, card.modelData.length))
                            height: parent.height; radius: 2
                            color: Colors.accent
                            Behavior on width { NumberAnimation { duration: 400 } }
                        }
                        MouseArea {
                            anchors.fill: parent; anchors.margins: -6
                            enabled: card.modelData.canSeek
                            onClicked: m => {
                                var f = Math.max(0, Math.min(1, (m.x - 6) / parent.width))
                                card.modelData.position = f * card.modelData.length
                                card.pos = card.modelData.position
                            }
                        }
                    }
                }
            }
        }
    }
}
