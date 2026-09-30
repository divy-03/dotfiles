#!/usr/bin/env bash
# Toggle an Android phone as a secondary monitor over USB.
# Creates a Hyprland headless output, serves it with wayvnc on localhost, and
# tunnels it to the phone with `adb reverse`. Open a VNC client on the phone
# (e.g. bVNC) and connect to localhost:5900.
#
# Usage: phone-monitor.sh [WxH[@R]] [scale]   (default 1920x1080@60, scale 1)

MODE="${1:-1920x1080@60}"
SCALE="${2:-1}"
PORT=5900
STATE="${XDG_RUNTIME_DIR:-/tmp}/phone-monitor.state"

notify() { notify-send -a phone-monitor "Phone monitor" "$1" 2>/dev/null; echo "$1"; }

stop() {
    local name
    name="$(cat "$STATE" 2>/dev/null)"
    pkill -f "wayvnc.*127.0.0.1 $PORT" 2>/dev/null
    adb reverse --remove "tcp:$PORT" >/dev/null 2>&1
    [ -n "$name" ] && hyprctl output remove "$name" >/dev/null 2>&1
    rm -f "$STATE"
    notify "Stopped"
}

if [ -f "$STATE" ]; then
    stop
    exit 0
fi

for dep in wayvnc adb hyprctl jq; do
    command -v "$dep" >/dev/null || { notify "Missing dependency: $dep"; exit 1; }
done

if ! adb get-state >/dev/null 2>&1; then
    notify "No authorized phone via adb (enable USB debugging, accept prompt)"
    exit 1
fi

before="$(hyprctl monitors -j | jq -r '.[].name' | sort)"
hyprctl output create headless >/dev/null
sleep 0.3
name="$(comm -13 <(echo "$before") <(hyprctl monitors -j | jq -r '.[].name' | sort) | head -n1)"
[ -n "$name" ] || { notify "Failed to create headless output"; exit 1; }
echo "$name" > "$STATE"

hyprctl keyword monitor "$name,$MODE,auto-right,$SCALE" >/dev/null

if ! adb reverse "tcp:$PORT" "tcp:$PORT" >/dev/null; then
    notify "adb reverse failed"
    stop
    exit 1
fi

notify "$name up. On phone: VNC client -> localhost:$PORT"
wayvnc -o "$name" 127.0.0.1 "$PORT"   # blocks until killed or client quits
[ -f "$STATE" ] && stop
