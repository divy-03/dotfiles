#!/usr/bin/env bash
# Set a wallpaper with awww. When the "Wallpaper (auto)" theme is active, the
# desktop colors are regenerated from it (matugen, via ~/.config/theme/theme);
# a preset theme (Super+Shift+G) keeps its colors.
# usage: set-wallpaper.sh <image> [--no-transition]
set -u

wall="${1:-}"
[[ -f "$wall" ]] || { echo "usage: $0 <image>" >&2; exit 1; }
wall="$(realpath "$wall")"

if [[ "$wall" == *.gif || "${2:-}" == --no-transition ]]; then
  awww img "$wall" --transition-type none
else
  awww img "$wall" --transition-type any --transition-fps 60 --transition-duration 1.5
fi

echo "$wall" >"$HOME/.cache/current_wallpaper"

~/.config/theme/theme refresh
