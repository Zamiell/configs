#!/bin/bash

set -euo pipefail # Exit on errors and undefined variables.

# Get the directory of this script:
# https://stackoverflow.com/questions/59895/getting-the-source-directory-of-a-bash-script-from-within
DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

ZED_CONFIG_DIR="/mnt/c/Users/$USER/AppData/Roaming/Zed"
UPDATED=false

for FILE_NAME in keymap.json settings.json; do
  CONFIG_PATH="$ZED_CONFIG_DIR/$FILE_NAME"

  if [[ -f "$CONFIG_PATH" ]] && cmp --silent "$DIR/$FILE_NAME" "$CONFIG_PATH"; then
    continue
  fi

  cp "$DIR/$FILE_NAME" "$CONFIG_PATH"
  echo "Successfully updated: $CONFIG_PATH"
  UPDATED=true
done

if [[ "$UPDATED" == false ]]; then
  echo "The Zed configuration files are already up to date."
fi
