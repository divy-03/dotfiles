#!/usr/bin/env bash

WALLPAPER_DIR="$HOME/Pictures/wallpapers"

# Find images (jpg, png, jpeg, gif)
selected_wallpaper=$(find "$WALLPAPER_DIR" -maxdepth 1 -type f \
  \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" \) |
  sort |
  rofi -dmenu -i -p "🖼 Choose wallpaper:")

# Exit if no selection
[ -z "$selected_wallpaper" ] && exit 0

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
