#!/usr/bin/env bash
# Restart waybar so it picks up new theme colors (SIGUSR2 reloads don't always
# repaint everything). Left alone when it isn't running (hidden with Super+Shift+H).
pgrep -x waybar >/dev/null || exit 0
pkill -x waybar
for _ in $(seq 30); do
  pgrep -x waybar >/dev/null || break
  sleep 0.1
done
setsid -f waybar >/dev/null 2>&1
