#!/bin/bash

set -euo pipefail # Exit on errors and undefined variables.

SETTINGS_PATH_DST="/mnt/c/Users/$USER/AppData/Roaming/Notepad++/config.xml"
SETTINGS_PATH_SRC=$(mktemp)
trap 'rm -f "$SETTINGS_PATH_SRC"' EXIT

# Apply the following settings in order:
# View --> Show Symbol --> Show Space and Tab
# View --> Word Wrap
# Settings --> Preferences --> Margins/Border/Edge --> Uncheck "Display Change History"
# Settings --> Preferences --> New Document --> Format (Line ending) --> Unix (LF)
sed --regexp-extended \
  --expression 's/whiteSpaceShow="hide"/whiteSpaceShow="show"/g' \
  --expression 's/ Wrap="no"/ Wrap="yes"/g' \
  --expression 's/isChangeHistoryEnabled="1"/isChangeHistoryEnabled="0"/g' \
  --expression 's/(<GUIConfig name="NewDocDefaultSettings" format=")[0-9](")/\12\2/g' \
  "$SETTINGS_PATH_DST" > "$SETTINGS_PATH_SRC"

if cmp --silent "$SETTINGS_PATH_SRC" "$SETTINGS_PATH_DST"; then
  echo "The \"$SETTINGS_PATH_DST\" file is already up to date."
  exit
fi

cp "$SETTINGS_PATH_SRC" "$SETTINGS_PATH_DST"
echo "Successfully updated: $SETTINGS_PATH_DST"
