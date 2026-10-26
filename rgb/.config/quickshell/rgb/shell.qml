//@ pragma UseQApplication
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

// RGB control centre: the WLED strip, the Kreo keyboard and HyperHDR screen
// sync in one panel. Toggle it with: qs -c rgb ipc call rgb toggle
ShellRoot {
    id: root

    property bool open: false
    property string device: "strip"   // strip | keyboard
    property string tab: "color"      // strip: color | effects | music | screen
    property string screen: "down"    // HyperHDR: on | off | down
    property int gain: 100
    property bool syncStrip: true
    property bool syncKeyboard: true
    property int kbBrightness: 4
    property bool followStrip: false
    property string lastKb: ""
    property bool vizOn: false
    property string vizMode: "grow"
    property int vizGain: 100
    property int tick: 0
    readonly property string font: "JetBrainsMono Nerd Font"

    function hex(c) {
        function h(v) { return ("0" + Math.round(v * 255).toString(16)).slice(-2) }
        return "#" + h(c.r) + h(c.g) + h(c.b)
    }

    Component {
        id: procComp
        Process {
            id: p
            property var done: null
            stdout: StdioCollector {
                onStreamFinished: if (p.done) p.done(text.trim())
            }
            onExited: p.destroy(3000)
        }
    }

    function run(cmd, done) {
        var p = procComp.createObject(root, { command: cmd, done: done })
        p.running = true
    }

    function ctl(args, done) {
        run([Quickshell.env("HOME") + "/.local/bin/rgbctl"].concat(args), done)
    }

    function refresh() {
        wled.poll()
        ctl(["screen", "status"], function (s) { root.screen = s })
        ctl(["music", "status"], function (s) { root.vizOn = s === "on" })
    }

    function loadSettings() {
        ctl(["host"], function (h) { wled.host = h; wled.poll(); wled.loadEffects() })
        ctl(["sync", "strip"], function (s) { root.syncStrip = s === "on" })
        ctl(["sync", "keyboard"], function (s) { root.syncKeyboard = s === "on" })
        ctl(["follow"], function (s) { root.followStrip = s === "on"; if (root.followStrip) followTimer.restart() })
        ctl(["gain"], function (g) { root.gain = parseInt(g) || 100 })
        ctl(["music", "mode"], function (m) { root.vizMode = m })
        ctl(["music", "gain"], function (g) { root.vizGain = parseInt(g) || 100 })
        refresh()
    }

    // Turn screen sync off before anything that needs the strip to itself.
    // Color changes keep the visualizer running (it follows the strip's color).
    function strip(action, keepViz) {
        if (root.vizOn && !keepViz) {
            root.vizOn = false
            ctl(["music", "off"])
        }
        if (root.screen === "on") {
            ctl(["screen", "off"], function () {
                root.screen = "off"
                action()
            })
        } else {
            action()
        }
    }

    Wled { id: wled }

    // Keyboard mirrors the strip's color. A keyboard write takes seconds, so
    // wait until the color has settled and skip repeats.
    function followNow() {
        var c = hex(wled.color)
        if (!followStrip || !wled.online || c === lastKb)
            return
        lastKb = c
        kbPicker.setColor(wled.color)
        ctl(["keyboard", c, String(kbBrightness)])
    }

    Timer {
        id: followTimer
        interval: 1200
        onTriggered: root.followNow()
    }

    Connections {
        target: wled
        function onColorChanged() { if (root.followStrip) followTimer.restart() }
    }

    IpcHandler {
        target: "rgb"
        function toggle(): void { root.open = !root.open }
        function show(): void { root.open = true }
        function hide(): void { root.open = false }
    }

    Timer {
        interval: 1500
        running: root.open
        repeat: true
        onTriggered: {
            wled.poll()
            if (++root.tick % 2 === 0)
                ctl(["screen", "status"], function (s) { root.screen = s })
        }
    }

    onOpenChanged: if (open) loadSettings()

    PanelWindow {
        id: win
        visible: root.open
        anchors { top: true; right: true }
        margins { top: 56; right: 12 }
        implicitWidth: 380
        implicitHeight: card.implicitHeight
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        HyprlandFocusGrab {
            windows: [win]
            active: root.open
            onCleared: root.open = false
        }

        FocusScope {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: root.open = false

            Rectangle {
                id: card
                width: parent.width
                implicitHeight: body.implicitHeight + 32
                radius: 16
                color: Colors.base
                border.width: 1
                border.color: Colors.surface1

                ColumnLayout {
                    id: body
                    x: 16
                    y: 16
                    width: parent.width - 32
                    spacing: 12

                    // header
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "RGB"
                            color: Colors.text
                            font { pixelSize: 16; bold: true; family: root.font }
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            width: 8; height: 8; radius: 4
                            color: wled.online ? Colors.green : Colors.red
                        }
                        Text {
                            text: wled.online ? (wled.live ? "live (screen sync)" : wled.host) : "strip offline"
                            color: Colors.subtext0
                            font { pixelSize: 11; family: root.font }
                        }
                    }

                    // device selector
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Repeater {
                            model: [
                                { id: "strip", name: "LED strip" },
                                { id: "keyboard", name: "Keyboard" }
                            ]
                            delegate: Chip {
                                required property var modelData
                                Layout.fillWidth: true
                                label: modelData.name
                                active: root.device === modelData.id
                                onClicked: root.device = modelData.id
                            }
                        }
                    }

                    // ------------------------------------------------ strip
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.device === "strip"
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            Toggle {
                                checked: wled.on
                                onToggled: value => wled.setPower(value)
                            }
                            FlatSlider {
                                Layout.fillWidth: true
                                from: 1; to: 255
                                value: wled.bri
                                onMoved: (v, released) => wled.setBrightness(Math.round(v), released)
                            }
                            Text {
                                text: Math.round(wled.bri / 2.55) + "%"
                                color: Colors.subtext0
                                Layout.preferredWidth: 32
                                horizontalAlignment: Text.AlignRight
                                font { pixelSize: 11; family: root.font }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Repeater {
                                model: [
                                    { id: "color", name: "Color" },
                                    { id: "effects", name: "Effects" },
                                    { id: "music", name: "Music" },
                                    { id: "screen", name: "Screen" }
                                ]
                                delegate: Chip {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    label: modelData.name
                                    active: root.tab === modelData.id
                                    onClicked: root.tab = modelData.id
                                }
                            }
                        }

                        // color
                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: root.tab === "color"
                            spacing: 10
                            HSVPicker {
                                id: stripPicker
                                Layout.fillWidth: true
                                Layout.preferredHeight: implicitHeight
                                onPicked: released => root.strip(function () { wled.setColor(color, released) }, true)
                                Connections {
                                    target: wled
                                    function onPolled() {
                                        if (!stripPicker.dragging)
                                            stripPicker.setColor(wled.color)
                                    }
                                }
                            }
                            TempSlider {
                                Layout.fillWidth: true
                                onPicked: (c, released) => root.strip(function () { wled.setColor(c, released) }, true)
                            }
                            RowLayout {
                                spacing: 8
                                Repeater {
                                    model: [Colors.accent, Colors.secondary, "#ffffff", "#ffa000"]
                                    delegate: Rectangle {
                                        required property var modelData
                                        width: 28; height: 28; radius: 14
                                        color: modelData
                                        border.width: 1
                                        border.color: Colors.surface2
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                stripPicker.setColor(parent.color)
                                                root.strip(function () { wled.setColor(parent.color, true) }, true)
                                            }
                                        }
                                    }
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: root.hex(wled.color)
                                    color: Colors.subtext0
                                    font { pixelSize: 11; family: root.font }
                                }
                            }
                        }

                        // effects and music share the list
                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: root.tab === "effects" || root.tab === "music"
                            spacing: 8

                            // cava visualizer
                            ColumnLayout {
                                visible: root.tab === "music"
                                Layout.fillWidth: true
                                spacing: 8
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        Layout.fillWidth: true
                                        text: "Cava visualizer"
                                        color: Colors.text
                                        font { pixelSize: 13; bold: true; family: root.font }
                                    }
                                    Toggle {
                                        checked: root.vizOn
                                        onToggled: value => {
                                            root.vizOn = value
                                            if (!value) {
                                                root.ctl(["music", "off"])
                                                return
                                            }
                                            var start = function () { root.ctl(["music", "on"], function () { root.refresh() }) }
                                            if (root.screen === "on")
                                                root.ctl(["screen", "off"], function () { root.screen = "off"; start() })
                                            else
                                                start()
                                        }
                                    }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Repeater {
                                        model: [
                                            { id: "grow", name: "Bass | Treble" },
                                            { id: "mirror", name: "Mirror" },
                                            { id: "spectrum", name: "Spectrum" }
                                        ]
                                        delegate: Chip {
                                            required property var modelData
                                            Layout.fillWidth: true
                                            label: modelData.name
                                            active: root.vizMode === modelData.id
                                            onClicked: {
                                                root.vizMode = modelData.id
                                                root.ctl(["music", "mode", modelData.id])
                                            }
                                        }
                                    }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "Gain"; color: Colors.subtext0; Layout.preferredWidth: 64; font { pixelSize: 11; family: root.font } }
                                    FlatSlider {
                                        Layout.fillWidth: true
                                        from: 30; to: 250; step: 5
                                        value: root.vizGain
                                        onMoved: (v, released) => {
                                            if (released) {
                                                root.vizGain = Math.round(v)
                                                root.ctl(["music", "gain", String(Math.round(v))])
                                            }
                                        }
                                    }
                                }
                                Text {
                                    text: "WLED effects (sound reactive)"
                                    color: Colors.subtext0
                                    font { pixelSize: 11; family: root.font }
                                }
                            }

                            RowLayout {
                                visible: root.tab === "music"
                                Layout.fillWidth: true
                                Text {
                                    Layout.fillWidth: true
                                    text: wled.mic ? "Mic: " + wled.mic : "Mic: not found"
                                    color: Colors.subtext0
                                    elide: Text.ElideRight
                                    font { pixelSize: 11; family: root.font }
                                }
                                Text {
                                    text: "audio reactive"
                                    color: Colors.subtext0
                                    font { pixelSize: 11; family: root.font }
                                }
                                Toggle {
                                    checked: wled.audioOn
                                    onToggled: value => wled.setAudio(value)
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 150
                                radius: 8
                                color: Colors.mantle
                                clip: true

                                ListView {
                                    id: fxList
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    boundsBehavior: Flickable.StopAtBounds
                                    model: wled.effects.filter(e => e.id !== 0 && e.audio === (root.tab === "music"))
                                    delegate: Rectangle {
                                        required property var modelData
                                        width: fxList.width
                                        height: 26
                                        radius: 6
                                        color: wled.fx === modelData.id ? Colors.accent
                                             : hover.containsMouse ? Colors.surface0 : "transparent"
                                        Text {
                                            x: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.name
                                            color: wled.fx === modelData.id ? Colors.textOnAccent : Colors.text
                                            font { pixelSize: 12; family: root.font }
                                        }
                                        MouseArea {
                                            id: hover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.strip(function () {
                                                if (root.tab === "music" && !wled.audioOn)
                                                    wled.setAudio(true)
                                                wled.setEffect(modelData.id)
                                            })
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Speed"; color: Colors.subtext0; Layout.preferredWidth: 64; font { pixelSize: 11; family: root.font } }
                                FlatSlider {
                                    Layout.fillWidth: true
                                    from: 0; to: 255
                                    value: wled.sx
                                    onMoved: (v, released) => { if (released) wled.setSpeed(Math.round(v)) }
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: root.tab === "music" ? "Sensitivity" : "Intensity"; color: Colors.subtext0; Layout.preferredWidth: 64; font { pixelSize: 11; family: root.font } }
                                FlatSlider {
                                    Layout.fillWidth: true
                                    from: 0; to: 255
                                    value: wled.ix
                                    onMoved: (v, released) => { if (released) wled.setIntensity(Math.round(v)) }
                                }
                            }
                        }

                        // screen sync
                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: root.tab === "screen"
                            spacing: 12

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    Layout.fillWidth: true
                                    text: root.screen === "on" ? "HyperHDR is driving the strip"
                                        : root.screen === "off" ? "HyperHDR running, LED output off"
                                        : "HyperHDR is not running"
                                    color: Colors.subtext0
                                    font { pixelSize: 12; family: root.font }
                                }
                                Toggle {
                                    checked: root.screen === "on"
                                    onToggled: value => {
                                        if (value && root.vizOn) {
                                            root.vizOn = false
                                            root.ctl(["music", "off"])
                                        }
                                        root.ctl(["screen", value ? "on" : "off"], function () { root.refresh() })
                                    }
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Luminance"; color: Colors.subtext0; Layout.preferredWidth: 72; font { pixelSize: 11; family: root.font } }
                                FlatSlider {
                                    Layout.fillWidth: true
                                    from: 0; to: 100; step: 1
                                    value: root.gain
                                    onMoved: (v, released) => {
                                        root.gain = v
                                        if (released)
                                            root.ctl(["gain", String(Math.round(v))])
                                    }
                                }
                                Text {
                                    text: root.gain + "%"
                                    color: Colors.subtext0
                                    Layout.preferredWidth: 32
                                    horizontalAlignment: Text.AlignRight
                                    font { pixelSize: 11; family: root.font }
                                }
                            }
                        }
                    }

                    // -------------------------------------------- keyboard
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.device === "keyboard"
                        spacing: 12

                        HSVPicker {
                            id: kbPicker
                            Layout.fillWidth: true
                            Layout.preferredHeight: implicitHeight
                            hue: 0.6
                            // a write takes seconds, so only the released pick is sent
                            onPicked: released => { if (released) root.ctl(["keyboard", root.hex(color), String(root.kbBrightness)]) }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "Brightness"; color: Colors.subtext0; Layout.preferredWidth: 72; font { pixelSize: 11; family: root.font } }
                            FlatSlider {
                                Layout.fillWidth: true
                                from: 0; to: 4; step: 1
                                value: root.kbBrightness
                                onMoved: (v, released) => {
                                    root.kbBrightness = v
                                    if (released)
                                        root.ctl(["keyboard", root.hex(kbPicker.color), String(root.kbBrightness)])
                                }
                            }
                            Text {
                                text: root.kbBrightness + "/4"
                                color: Colors.subtext0
                                Layout.preferredWidth: 32
                                horizontalAlignment: Text.AlignRight
                                font { pixelSize: 11; family: root.font }
                            }
                        }
                    }

                    // keyboard follows the strip
                    RowLayout {
                        Layout.fillWidth: true
                        visible: root.device === "keyboard"
                        Text {
                            Layout.fillWidth: true
                            text: "Follow LED strip color"
                            color: Colors.text
                            font { pixelSize: 12; family: root.font }
                        }
                        Toggle {
                            checked: root.followStrip
                            onToggled: value => {
                                root.followStrip = value
                                root.lastKb = ""
                                root.ctl(["follow", value ? "on" : "off"])
                                if (value)
                                    followTimer.restart()
                            }
                        }
                    }

                    // ---------------------------------------- theme sync
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Colors.surface0
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text {
                            text: "Theme sync"
                            color: Colors.text
                            Layout.fillWidth: true
                            font { pixelSize: 12; family: root.font }
                        }
                        Text { text: "strip"; color: Colors.subtext0; font { pixelSize: 11; family: root.font } }
                        Toggle {
                            checked: root.syncStrip
                            onToggled: value => {
                                root.syncStrip = value
                                root.ctl(["sync", "strip", value ? "on" : "off"])
                            }
                        }
                        Text { text: "keys"; color: Colors.subtext0; font { pixelSize: 11; family: root.font } }
                        Toggle {
                            checked: root.syncKeyboard
                            onToggled: value => {
                                root.syncKeyboard = value
                                root.ctl(["sync", "keyboard", value ? "on" : "off"])
                            }
                        }
                        Chip {
                            label: "Sync now"
                            onClicked: root.strip(function () { root.ctl(["sync-now"]) })
                        }
                    }
                }
            }
        }
    }
}
