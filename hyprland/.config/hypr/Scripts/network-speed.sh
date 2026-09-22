#!/usr/bin/env bash
# Waybar custom module: real-time download / upload speed.
# Emits one JSON line per second for whichever interface holds the default route,
# so it follows wifi <-> ethernet switches and ignores docker/veth bridges.

INTERVAL=1

default_iface() {
    ip route show default 2>/dev/null | awk '/^default/ {print $5; exit}'
}

counters() {
    # iface -> "<rx bytes> <tx bytes>"
    awk -v iface="$1:" '$1 == iface {print $2, $10}' /proc/net/dev
}

rate() {
    # bytes/s -> padded 5-char value for the bar, e.g. "  0B", " 1.2M", "12.3M"
    awk -v b="$1" 'BEGIN {
        split("B K M G T", unit, " ")
        i = 1
        while (b >= 1024 && i < 5) { b /= 1024; i++ }
        if (i == 1 || b >= 10) printf "%5s", sprintf("%.0f%s", b, unit[i])
        else                   printf "%5s", sprintf("%.1f%s", b, unit[i])
    }'
}

total() {
    # bytes -> spelled-out value for the tooltip, e.g. "452.3 MB"
    awk -v b="$1" 'BEGIN {
        split("B KB MB GB TB", unit, " ")
        i = 1
        while (b >= 1024 && i < 5) { b /= 1024; i++ }
        if (i == 1) printf "%d %s", b, unit[i]
        else        printf "%.1f %s", b, unit[i]
    }'
}

prev_iface=""
prev_rx=0
prev_tx=0

while true; do
    iface=$(default_iface)

    if [ -z "$iface" ]; then
        printf '{"text":"󰤭 offline","tooltip":"No network connection","class":"disconnected"}\n'
        prev_iface=""
        sleep "$INTERVAL"
        continue
    fi

    read -r rx tx < <(counters "$iface")
    : "${rx:=0}" "${tx:=0}"

    if [ "$iface" != "$prev_iface" ]; then
        # First sample on a new interface: no delta to report yet.
        down=0
        up=0
    else
        down=$(( (rx - prev_rx) / INTERVAL ))
        up=$(( (tx - prev_tx) / INTERVAL ))
        # Counters reset when an interface goes down and comes back.
        [ "$down" -lt 0 ] && down=0
        [ "$up" -lt 0 ] && up=0
    fi

    prev_iface="$iface"
    prev_rx="$rx"
    prev_tx="$tx"

    printf '{"text":"󰇚%s  󰕒%s","tooltip":"%s\\nDownloaded: %s\\nUploaded: %s","class":"connected"}\n' \
        "$(rate "$down")" "$(rate "$up")" \
        "$iface" "$(total "$rx")" "$(total "$tx")"

    sleep "$INTERVAL"
done
