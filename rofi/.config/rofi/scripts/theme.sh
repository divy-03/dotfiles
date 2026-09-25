#!/usr/bin/env bash
# Theme picker (Super+Shift+G): a preset palette, or colors from the wallpaper.
# Themes live in ~/.config/theme/themes; see ~/.config/theme/theme.
theme=~/.config/theme/theme

mapfile -t ids < <("$theme" list | cut -f1)
mapfile -t names < <("$theme" list | cut -f2)
current="$("$theme" current)"

entries=()
active=0
for i in "${!ids[@]}"; do
  id="${ids[$i]}"
  if [[ "$id" == wallpaper ]]; then
    # the current wallpaper's thumbnail from the wallpaper picker, if it has one
    wall="$(cat ~/.cache/current_wallpaper 2>/dev/null)"
    wall="${wall##*/}"
    icon="$HOME/.cache/rofi/wallpaper-thumbs/${wall%.*}.png"
    [[ -f "$icon" ]] || icon="$("$theme" preview wallpaper)"
  else
    icon="$("$theme" preview "$id")"
  fi
  [[ "$id" == "$current" ]] && active=$i
  entries+=("${names[$i]}\0icon\x1f$icon")
done

choice=$(printf '%b\n' "${entries[@]}" | rofi -dmenu -i -p "🎨 " \
  -theme ~/.config/rofi/theme.rasi -show-icons -format i \
  -a "$active" -selected-row "$active")

[[ -z "$choice" ]] && exit 0
out="$("$theme" set "${ids[$choice]}" 2>&1)" || notify-send -u critical "Theme" "$out"
