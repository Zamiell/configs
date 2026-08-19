#!/bin/bash

set -euo pipefail # Exit on errors and undefined variables.

# Get the directory of this script:
# https://stackoverflow.com/questions/59895/getting-the-source-directory-of-a-bash-script-from-within
DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

SETTINGS_PATH="$HOME/.claude/settings.json"

if [[ -f "$SETTINGS_PATH" ]] && cmp --silent "$DIR/settings.json" "$SETTINGS_PATH"; then
  echo "The Claude settings are already up to date. Nothing needs to be updated."
  exit 0
fi

cp "$DIR/settings.json" "$SETTINGS_PATH"
echo "Successfully updated: $SETTINGS_PATH"
