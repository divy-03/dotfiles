#!/usr/bin/env bash
# Theme picker (Super+Shift+G): a preset palette, or colors from the wallpaper.
# Themes live in ~/.config/theme/themes; see ~/.config/theme/theme.
theme=~/.config/theme/theme

# one run of the theme script: id, name, preview image, 1 if current
ids=()
entries=()
active=0
while IFS=$'\t' read -r id name icon is_current; do
  [[ "$is_current" == 1 ]] && active=${#ids[@]}
  ids+=("$id")
  entries+=("$name\0icon\x1f$icon")
done < <("$theme" menu)

choice=$(printf '%b\n' "${entries[@]}" | rofi -dmenu -i -p "🎨 " \
  -theme ~/.config/rofi/theme.rasi -show-icons -format i \
  -a "$active" -selected-row "$active")

[[ -z "$choice" ]] && exit 0
out="$("$theme" set "${ids[$choice]}" 2>&1)" || notify-send -u critical "Theme" "$out"
