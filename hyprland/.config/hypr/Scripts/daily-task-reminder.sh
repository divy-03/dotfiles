#!/bin/bash
# Nags you about time-tagged tasks in today's Obsidian daily note
# ("- [ ] Task name [ 7 am ]") that are still unchecked past their time.
# Re-checks every REMIND_INTERVAL seconds and keeps notifying until the
# task is checked off or the day rolls over.

DAILY_DIR="/home/divy/Documents/Obsidian Vault/97 Daily"
REMIND_INTERVAL=900 # 15 minutes

while true; do
  today=$(date +%F)
  file="$DAILY_DIR/$today.md"

  if [[ -f "$file" ]]; then
    now_epoch=$(date +%s)

    while IFS= read -r line; do
      if [[ "$line" =~ ^-\ \[\ \]\ (.+)\[[[:space:]]*([0-9]{1,2}(:[0-9]{2})?[[:space:]]*[ap]m)[[:space:]]*\][[:space:]]*$ ]]; then
        task="${BASH_REMATCH[1]}"
        task="${task%"${task##*[![:space:]]}"}"
        time_str="${BASH_REMATCH[2]}"

        sched_epoch=$(date -d "$today $time_str" +%s 2>/dev/null) || continue

        if ((now_epoch >= sched_epoch)); then
          notify-send -u critical -a "Daily Tasks" "Task overdue: $task" "Was due at $time_str"
          sleep 1.5
        fi
      fi
    done <"$file"
  fi

  sleep "$REMIND_INTERVAL"
done
