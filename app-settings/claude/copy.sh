#!/bin/bash

set -euo pipefail # Exit on errors and undefined variables.

# Get the directory of this script:
# https://stackoverflow.com/questions/59895/getting-the-source-directory-of-a-bash-script-from-within
DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

SETTINGS_PATH_SRC="$DIR/settings.json"
SETTINGS_PATH_DST="$HOME/.claude/settings.json"

if [[ -f "$SETTINGS_PATH_DST" ]] && cmp --silent "$SETTINGS_PATH_SRC" "$SETTINGS_PATH_DST"; then
  echo "The \"$SETTINGS_PATH_DST\" file is already up to date."
  exit
fi

cp "$SETTINGS_PATH_SRC" "$SETTINGS_PATH_DST"
echo "Successfully updated: $SETTINGS_PATH_DST"
