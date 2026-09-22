#!/usr/bin/env bash
# Waybar custom module: cava audio visualizer.
# Turns cava's raw ascii frames into block characters, one line per frame.
# Uses its own cava profile so the interactive ~/.config/cava/config is untouched.

CONFIG="$HOME/.config/cava/waybar-config"

# Drop a visualizer left behind by a previous waybar instance. The pattern is
# scoped to this profile so an interactive cava session is never touched.
pkill -f "cava -p $CONFIG" 2>/dev/null

# When waybar goes away the pipe collapses and SIGPIPE takes cava with it.
cava -p "$CONFIG" | awk '
BEGIN {
    blk[0] = "▁"; blk[1] = "▂"; blk[2] = "▃"; blk[3] = "▄"
    blk[4] = "▅"; blk[5] = "▆"; blk[6] = "▇"; blk[7] = "█"
    hold = 45          # frames of silence before collapsing (~1.5s at 30fps)
    quiet = 0
    hidden = 0
}
{
    n = split($0, f, ";")
    line = ""
    active = 0
    for (i = 1; i < n; i++) {
        v = f[i] + 0
        if (v < 0) v = 0
        if (v > 7) v = 7
        if (v > 0) active = 1
        line = line blk[v]
    }

    if (active) quiet = 0; else quiet++

    if (quiet > hold) {
        # Empty text makes waybar collapse the module instead of parking a
        # flat baseline in the bar. Emit it once, not every frame.
        if (!hidden) { print ""; fflush(); hidden = 1 }
    } else {
        hidden = 0
        print line
        fflush()
    }
}'
