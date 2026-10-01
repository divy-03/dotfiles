#!/usr/bin/env bash
# Toggle an Android phone as a secondary monitor over USB.
# Creates a Hyprland headless output, serves it with wayvnc on localhost, and
# tunnels it to the phone with `adb reverse`. Open a VNC client on the phone
# (e.g. bVNC) and connect to localhost:5900.
#
# Usage: phone-monitor.sh [WxH[@R]] [scale]   (default 1920x1080@120, scale 1.5)
#        phone-monitor.sh pos 0|1|2           move the phone screen (live)
#
# Position (also remembered across restarts):
#   0 = left of the laptop, bottom-aligned
#   1 = centered below the laptop
#   2 = right of the laptop, bottom-aligned
# Set the initial one with POSITION=N phone-monitor.sh, or use `pos N`.

POSFILE="${XDG_STATE_HOME:-$HOME/.local/state}/phone-monitor.position"
PORT=5900
STATE="${XDG_RUNTIME_DIR:-/tmp}/phone-monitor.state" # line 1: output, 2: mode, 3: scale

notify() {
  notify-send -a phone-monitor "Phone monitor" "$1" 2>/dev/null
  echo "$1"
}

stop() {
  local name
  name="$(head -n1 "$STATE" 2>/dev/null)"
  pkill -f "wayvnc.*127.0.0.1 $PORT" 2>/dev/null
  adb reverse --remove "tcp:$PORT" >/dev/null 2>&1
  [ -n "$name" ] && hyprctl output remove "$name" >/dev/null 2>&1
  rm -f "$STATE"
  notify "Stopped"
}

# Apply the phone's mode/scale at position $1 (see header).
# Hyprland only has auto-left/right/up/down and shifts the whole layout when
# a monitor gets negative coordinates, so both monitors are placed explicitly
# with non-negative coordinates (laptop moves instead of the phone going <0).
place() {
  local pos="$1" name="$2" mode="$3" scale="$4" res pw ph primary pname pmode pscale prw prh
  local px py qx qy
  res="${mode%%@*}"
  pw=$(awk -v w="${res%x*}" -v s="$scale" 'BEGIN{printf "%d", w/s}')
  ph=$(awk -v h="${res#*x}" -v s="$scale" 'BEGIN{printf "%d", h/s}')
  primary="$(hyprctl monitors -j | jq -c --arg n "$name" '[.[] | select(.name != $n)][0]')"
  pname=$(echo "$primary" | jq -r '.name')
  pscale=$(echo "$primary" | jq -r '.scale')
  pmode=$(echo "$primary" | jq -r '"\(.width)x\(.height)@\(.refreshRate)"')
  prw=$(echo "$primary" | jq -r '(.width / .scale) | floor')
  prh=$(echo "$primary" | jq -r '(.height / .scale) | floor')
  case "$pos" in
  1) px=$((pw > prw ? (pw - prw) / 2 : 0)) py=0
     qx=$((prw > pw ? (prw - pw) / 2 : 0)) qy=$prh ;;
  2) px=0 py=$((ph > prh ? ph - prh : 0))
     qx=$prw qy=$((prh > ph ? prh - ph : 0)) ;;
  *) px=$pw py=$((ph > prh ? ph - prh : 0))
     qx=0 qy=$((prh > ph ? prh - ph : 0)) ;;
  esac
  hyprctl --batch "keyword monitor $pname,$pmode,${px}x${py},$pscale ; keyword monitor $name,$mode,${qx}x${qy},$scale" >/dev/null
}

if [ "$1" = "pos" ] || [ "$1" = "restore" ]; then
  # `restore` re-applies the saved position; hyprland.conf runs it on every
  # config reload, which otherwise resets the phone to Hyprland's auto-right.
  if [ "$1" = "restore" ]; then
    set -- pos "$(cat "$POSFILE" 2>/dev/null)"
    [ -n "$2" ] || set -- pos 0
  fi
  case "$2" in 0 | 1 | 2) ;; *)
    echo "usage: $0 pos 0|1|2" >&2
    exit 1
    ;;
  esac
  mkdir -p "$(dirname "$POSFILE")" && echo "$2" >"$POSFILE"
  if [ -f "$STATE" ]; then
    { read -r pname; read -r pmode; read -r pscale; } <"$STATE"
    # fall back to the live values if the state file predates mode/scale
    [ -n "$pmode" ] || pmode="1920x1080@120"
    [ -n "$pscale" ] || pscale="$(hyprctl monitors -j | jq -r --arg n "$pname" '.[] | select(.name == $n) | .scale')"
    place "$2" "$pname" "$pmode" "$pscale"
  fi
  exit 0
fi

MODE="${1:-1920x1080@120}"
SCALE="${2:-1.5}"

if [ -f "$STATE" ]; then
  stop
  exit 0
fi

for dep in wayvnc adb hyprctl jq; do
  command -v "$dep" >/dev/null || {
    notify "Missing dependency: $dep"
    exit 1
  }
done

if ! adb get-state >/dev/null 2>&1; then
  notify "No authorized phone via adb (enable USB debugging, accept prompt)"
  exit 1
fi

before="$(hyprctl monitors -j | jq -r '.[].name' | sort)"
hyprctl output create headless >/dev/null
sleep 0.3
name="$(comm -13 <(echo "$before") <(hyprctl monitors -j | jq -r '.[].name' | sort) | head -n1)"
[ -n "$name" ] || {
  notify "Failed to create headless output"
  exit 1
}
printf '%s\n%s\n%s\n' "$name" "$MODE" "$SCALE" >"$STATE"

POSITION="${POSITION:-$(cat "$POSFILE" 2>/dev/null)}"
place "${POSITION:-0}" "$name" "$MODE" "$SCALE"

if ! adb reverse "tcp:$PORT" "tcp:$PORT" >/dev/null; then
  notify "adb reverse failed"
  stop
  exit 1
fi

notify "$name up. On phone: VNC client -> localhost:$PORT"
wayvnc -o "$name" 127.0.0.1 "$PORT" # blocks until killed or client quits
[ -f "$STATE" ] && stop
