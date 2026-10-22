#!/bin/bash

# Close Notepad++ before running this script so it does not overwrite these changes on exit.

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
else
  cp "$SETTINGS_PATH_SRC" "$SETTINGS_PATH_DST"
  echo "Successfully updated: $SETTINGS_PATH_DST"
fi

SETTINGS_PATH_DST="/mnt/c/Users/$USER/AppData/Roaming/Notepad++/shortcuts.xml"

# Settings --> Shortcut Mapper --> Macros --> Trim Trailing Space and Save --> Ctrl+S
# Settings --> Shortcut Mapper --> Main menu --> Save --> Alt+Shift+S
python3 - "$SETTINGS_PATH_DST" > "$SETTINGS_PATH_SRC" << 'PY'
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

original = Path(sys.argv[1]).read_bytes()
parser = ET.XMLParser(target=ET.TreeBuilder(insert_comments=True))
root = ET.fromstring(original, parser=parser)
macro = root.find("./Macros/Macro[@name='Trim Trailing Space and Save']")
if macro is None:
    sys.exit("Error: The Trim Trailing Space and Save macro is missing from shortcuts.xml.")

commands = root.find("InternalCommands")
if commands is None:
    commands = ET.SubElement(root, "InternalCommands")
save = commands.find("./Shortcut[@id='41006']")
changed = save is None
if save is None:
    save = ET.SubElement(commands, "Shortcut", id="41006")

for element, attributes in (
    (macro, {"Ctrl": "yes", "Alt": "no", "Shift": "no", "Key": "83"}),
    (save, {"Ctrl": "no", "Alt": "yes", "Shift": "yes", "Key": "83"}),
):
    for name, value in attributes.items():
        if element.get(name) != value:
            element.set(name, value)
            changed = True

if changed:
    sys.stdout.buffer.write(ET.tostring(root, encoding="utf-8", xml_declaration=True))
else:
    sys.stdout.buffer.write(original)
PY

if cmp --silent "$SETTINGS_PATH_SRC" "$SETTINGS_PATH_DST"; then
  echo "The \"$SETTINGS_PATH_DST\" file is already up to date."
  exit
fi

cp "$SETTINGS_PATH_SRC" "$SETTINGS_PATH_DST"
echo "Successfully updated: $SETTINGS_PATH_DST"
