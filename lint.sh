#!/bin/bash

set -euo pipefail # Exit on errors and undefined variables.

# Get the directory of this script:
# https://stackoverflow.com/questions/59895/getting-the-source-directory-of-a-bash-script-from-within
DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

# Get the name of this repository:
# https://stackoverflow.com/questions/23162299/how-to-get-the-last-part-of-dirname-in-bash/23162553
REPO=$(basename "$DIR")

cd "$DIR"

bunx prettier --log-level=warn --check .
find . \( -name "node_modules" -o -name ".venv" \) -prune -o -type f -name "*.sh" -exec shellcheck {} +
shellcheck ./bash/.bash_profile_remote # The main config file does not have a ".sh" extension.
bunx cspell --no-progress --no-summary
bunx cspell-check-unused-words

echo "Successfully linted $REPO."
