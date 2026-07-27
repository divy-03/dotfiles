#!/bin/bash
# Watches Hyprland window events for Zen private-browsing windows and
# triggers the focus-guard prompt the first time each one appears.

SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
PROMPT_SCRIPT="$HOME/.config/hypr/Scripts/focus-guard-prompt.sh"
PRIVATE_TITLE_MARKER="Zen Browser Private Browsing"

declare -A prompted

socat -U - UNIX-CONNECT:"$SOCKET" | while IFS= read -r line; do
  case "$line" in
    windowtitlev2\>\>*)
      payload="${line#windowtitlev2>>}"
      addr="${payload%%,*}"
      title="${payload#*,}"

      if [[ "$title" == *"$PRIVATE_TITLE_MARKER"* && -z "${prompted[$addr]}" ]]; then
        class=$(hyprctl clients -j | jq -r --arg a "0x$addr" '.[] | select(.address==$a) | .class')
        if [[ "$class" == "zen" ]]; then
          prompted[$addr]=1
          "$PROMPT_SCRIPT" "0x$addr" &
        fi
      fi
      ;;
    closewindow\>\>*)
      addr="${line#closewindow>>}"
      unset 'prompted[$addr]'
      ;;
  esac
done
