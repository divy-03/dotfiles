#!/usr/bin/env bash
# Cava audio visualizer for the hyprlock lock screen.
#
# hyprlock can only put the stdout of a command into a label and re-runs that
# command on a timer; there is no way to stream into it. cava needs a few hundred
# milliseconds to lock onto the audio, so starting it per tick is not an option.
# The work is therefore split in two:
#
#   --daemon   runs cava once and keeps the newest frame in a file under
#              $XDG_RUNTIME_DIR, tearing itself down when hyprlock goes away so
#              nothing is left burning CPU on an unlocked session.
#   (no args)  is what the label runs 20x a second: print that frame, starting
#              the daemon first if it is not up yet.
#
# Frames are written in place with bash's read-write redirection (1<>) instead of
# a truncating >, because a reader ticking at the same rate as the writer will
# eventually open the file mid-write. Every frame is the same byte length -- one
# 3-byte block character per bar -- so an in-place overwrite can only ever hand a
# reader whole characters, never a half-written UTF-8 sequence that pango would
# choke on. The only truncating write is the blank frame, and that happens on a
# state change rather than every tick.

set -u

CONFIG="$HOME/.config/cava/hyprlock-config"
FRAME="${XDG_RUNTIME_DIR:-/tmp}/cava-hyprlock"
PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/cava-hyprlock.pid"

# Liveness without forking: the reader runs 20x a second, so a pgrep per tick
# would cost more than everything else here put together. A daemon that has not
# written its pid yet is reported alive for a few seconds, so the gap between
# spawning it and it recording itself cannot start a second one.
daemon_alive() {
    local pid rest
    [[ -r $PIDFILE ]] || return 1
    read -r pid rest < "$PIDFILE" || return 1
    [[ -n $pid ]] || return 1
    if [[ $pid == starting ]]; then
        (( EPOCHSECONDS - rest < 5 ))
        return
    fi
    [[ -r /proc/$pid/cmdline ]] || return 1
    # Walked argument by argument because /proc/<pid>/cmdline is NUL-separated and
    # slurping it whole makes bash warn about null bytes on every single tick.
    local arg
    while read -r -d "" arg; do
        [[ $arg == *cava-hyprlock* ]] && return 0
    done < /proc/"$pid"/cmdline
    return 1
}

run_daemon() {
    echo "$$" > "$PIDFILE"
    trap 'rm -f "$PIDFILE" "$FRAME"' EXIT TERM INT

    # setsid put us in our own session, so the group holds cava, playerctl, awk
    # and this shell and nothing else -- `kill 0` cannot reach hyprlock.
    (
        while pgrep -x hyprlock >/dev/null 2>&1; do sleep 2; done
        kill 0 2>/dev/null
    ) &

    # playerctl is merged into cava's pipe behind a P: marker rather than polled:
    # --follow is event-driven and emits the current status immediately, and a
    # bare empty line when the last player exits. Both producers write short
    # lines, well under PIPE_BUF, so the writes stay atomic and never interleave.
    {
        playerctl --follow status --format 'P:{{status}}' 2>/dev/null &
        cava -p "$CONFIG"
    } | awk '
    BEGIN {
        blk[0] = "▁"; blk[1] = "▂"; blk[2] = "▃"; blk[3] = "▄"
        blk[4] = "▅"; blk[5] = "▆"; blk[6] = "▇"; blk[7] = "█"
        playing = 0; shown = -1
    }
    /^$/  { playing = 0; next }
    /^P:/ { playing = (substr($0, 3) == "Playing"); next }
    {
        # Nothing is playing: blank the label rather than parking a dead flat line
        # on the lock screen. Emitted once, so a paused player is not 20 pointless
        # truncations a second.
        if (!playing) {
            if (shown != 0) { print ""; fflush(); shown = 0 }
            next
        }
        n = split($0, f, ";")
        line = ""
        for (i = 1; i < n; i++) {
            v = f[i] + 0
            if (v < 0) v = 0
            if (v > 7) v = 7
            line = line blk[v]
        }
        print line
        fflush()
        shown = 1
    }' | while IFS= read -r line; do
        if [[ -n $line ]]; then
            printf '%s\n' "$line" 1<> "$FRAME"
        else
            : > "$FRAME"
        fi
    done
}

if [[ ${1-} == --daemon ]]; then
    run_daemon
    exit 0
fi

# Reader path. Every builtin here is deliberate: this runs 20x a second.
command -v cava >/dev/null 2>&1 || exit 0

if ! daemon_alive; then
    echo "starting $EPOCHSECONDS" > "$PIDFILE"
    setsid -f "$0" --daemon >/dev/null 2>&1 </dev/null
fi

[[ -r $FRAME ]] && printf '%s\n' "$(< "$FRAME")"
exit 0
