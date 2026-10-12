#!/usr/bin/env bash
# Toggle the built-in laptop keyboard. The external keyboard (CX 2.4G / kreo) is untouched.
# Refuses to disable it unless the external keyboard is connected, so you can't lock yourself out.

INTERNAL="at-translated-set-2-keyboard"
EXTERNAL="cx-2.4g-wireless-receiver-keyboard"
STATE="${XDG_RUNTIME_DIR:-/tmp}/laptop-keyboard-disabled"

notify() { notify-send -t 2000 -h string:x-canonical-private-synchronous:laptop-kb "Laptop keyboard" "$1"; }

if [[ -e "$STATE" ]]; then
    hyprctl keyword "device[$INTERNAL]:enabled" true >/dev/null
    rm -f "$STATE"
    notify "Enabled"
else
    if ! hyprctl devices -j | jq -e --arg n "$EXTERNAL" '.keyboards[] | select(.name == $n)' >/dev/null; then
        notify "External keyboard not found, not disabling"
        exit 1
    fi
    hyprctl keyword "device[$INTERNAL]:enabled" false >/dev/null
    touch "$STATE"
    notify "Disabled"
fi
