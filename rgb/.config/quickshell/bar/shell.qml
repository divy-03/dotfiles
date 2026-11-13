//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io

// Floating pills that sit either side of waybar's clock: the media player and
// CPU/RAM. Hovering either one opens an animated popup.
//   qs -c bar ipc call bar toggle|show|hide
ShellRoot {
    id: root
    property bool visibleBar: true
    readonly property string font: "JetBrainsMono Nerd Font"

    // Waybar's right-hand group (tray, volume, battery, power) is ~262px wide;
    // the pills sit just left of it. Raise this if you add tray icons.
    readonly property int rightReserve: 272
    readonly property int gap: 10
    readonly property int pillTop: 10
    readonly property int pillH: 34

    property var stats: ({ cpu: 0, cores: 1, memUsed: 0, memTotal: 1, topCpu: [], topMem: [] })

    Process {
        running: true
        command: [Quickshell.shellDir + "/sysstat.py", "2"]
        stdout: SplitParser {
            onRead: data => { try { root.stats = JSON.parse(data) } catch (e) {} }
        }
    }

    IpcHandler {
        target: "bar"
        function toggle(): void { root.visibleBar = !root.visibleBar }
        function show(): void { root.visibleBar = true }
        function hide(): void { root.visibleBar = false }
    }

    PlayerPill {
        visible: root.visibleBar
        shell: root
    }
    SysPill {
        visible: root.visibleBar
        shell: root
    }
}
