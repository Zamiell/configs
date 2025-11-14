#!/bin/bash

set -euo pipefail # Exit on errors and undefined variables.

# Get the directory of this script:
# https://stackoverflow.com/questions/59895/getting-the-source-directory-of-a-bash-script-from-within
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd)"

# Get the name of this repository:
# https://stackoverflow.com/questions/23162299/how-to-get-the-last-part-of-dirname-in-bash/23162553
REPO="$(basename "$DIR")"

cd "$DIR"

bunx prettier --log-level=warn --check .
shellcheck ./*.sh ./bash/.bash_profile_remote
bunx cspell --no-progress --no-summary
bunx cspell-check-unused-words

echo "Successfully linted $REPO."
