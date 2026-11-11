#!/bin/bash

set -euo pipefail # Exit on errors and undefined variables.

# Get the directory of this script:
# https://stackoverflow.com/questions/59895/getting-the-source-directory-of-a-bash-script-from-within
DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

SETTINGS_PATH_SRC="$DIR/settings.json"
WINDOWS_CLAUDE_DIR="/mnt/c/Users/$USER/.claude"

copy_settings() {
  local settings_path_dst="$1"

  if [[ -f "$settings_path_dst" ]] && cmp --silent "$SETTINGS_PATH_SRC" "$settings_path_dst"; then
    echo "The \"$settings_path_dst\" file is already up to date."
    return
  fi

  cp "$SETTINGS_PATH_SRC" "$settings_path_dst"
  echo "Successfully updated: $settings_path_dst"
}

copy_settings "$HOME/.claude/settings.json"

if [[ -d "$WINDOWS_CLAUDE_DIR" ]]; then
  copy_settings "$WINDOWS_CLAUDE_DIR/settings.json"
fi
