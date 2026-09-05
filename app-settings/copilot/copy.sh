#!/bin/bash

set -euo pipefail # Exit on errors and undefined variables.

# Get the directory of this script:
# https://stackoverflow.com/questions/59895/getting-the-source-directory-of-a-bash-script-from-within
DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

SETTINGS_PATH_SRC="$DIR/settings.json"
SETTINGS_PATH_DST="$HOME/.copilot/settings.json"

# First, copy the main settings file.
mkdir -p "$(dirname "$SETTINGS_PATH_DST")"

if [[ -f "$SETTINGS_PATH_DST" ]] && cmp --silent "$SETTINGS_PATH_SRC" "$SETTINGS_PATH_DST"; then
  echo "The \"$SETTINGS_PATH_DST\" file is already up to date."
else
  cp "$SETTINGS_PATH_SRC" "$SETTINGS_PATH_DST"
  echo "Successfully updated: $SETTINGS_PATH_DST"
fi

# Second, handle the hooks. First, validate that the sound file exists.
SOUND_PATH="/mnt/c/Users/$USER/turn-blind1.mp3"
if [[ ! -f "$SOUND_PATH" ]]; then
  echo "Error: The sound file does not exist: $SOUND_PATH" >&2
  exit 1
fi

HOOK_PATH_SRC="$DIR/hooks/sound.json"
HOOK_PATH_DST="$HOME/.copilot/hooks/sound.json"

TEMP_DIR=$(mktemp --directory)
trap 'rm -rf -- "$TEMP_DIR"' EXIT

HOOK_PATH_TEMP="$TEMP_DIR/sound.json"
cp "$HOOK_PATH_SRC" "$HOOK_PATH_TEMP"

WINDOWS_SOUND_PATH=$(wslpath -m "$SOUND_PATH")
sed --in-place "s|__MP3_PATH__|$WINDOWS_SOUND_PATH|g" "$HOOK_PATH_TEMP"

if [[ -f "$HOOK_PATH_DST" ]] && cmp --silent "$HOOK_PATH_TEMP" "$HOOK_PATH_DST"; then
  echo "The \"$HOOK_PATH_DST\" file is already up to date."
else
  mkdir -p "$(dirname "$HOOK_PATH_DST")"
  cp "$HOOK_PATH_TEMP" "$HOOK_PATH_DST"
  echo "Successfully updated: $HOOK_PATH_DST"
fi

TIMING_HOOK_PATH_SRC="$DIR/hooks/prompt-timing.json"
TIMING_HOOK_PATH_DST="$HOME/.copilot/hooks/prompt-timing.json"

if [[ -f "$TIMING_HOOK_PATH_DST" ]] && cmp --silent "$TIMING_HOOK_PATH_SRC" "$TIMING_HOOK_PATH_DST"; then
  echo "The \"$TIMING_HOOK_PATH_DST\" file is already up to date."
else
  cp "$TIMING_HOOK_PATH_SRC" "$TIMING_HOOK_PATH_DST"
  echo "Successfully updated: $TIMING_HOOK_PATH_DST"
fi

TIMING_SCRIPT_PATH_SRC="$DIR/hooks/prompt-timing.sh"
TIMING_SCRIPT_PATH_DST="$HOME/.copilot/hooks/prompt-timing.sh"

if [[ -x "$TIMING_SCRIPT_PATH_DST" ]] && cmp --silent "$TIMING_SCRIPT_PATH_SRC" "$TIMING_SCRIPT_PATH_DST"; then
  echo "The \"$TIMING_SCRIPT_PATH_DST\" file is already up to date."
else
  install --mode=755 "$TIMING_SCRIPT_PATH_SRC" "$TIMING_SCRIPT_PATH_DST"
  echo "Successfully updated: $TIMING_SCRIPT_PATH_DST"
fi

SKILL_PATH_SRC="$DIR/skills/pr2/SKILL.md"
SKILL_PATH_DST="$HOME/.copilot/skills/pr2/SKILL.md"

if [[ -f "$SKILL_PATH_DST" ]] && cmp --silent "$SKILL_PATH_SRC" "$SKILL_PATH_DST"; then
  echo "The \"$SKILL_PATH_DST\" file is already up to date."
else
  mkdir -p "$(dirname "$SKILL_PATH_DST")"
  cp "$SKILL_PATH_SRC" "$SKILL_PATH_DST"
  echo "Successfully updated: $SKILL_PATH_DST"
fi
