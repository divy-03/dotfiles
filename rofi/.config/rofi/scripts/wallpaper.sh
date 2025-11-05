#!/usr/bin/env bash

WALLPAPER_DIR="$HOME/Pictures/wallpapers/walls-catppuccin-mocha"
CACHE_DIR="$HOME/.cache/rofi/wallpaper-thumbs"

# Create cache directory if it doesn't exist
mkdir -p "$CACHE_DIR"

# Function to generate thumbnail
generate_thumbnail() {
  local source="$1"
  local dest="$2"

  # Only regenerate if thumbnail doesn't exist or source is newer
  if [[ ! -f "$dest" ]] || [[ "$source" -nt "$dest" ]]; then
    convert "$source" -resize 300x200^ -gravity center -extent 300x200 "$dest" 2>/dev/null
  fi
}

# Get a list of image files
mapfile -t images < <(find "$WALLPAPER_DIR" -maxdepth 1 -type f \
  \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" \) |
  sort)

# Generate thumbnails and prepare rofi entries
entries=()
for img in "${images[@]}"; do
  filename=$(basename "$img")
  thumbnail="$CACHE_DIR/${filename%.*}.png"

  # Generate thumbnail in background if needed
  generate_thumbnail "$img" "$thumbnail" &

  # Create rofi entry with icon
  entries+=("$filename\0icon\x1f$thumbnail")
done

# Wait for thumbnail generation to complete
wait

# Show rofi with custom theme
selected_name=$(printf '%b\n' "${entries[@]}" | rofi -dmenu -i -p "🖼 " \
  -theme ~/.config/rofi/wallpaper.rasi \
  -show-icons)

# Exit if no selection
[ -z "$selected_name" ] && exit 0

# Get the full path that matches the chosen filename
selected_wallpaper=$(printf '%s\n' "${images[@]}" | grep "/$selected_name$")

# Apply wallpaper with swww
if [[ "$selected_wallpaper" == *.gif ]]; then
  swww img "$selected_wallpaper" --transition-type none
else
  swww img "$selected_wallpaper" --transition-type any --transition-fps 60 --transition-duration 1.5
fi

# Optional: Save current wallpaper to a file for persistence
echo "$selected_wallpaper" >"$HOME/.cache/current_wallpaper"
