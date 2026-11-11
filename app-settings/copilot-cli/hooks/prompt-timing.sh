#!/bin/bash

set -euo pipefail # Exit on errors and undefined variables.

INPUT=$(cat)
if [[ "$1" == "display" ]]; then
  SESSION_ID=$(jq --raw-output ".session_id" <<< "$INPUT")
  TIMESTAMP=$(date +%s%3N)
else
  SESSION_ID=$(jq --raw-output ".sessionId" <<< "$INPUT")
  TIMESTAMP=$(jq --raw-output ".timestamp" <<< "$INPUT")
fi

if [[ ! "$SESSION_ID" =~ ^[[:alnum:]-]+$ ]] || [[ ! "$TIMESTAMP" =~ ^[0-9]+$ ]]; then
  echo "Invalid Copilot timing input." >&2
  exit 1
fi

STATE_DIRECTORY="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/copilot-prompt-timing-$UID"
STATE_PATH="$STATE_DIRECTORY/$SESSION_ID"

case "$1" in
  start)
    install --directory --mode=700 "$STATE_DIRECTORY"
    printf "%s\n" "$TIMESTAMP" > "$STATE_PATH"
    ;;
  stop | display)
    if [[ -f "$STATE_PATH" ]]; then
      START_TIMESTAMP=$(< "$STATE_PATH")
      ELAPSED_MILLISECONDS=$((TIMESTAMP - START_TIMESTAMP))
      ELAPSED_SECONDS=$((ELAPSED_MILLISECONDS / 1000))
      ELAPSED_MINUTES=$((ELAPSED_SECONDS / 60))
      REMAINING_SECONDS=$((ELAPSED_SECONDS % 60))

      if [[ "$1" == "display" ]]; then
        printf "Prompt: %dm %02ds\n" "$ELAPSED_MINUTES" "$REMAINING_SECONDS"
        exit 0
      fi

      COMPLETED_AT=$(date --date="@$(("$TIMESTAMP" / 1000))" +"%-I:%M %p %Z on %b %-d, %Y")

      jq --compact-output --null-input \
        --arg message "Prompt completed at $COMPLETED_AT after ${ELAPSED_MINUTES}m ${REMAINING_SECONDS}s" \
        '{type: "progress", message: $message}'

      rm --force "$STATE_PATH"
    fi

    if [[ "$1" == "stop" ]]; then
      printf "{}\n"
    fi
    ;;
  *)
    echo "Usage: prompt-timing.sh <start|stop|display>" >&2
    exit 1
    ;;
esac
