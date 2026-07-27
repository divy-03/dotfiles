#!/bin/bash
# Full-screen friction prompt shown when a Zen private window opens.
# Logs every trigger, escalates strictness after repeated use in a day,
# and auto-closes the window if the user doesn't respond in time.

ADDR="$1"
LOG_DIR="$HOME/.local/share/focus"
LOG_FILE="$LOG_DIR/history.log"
THEME="$HOME/.config/rofi/focus-guard.rasi"

mkdir -p "$LOG_DIR"

today=$(date +%F)
yesterday=$(date -d "yesterday" +%F)

today_count=$(grep -c "^$today .*opened" "$LOG_FILE" 2>/dev/null)
today_count=${today_count:-0}
yesterday_count=$(grep -c "^$yesterday .*opened" "$LOG_FILE" 2>/dev/null)
yesterday_count=${yesterday_count:-0}
count=$((today_count + 1))

echo "$(date '+%F %T')  opened  count=$count" >>"$LOG_FILE"

if ((count >= 5)); then
  timeout_s=8
  header="Private window #$count today. Really?"
else
  timeout_s=20
  header="Why are you opening this?"
fi

mesg="$header"$'\n'"Today: $count   Yesterday: $yesterday_count"

selection=$(printf '1. Work / Development\n2. Banking / Personal\n3. Testing a website\n4. I'\''m procrastinating\n' |
  timeout "${timeout_s}s" rofi -dmenu -p "focus-guard" -mesg "$mesg" -theme "$THEME")

close_window() {
  hyprctl dispatch closewindow address:"$ADDR" >/dev/null
}

case "$selection" in
1.* | 2.* | 3.*)
  echo "$(date '+%F %T')  reason=$selection" >>"$LOG_FILE"
  ;;
4.*)
  confirm=$(printf 'Yes, close it\nNo, continue anyway\n' |
    timeout "${timeout_s}s" rofi -dmenu -p "focus-guard" \
      -mesg "You told yourself it's procrastination."$'\n'"Close the window?" -theme "$THEME")
  if [[ "$confirm" == "Yes"* ]]; then
    echo "$(date '+%F %T')  closed-procrastination-confirmed" >>"$LOG_FILE"
    close_window
  else
    echo "$(date '+%F %T')  continued-after-procrastination-flag" >>"$LOG_FILE"
  fi
  ;;
*)
  echo "$(date '+%F %T')  timeout-autoclosed" >>"$LOG_FILE"
  close_window
  ;;
esac
