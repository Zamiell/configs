#!/bin/bash

set -euo pipefail # Exit on errors and undefined variables.

# Get the directory of this script:
# https://stackoverflow.com/questions/59895/getting-the-source-directory-of-a-bash-script-from-within
DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

# First, copy the main settings file.
cp "$DIR/settings.json" "$HOME/.copilot/settings.json"

# Second, handle the hooks. First, validate that the mp3 file exists.
MP3_PATH="/mnt/c/Users/$USER/turn-blind1.mp3"
if [[ ! -f "$MP3_PATH" ]]; then
  echo "Error: The sound file does not exist: $MP3_PATH" >&2
  exit 1
fi

HOOKS_DIR="$HOME/.copilot/hooks"
mkdir -p "$HOOKS_DIR"
cp -r "$DIR/hooks/." "$HOOKS_DIR"
WINDOWS_MP3_PATH=$(wslpath -m "$MP3_PATH")
sed --in-place "s|__MP3_PATH__|$WINDOWS_MP3_PATH|g" "$HOOKS_DIR/sound.json"
