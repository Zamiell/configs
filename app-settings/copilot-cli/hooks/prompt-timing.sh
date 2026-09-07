#!/bin/bash

set -euo pipefail # Exit on errors and undefined variables.

INPUT=$(cat)
SESSION_ID=$(jq --raw-output ".sessionId" <<< "$INPUT")
TIMESTAMP=$(jq --raw-output ".timestamp" <<< "$INPUT")

if [[ ! "$SESSION_ID" =~ ^[[:alnum:]-]+$ ]] || [[ ! "$TIMESTAMP" =~ ^[0-9]+$ ]]; then
  echo "Invalid Copilot hook input." >&2
  exit 1
fi

STATE_DIRECTORY="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/copilot-prompt-timing-$UID"
STATE_PATH="$STATE_DIRECTORY/$SESSION_ID"

case "$1" in
  start)
    install --directory --mode=700 "$STATE_DIRECTORY"
    printf "%s\n" "$TIMESTAMP" > "$STATE_PATH"
    ;;
  stop)
    if [[ -f "$STATE_PATH" ]]; then
      START_TIMESTAMP=$(< "$STATE_PATH")
      ELAPSED_MILLISECONDS=$((TIMESTAMP - START_TIMESTAMP))
      ELAPSED_SECONDS=$((ELAPSED_MILLISECONDS / 1000))
      COMPLETED_AT=$(date --date="@$(("$TIMESTAMP" / 1000))" --iso-8601=seconds)

      jq --compact-output --null-input \
        --arg message "Prompt completed at $COMPLETED_AT after ${ELAPSED_SECONDS}s" \
        '{type: "progress", message: $message}'

      rm --force "$STATE_PATH"
    fi

    printf "{}\n"
    ;;
  *)
    echo "Usage: prompt-timing.sh <start|stop>" >&2
    exit 1
    ;;
esac
