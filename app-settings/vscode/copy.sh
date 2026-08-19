#!/bin/bash

set -euo pipefail # Exit on errors and undefined variables.

# Get the directory of this script:
# https://stackoverflow.com/questions/59895/getting-the-source-directory-of-a-bash-script-from-within
DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

cp "$DIR/keybindings.json" "/mnt/c/Users/$USER/AppData/Roaming/Code/User/keybindings.json"
cp "$DIR/settings.json" "/mnt/c/Users/$USER/AppData/Roaming/Code/User/settings.json"
