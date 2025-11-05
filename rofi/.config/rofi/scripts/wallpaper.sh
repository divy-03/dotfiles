#!/usr/bin/env bash

WALLPAPER_DIR="$HOME/Pictures/wallpapers/walls-catppuccin-mocha"

# Get a list of image files (jpg, jpeg, png, gif)
mapfile -t images < <(find "$WALLPAPER_DIR" -maxdepth 1 -type f \
  \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" \) |
  sort)

# Extract filenames for rofi display
filenames=()
for img in "${images[@]}"; do
  filenames+=("$(basename "$img")")
done

# Let user select a filename
selected_name=$(printf '%s\n' "${filenames[@]}" | rofi -dmenu -i -p "🖼")

# Exit if no selection
[ -z "$selected_name" ] && exit 0

# Get the full path that matches the chosen filename
selected_wallpaper=$(printf '%s\n' "${images[@]}" | grep "/$selected_name$")

# If it's a GIF, set without transition (to avoid flickering)
if [[ "$selected_wallpaper" == *.gif ]]; then
  swww img "$selected_wallpaper" --transition-type none
else
  swww img "$selected_wallpaper" --transition-type any --transition-fps 60 --transition-duration 1
fi

# Optionally notify (requires notify-send / libnotify)
#if command -v notify-send &>/dev/null; then
#  basename=$(basename "$selected_wallpaper")
#  notify-send "🖼 Wallpaper Changed" "$basename applied successfully"
#fi
