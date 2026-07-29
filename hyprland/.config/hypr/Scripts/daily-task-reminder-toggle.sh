#!/bin/bash
# Starts/stops the daily-task-reminder daemon. Used both from a keybind and
# from the swaync toggle button (config.json widget-config.buttons-grid#reminder):
#   command:        daily-task-reminder-toggle.sh apply   (reads $SWAYNC_TOGGLE_STATE)
#   update-command: daily-task-reminder-toggle.sh status  (echoes true/false)

SCRIPT="$HOME/.config/hypr/Scripts/daily-task-reminder.sh"
PATTERN="bash .*/Scripts/daily-task-reminder\.sh$"

is_running() {
  pgrep -f "$PATTERN" >/dev/null
}

start() {
  is_running && return
  setsid nohup bash "$SCRIPT" >/dev/null 2>&1 </dev/null &
  disown
  notify-send -a "Daily Tasks" "Task reminders enabled"
}

stop() {
  is_running || return
  pkill -f "$PATTERN"
  notify-send -a "Daily Tasks" "Task reminders disabled"
}

case "$1" in
start) start ;;
stop) stop ;;
toggle)
  if is_running; then stop; else start; fi
  ;;
apply)
  if [[ "$SWAYNC_TOGGLE_STATE" == "true" ]]; then start; else stop; fi
  ;;
status)
  is_running && echo true || echo false
  ;;
*)
  echo "usage: $0 {start|stop|toggle|apply|status}" >&2
  exit 1
  ;;
esac
