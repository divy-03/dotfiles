#!/usr/bin/env bash
# Cava audio visualizer for the hyprlock lock screen.
#
# hyprlock can only put the stdout of a command into a label and re-runs that
# command on a timer; there is no way to stream into it. cava needs a few hundred
# milliseconds to lock onto the audio, so starting it per tick is not an option.
# The work is therefore split in two (see hyprlock-daemon.sh):
#
#   --daemon   runs cava once and keeps the newest frame in a file under
#              $XDG_RUNTIME_DIR, tearing itself down when hyprlock goes away so
#              nothing is left burning CPU on an unlocked session.
#   (no args)  is what the label runs 20x a second: print that frame, starting
#              the daemon first if it is not up yet.
#
# A frame is the bars of the original one-line version stacked into rows: each
# bar is a column of full blocks topped by a partial one (▁ to ▇), so its height
# has eighth-of-a-row resolution. It spans the bottom of the lock screen, behind
# every other widget, and is blank whenever nothing is playing.
#
# Frames are written in place with bash's read-write redirection (1<>) instead of
# a truncating >, because a reader ticking at the same rate as the writer will
# eventually open the file mid-write. Every frame is the same byte length -- every
# cell is a 3-byte character, bar or blank, and the row breaks never move -- so an
# in-place overwrite can only ever hand a reader whole characters, never a
# half-written UTF-8 sequence that pango would choke on. The only truncating
# write is the blank frame, and that happens on a state change rather than every
# tick.

set -u

CONFIG="$HOME/.config/cava/hyprlock-config"
FRAME="${XDG_RUNTIME_DIR:-/tmp}/cava-hyprlock"
PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/cava-hyprlock.pid"

. "${0%/*}/hyprlock-daemon.sh"

run_daemon() {
    # Checked here rather than on every read. Without cava the readers find no
    # frames, and retry the daemon every few seconds.
    command -v cava >/dev/null 2>&1 || exit 0
    echo "$$" > "$PIDFILE"
    trap 'rm -f "$PIDFILE" "$FRAME"' EXIT TERM INT
    # A frame left behind by a daemon that died hard could be longer than ours,
    # and the in-place writes below would leave its tail on the end.
    : > "$FRAME"

    # Eight levels per row (the eighths of a block), so the height is set in
    # one place: ascii_max_range in the cava config.
    local max=8 key eq val
    while read -r key eq val; do
        [[ $key == ascii_max_range && $eq == = ]] && max=$val
    done < "$CONFIG"

    exit_with_hyprlock

    # playerctl is merged into cava's pipe behind a P: marker rather than polled:
    # --follow is event-driven and emits the current status immediately, and a
    # bare empty line when the last player exits. Both producers write short
    # lines, well under PIPE_BUF, so the writes stay atomic and never interleave.
    {
        playerctl --follow status --format 'P:{{status}}' 2>/dev/null &
        cava -p "$CONFIG"
    } | awk -v max="$max" '
    BEGIN {
        part[1] = "▁"; part[2] = "▂"; part[3] = "▃"; part[4] = "▄"
        part[5] = "▅"; part[6] = "▆"; part[7] = "▇"; full = "█"
        # U+2001 EM QUAD: blank, but in JetBrains Mono exactly as wide as a block
        # and, like one, 3 bytes long -- see the header for why that matters.
        off = "\342\200\201"
        rows = int((max + 7) / 8)
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
        n = split($0, f, ";") - 1
        for (i = 1; i <= n; i++) {
            v = f[i] + 0
            # Silence still draws the bottom eighth, like the one-line version.
            if (v < 1) v = 1
            if (v > max) v = max
            lvl[i] = v
        }
        # Rows are separated by tabs so a frame stays one line through the read
        # loop below, which turns them back into newlines.
        frame = ""
        for (r = rows; r >= 1; r--) {
            base = (r - 1) * 8
            for (i = 1; i <= n; i++) {
                v = lvl[i] - base
                frame = frame (v >= 8 ? full : v >= 1 ? part[v] : off)
            }
            if (r > 1) frame = frame "\t"
        }
        print frame
        fflush()
        shown = 1
    }' | while IFS= read -r line; do
        if [[ -n $line ]]; then
            printf '%s\n' "${line//$'\t'/$'\n'}" 1<> "$FRAME"
        else
            : > "$FRAME"
        fi
    done
}

if [[ ${1-} == --daemon ]]; then
    run_daemon
    exit 0
fi

# Reader path. Every builtin here is deliberate: this runs 20x a second, on
# hyprlock's main thread. read -d '' rather than $(< ...), which forks.
ensure_daemon "$PIDFILE" "$CONFIG"
[[ -r $FRAME ]] && IFS= read -r -d '' frame < "$FRAME"
printf '%s' "${frame-}"
exit 0
