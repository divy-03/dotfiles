#!/usr/bin/env bash
# swayosd has no reload signal; restart it so it picks up new colors.
# The D-Bus name lingers briefly after the old server exits, so a fresh
# server can die right away -- retry until one stays up.
pkill -x swayosd-server
for _ in $(seq 30); do
  pgrep -x swayosd-server >/dev/null || break
  sleep 0.1
done

for _ in $(seq 10); do
  setsid -f swayosd-server >/dev/null 2>&1
  sleep 1
  pgrep -x swayosd-server >/dev/null && exit 0
done
exit 1
