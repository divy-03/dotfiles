#!/bin/bash
# Toggle between swayosd and wpctl

if pgrep -x swayosd-server >/dev/null; then
  # Switch to wpctl
  killall swayosd-server
  notify-send "Audio Control" "Switched to wpctl"
else
  # Switch to swayosd
  swayosd-server &
  notify-send "Audio Control" "Switched to swayosd"
fi
