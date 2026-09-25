#!/usr/bin/env bash
# Set a wallpaper with awww and regenerate the desktop colors from it (matugen).
# usage: set-wallpaper.sh <image> [--no-transition]
set -u
# matugen is a cargo install; Hyprland's exec PATH doesn't include ~/.cargo/bin
export PATH="$HOME/.cargo/bin:$PATH"

wall="${1:-}"
[[ -f "$wall" ]] || { echo "usage: $0 <image>" >&2; exit 1; }
wall="$(realpath "$wall")"

if [[ "$wall" == *.gif || "${2:-}" == --no-transition ]]; then
  awww img "$wall" --transition-type none
else
  awww img "$wall" --transition-type any --transition-fps 60 --transition-duration 1.5
fi

echo "$wall" >"$HOME/.cache/current_wallpaper"

# matugen can't read animated gifs reliably; use the first frame
src="$wall"
if [[ "$wall" == *.gif ]]; then
  src="$HOME/.cache/matugen/wallpaper-frame.png"
  mkdir -p "${src%/*}"
  magick "${wall}[0]" "$src"
fi

matugen image "$src" -m dark -q
