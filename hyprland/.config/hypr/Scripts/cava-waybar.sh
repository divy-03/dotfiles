#!/usr/bin/env bash
# Waybar custom module: cava audio visualizer, layered over the mpris module.
# Turns cava's raw ascii frames into block characters, one JSON line per frame.
# Uses its own cava profile so the interactive ~/.config/cava/config is untouched.
#
# Because this module paints on top of mpris it also swallows its pointer events,
# so waybar's config gives it the same click and scroll bindings and this script
# supplies the matching tooltip.
#
# The module is gated on a media player existing so it appears and disappears in
# step with mpris. It deliberately does NOT blank itself on silence: mpris is
# overlaid on it with a negative margin, so a zero-width visualizer drags mpris
# out of the group and the whole player vanishes. A paused player therefore
# keeps a flat baseline here, which is what leaves something to click to resume.

CONFIG="$HOME/.config/cava/waybar-config"

# Drop a visualizer left behind by a previous waybar instance. The pattern is
# scoped to this profile so an interactive cava session is never touched.
pkill -f "cava -p $CONFIG" 2>/dev/null

# Player state is event-driven rather than polled: playerctl and cava share one
# pipe, and the P: prefix tells the two apart. Both write single short lines, so
# the writes stay under PIPE_BUF and never interleave.
{
    playerctl --follow metadata \
        --format 'P:{{status}}|~|{{playerName}}|~|{{title}}|~|{{artist}}|~|{{album}}' 2>/dev/null &
    cava -p "$CONFIG"
} | awk '
function esc(s,   out, i, c) {
    # Minimal JSON string escaping. Runs only when metadata changes, not per frame.
    out = ""
    for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (c == "\\")      out = out "\\\\"
        else if (c == "\"") out = out "\\\""
        else                out = out c
    }
    return out
}

BEGIN {
    blk[0] = "▁"; blk[1] = "▂"; blk[2] = "▃"; blk[3] = "▄"
    blk[4] = "▅"; blk[5] = "▆"; blk[6] = "▇"; blk[7] = "█"
    player = 0
    shown = -1
    tip = ""
}

# playerctl prints a bare empty line once the last player goes away.
/^$/ { player = 0; next }

# Status and metadata from playerctl. Mirrors mpris tooltip-format.
/^P:/ {
    split(substr($0, 3), m, "\\|~\\|")
    player = (m[1] != "")
    tip = esc(m[2]) "\\n" esc(m[3]) "\\n" esc(m[4]) "\\n" esc(m[5])
    next
}

{
    if (!player) {
        # Only ever collapse when there is no player at all, so this stays in
        # lockstep with mpris hiding itself and the group empties as a whole.
        if (shown != 0) { print "{\"text\":\"\"}"; fflush(); shown = 0 }
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

    printf "{\"text\":\"%s\",\"tooltip\":\"%s\"}\n", line, tip
    fflush()
    shown = 1
}'
