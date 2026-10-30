#!/usr/bin/env bash
# Start Waybar only on the laptop's physical monitor.
# The phone monitor is a dynamically-created HEADLESS-* Hyprland output.

set -euo pipefail

# Already running (e.g. Super+H pressed twice): do nothing instead of stacking bars.
pgrep -x waybar >/dev/null && exit 0

config="${XDG_CONFIG_HOME:-$HOME/.config}/waybar/config"
runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
temporary_config="$(mktemp "$runtime_dir/waybar-config.XXXXXX")"
trap 'rm -f "$temporary_config"' EXIT

# Hyprland may still be bringing its outputs up during autostart.
output=""
for _ in $(seq 1 50); do
  output="$(hyprctl monitors -j 2>/dev/null \
    | jq -r '[.[] | select((.name | ascii_upcase | startswith("HEADLESS-")) | not) | .name][0] // empty' \
    2>/dev/null || true)"
  [ -n "$output" ] && break
  sleep 0.1
done

if [ -z "$output" ]; then
  echo "waybar-main: could not find a physical Hyprland output" >&2
  exit 1
fi

# Waybar's config supports an output key, but does not expand shell variables.
# Insert the discovered connector into a temporary JSONC config instead.
sed "2i\\    \"output\": \"$output\"," "$config" >"$temporary_config"
exec waybar -c "$temporary_config"
