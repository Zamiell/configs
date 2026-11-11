#!/bin/bash

set -euo pipefail # Exit on errors and undefined variables.

DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
# shellcheck source=../../../bash/commands/say.sh
source "$DIR/say.sh"

SESSION_ID=$(jq --exit-status --raw-output '.sessionId | select(type == "string")')
if [[ ! "$SESSION_ID" =~ ^[[:alnum:]-]+$ ]]; then
  echo "Error: Invalid Copilot session ID." >&2
  exit 1
fi

SESSION_NAME=$(
  python3 - "${COPILOT_HOME:-$HOME/.copilot}/session-state/$SESSION_ID/workspace.yaml" << 'PY'
import sys

import yaml

with open(sys.argv[1], encoding="utf-8") as workspace_file:
    workspace = yaml.load(workspace_file, Loader=yaml.BaseLoader)

if not isinstance(workspace, dict):
    sys.exit("Error: Invalid Copilot workspace metadata.")

name = workspace.get("name")
if not isinstance(name, str) or not name.strip():
    sys.exit("Error: Copilot session name is missing or empty.")

print(name, end="")
PY
)

STATE_DIRECTORY="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/copilot-speech-$UID"
install --directory --mode=700 "$STATE_DIRECTORY"
exec 9> "$STATE_DIRECTORY/sound.lock"
flock --exclusive 9
say "session $SESSION_NAME"
