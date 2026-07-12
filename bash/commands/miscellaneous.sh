# ----------------------
# Miscellaneous Commands
# ----------------------

aks() (
  if [[ -z "${REPOSITORIES_DIR:-}" ]]; then
    echo "Error: You can only use this command if your repositories directory is in one of the standard locations." >&2
    exit 1
  fi

  SCRIPT_LOCATION="$REPOSITORIES_DIR/infrastructure/3_Applications/containers/aks-shell/aks-shell.sh"

  if [[ ! -s "$SCRIPT_LOCATION" ]]; then
    echo "Error: The \"$SCRIPT_LOCATION\" file does not exist or is 0 bytes." >&2
    exit 1
  fi

  "$SCRIPT_LOCATION" "$@"
)

# "ah" is short for "Azure DevOps history". Opens the Azure DevOps URL for the "History" tab of the
# corresponding file.
ah() (
  set -euo pipefail # Exit on errors and undefined variables.

  if [[ -z "${1:-}" ]]; then
    echo "Error: The file path is required. Usage: ${FUNCNAME[0]} <file_path>" >&2
    return 1
  fi
  local file_path="$1"

  local repo_root
  repo_root=$(git -C "$(dirname "$file_path")" rev-parse --show-toplevel)

  if command -v cygpath &> /dev/null; then
    file_path=$(cygpath --unix "$file_path")
    repo_root=$(cygpath --unix "$repo_root")
  fi

  local relative_path
  relative_path=$(realpath --relative-to="$repo_root" "$file_path")

  read -r host organization project repository <<< "$(get-git-remote-details "$repo_root")"
  assert-azure-devops-host "$host"

  local azdo_repository_url
  azdo_repository_url=$(get-azure-devops-repository-url "$host" "$organization" "$project" "$repository")

  local main_branch_name
  builtin cd "$repo_root"
  main_branch_name=$(get-main-branch-name)

  # e.g. https://azuredevops.logixhealth.com/LogixHealth/Infrastructure/_git/infrastructure?path=/infrastructure.code-workspace&version=GBmaster&_a=history
  o "$azdo_repository_url?path=/$relative_path&version=GB$main_branch_name&_a=history"
)

# "azl" is short for "az login". We use a custom browser profile to bypass the account picker.
azl() (
  set -euo pipefail # Exit on errors and undefined variables.

  local tmp_dir
  tmp_dir=$(mktemp -d)
  trap 'rm -rf "$tmp_dir"' EXIT

  local browser_path="$tmp_dir/az-login-browser"
  cat > "$browser_path" << 'BROWSER'
#!/usr/bin/env bash
set -euo pipefail

"/opt/az/bin/python3" - "$1" <<'PY'
import os
import subprocess
import sys
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

url = sys.argv[1]
user = os.environ["USER"]
login_hint = f"{user}az@logixhealth.com"
parts = urlsplit(url)
query = [
    (key, value)
    for key, value in parse_qsl(parts.query, keep_blank_values=True)
    if key != "prompt"
]
if not any(key == "login_hint" for key, _ in query):
    query.append(("login_hint", login_hint))
url = urlunsplit((parts.scheme, parts.netloc, parts.path, urlencode(query), parts.fragment))

subprocess.Popen(
    [
        "/mnt/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe",
        f"--user-data-dir=C:\\Users\\{user}\\AppData\\Local\\Microsoft\\Edge\\User Data AzLogin",
        "--profile-directory=Default",
        "--no-first-run",
        url,
    ],
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
)
PY
BROWSER

  chmod +x "$browser_path"
  BROWSER="$browser_path" /usr/bin/az login --subscription LH-DevOps-Dev-001
)

alias azwhoami="az account show --query user.name -o tsv"

# "bwl" is short for "bw login --apikey". (This is the BitWarden CLI.)
alias bwl="bw login --apikey"

canary() (
  set -euo pipefail # Exit on errors and undefined variables.

  assert-in-git-repository

  local repo_root
  repo_root=$(git rev-parse --show-toplevel)

  if [[ -n "$(git status --porcelain)" ]]; then
    echo "Error: The repository is not clean. Commit or stash your changes before applying canary text." >&2
    return 1
  fi

  local readme_path="$repo_root/README.md"
  if [[ ! -f "$readme_path" ]]; then
    echo "Error: The README.md file does not exist at the root of the current git repository." >&2
    return 1
  fi

  echo -e "\nCanary.\n" >> "$readme_path"
  echo "Applied Canary text to: $readme_path"

  git add "$readme_path"
  git commit --message "chore: canary"
  git push
)

# Only create the "cd" alias if the shell is interactive.
if [[ $- == *i* ]]; then
  # We have to use braces instead of parenthesis here.
  cd() {
    if command -v z &> /dev/null; then
      # Use "zoxide" if it is available.
      z "$@" && print-files-and-branches
    else
      builtin cd "$@" && print-files-and-branches
    fi
  }
fi

# "cd.." works on Windows for some reason and is convenient.
cd..() {
  cd ..
}

# "cdg" stands for "change directory git", which will change the working directory to the root of
# the current git repository. If used in a directory that is not part of a Git repository, it will
# throw an error.
cdg() {
  assert-in-git-repository

  local repo_root
  repo_root=$(git rev-parse --show-toplevel)

  cd "$repo_root"
}

if [[ -n "${REPOSITORIES_DIR:-}" ]]; then
  # "cdr" is short for "change directory repositories".
  alias cdr='builtin cd $REPOSITORIES_DIR'

  # Make various "cd" hotkeys for switching to specific personal repositories.
  set-cd-alias configs
  set-cd-alias notes
  set-cd-alias secrets

  # Make various "cd" hotkeys for switching to specific work repositories.
  set-cd-alias allscripts-external
  set-cd-alias database-services
  # "databricks-data" also starts with a "d".
  set-cd-alias infrastructure
  set-cd-alias LogixApplications
fi

# "clip" is a Windows utility that puts input into the clipboard.
alias clip="clip.exe"

# "co" is short for "copilot". (See below.)
alias co="copilot --yolo --no-ask-user"

# Turn off GitHub Copilot CLI prompts.
alias copilot="GITHUB_TOKEN=\${GITHUB_TOKEN_WORK:-\$GITHUB_TOKEN} copilot --yolo --no-ask-user"

# "cl" is short for "claude". (See below.)
alias cl="claude --dangerously-skip-permissions"

# Turn off Claude Code prompts.
alias claude="claude --dangerously-skip-permissions"

# "csf" is short for "CSpell fix", which will invoke "cspell-check-unused-words --fix".
csf() (
  set -euo pipefail # Exit on errors and undefined variables.

  assert-in-git-repository

  local repo_root
  repo_root=$(git rev-parse --show-toplevel)

  builtin cd "$repo_root"
  exec-package cspell-check-unused-words --fix

  if [[ -n "$(git status --porcelain)" ]]; then
    gc "chore: remove unused words from the CSpell configuration file"
  fi
)

decrypt() (
  if ! command -v age &> /dev/null; then
    echo "Error: age is required to get/set secrets. If you are on Windows, you can install it with: winget install --exact --id FiloSottile.age" >&2
    exit 1
  fi

  if [[ -z "${1:-}" ]]; then
    echo "Error: The destination file path is required. Usage: ${FUNCNAME[0]} <path>" >&2
    return 1
  fi
  local file_path="$1"

  local ssh_private_key_path="$HOME/.ssh/id_ed25519"
  if [[ ! -s "$ssh_private_key_path" ]]; then
    echo "Error: The \"$ssh_private_key_path\" file does not exist or is 0 bytes." >&2
    exit 1
  fi

  if [[ -z "${REPOSITORIES_DIR:-}" ]]; then
    echo "Error: You can only use this command if your repositories directory is in one of the standard locations." >&2
    exit 1
  fi

  local secrets_path="$REPOSITORIES_DIR/secrets"
  if [[ ! -d "$secrets_path" ]]; then
    echo "Error: The \"secrets\" repository does not exist." >&2
    exit 1
  fi

  local file_name
  file_name=$(basename "$file_path")
  local age_path="$secrets_path/$file_name.age"

  git -C "$secrets_path" pull --rebase --quiet

  if [[ -f "$file_path" ]]; then
    local tmp_file
    tmp_file=$(mktemp)
    trap 'rm -f "$tmp_file"' EXIT
    age --decrypt --identity "$ssh_private_key_path" --output "$tmp_file" "$age_path"
    if cmp --silent "$file_path" "$tmp_file"; then
      echo "Error: The content of \"$age_path\" is already decrypted in \"$file_path\". Nothing to do." >&2
      exit 1
    fi
  fi

  age --decrypt --identity "$ssh_private_key_path" --output "$file_path" "$age_path"
  echo "Successfully decrypted: $age_path --> $file_path"
)

encrypt() (
  set -euo pipefail # Exit on errors and undefined variables.

  if ! command -v age &> /dev/null; then
    echo "Error: age is required to get/set secrets. If you are on Windows, you can install it with: winget install --exact --id FiloSottile.age" >&2
    exit 1
  fi

  if [[ -z "${1:-}" ]]; then
    echo "Error: The source file path is required. Usage: ${FUNCNAME[0]} <path>" >&2
    return 1
  fi
  local file_path="$1"

  if [[ ! -s "$file_path" ]]; then
    echo "Error: The file path of \"$file_path\" does not exist or is 0 bytes." >&2
    return 1
  fi

  local ssh_public_key_path="$HOME/.ssh/id_ed25519.pub"
  if [[ ! -s "$ssh_public_key_path" ]]; then
    echo "Error: The \"$ssh_public_key_path\" file does not exist or is 0 bytes." >&2
    exit 1
  fi

  if [[ -z "${REPOSITORIES_DIR:-}" ]]; then
    echo "Error: You can only use this command if your repositories directory is in one of the standard locations." >&2
    exit 1
  fi

  local secrets_path="$REPOSITORIES_DIR/secrets"
  if [[ ! -d "$secrets_path" ]]; then
    echo "Error: The \"secrets\" repository does not exist." >&2
    exit 1
  fi

  local file_name
  file_name=$(basename "$file_path")
  local age_path="$secrets_path/$file_name.age"

  git -C "$secrets_path" pull --rebase --quiet

  if [[ -f "$age_path" ]]; then
    local ssh_private_key_path="$HOME/.ssh/id_ed25519"
    if [[ ! -s "$ssh_private_key_path" ]]; then
      echo "Error: The \"$ssh_private_key_path\" file does not exist or is 0 bytes." >&2
      exit 1
    fi

    local tmp_file
    tmp_file=$(mktemp)
    trap 'rm -f "$tmp_file"' EXIT
    age --decrypt --identity "$ssh_private_key_path" --output "$tmp_file" "$age_path"
    if cmp --silent "$file_path" "$tmp_file"; then
      echo "Error: The content of \"$file_path\" is already encrypted in \"$age_path\". Nothing to do." >&2
      exit 1
    fi
  fi

  age --encrypt --recipients-file "$ssh_public_key_path" --output "$age_path" "$file_path"
  git -C "$secrets_path" add --all
  git -C "$secrets_path" commit --message update
  git -C "$secrets_path" push
  echo "Successfully encrypted: $file_path --> $age_path"
)

alias full-path="readlink -f"

# We do not use a subshell because the "source" would not work.
get-env() {
  decrypt "$HOME/.env"
  # shellcheck source=/dev/null
  source "$HOME/.env"
  echo "Loaded new environment variables with: source $HOME/.env"
}

# Turn off Gemini Code Assist prompts.
alias gemini="gemini --yolo"

get-ssh-keys() (
  set -euo pipefail # Exit on errors and undefined variables.

  mkdir -p "$HOME/.ssh"
  bw sync
  # The secret is "id_ed25519.key" instead of "id_ed25519" because otherwise, BitWarden will
  # complain that "More than one result was found".
  bw get notes id_ed25519.key > "$HOME/.ssh/id_ed25519"
  chmod 600 "$HOME/.ssh/id_ed25519"
  bw get notes id_ed25519.pub > "$HOME/.ssh/id_ed25519.pub"
)

# "kb" is short for "kubernetes build".
kb() (
  set -euo pipefail # Exit on errors and undefined variables.

  if [[ -z "${REPOSITORIES_DIR:-}" ]]; then
    echo "Error: You can only use this command if your repositories directory is in one of the standard locations." >&2
    exit 1
  fi

  local kubernetes_path="$REPOSITORIES_DIR/infrastructure/3_Applications/kubernetes"
  if [[ ! -d "$kubernetes_path" ]]; then
    echo "Error: The directory does not exist at: $kubernetes_path" >&2
    exit 1
  fi

  builtin cd "$kubernetes_path"
  bun run build
)

killapp() (
  set -euo pipefail # Exit on errors and undefined variables.

  if is-mac-os; then
    echo "Error: This command is only meant to be used on macOS." >&2
    return 1
  fi

  if [[ -z "${1:-}" ]]; then
    echo "Error: The application name is required. Usage: ${FUNCNAME[0]} <application_name>" >&2
    return 1
  fi
  local application_name="$*"

  osascript -e "quit app \"$application_name\""
)

# A better "ll" alias that shows human-readable file sizes.
# (macOS does not support any of the long-form flags, so we use the short ones instead.)
# - "-a" is short for "--all", which shows hidden files.
# - "-h" is short for "--human-readable", which converts bytes to kilobytes and so on.
# - "-F" is short for "--classify", which displays extra characters to signify the file type.
# - "--color=auto" makes Ubuntu have the same colors that Git Bash for Windows does.
alias ll="ls -a -h -l -F --color=auto"

# Ask an LLM a question from the terminal.
llm() (
  set -euo pipefail # Exit on errors and undefined variables.

  if [[ $# -eq 0 ]]; then
    echo "Error: The prompt is required. Usage: ${FUNCNAME[0]} <prompt>" >&2
    return 1
  fi
  local prompt="$*"

  local system_prompt="You are being asked a question inside of a terminal. Be fairly brief in your response. For example, if you are being asked what the command is for something, format your response as just the command and a 1-2 sentence description."

  get-llm-output "$system_prompt" "$prompt"
)

# "n" is short for "nuke".
alias n="bunx complete-cli@latest nuke"

# "o" is short for "open", to open a URL in a browser.
o() (
  set -euo pipefail # Exit on errors and undefined variables.

  if [[ -z "${1:-}" ]]; then
    echo "Error: URL is required. Usage: ${FUNCNAME[0]} <url>" >&2
    return 1
  fi
  local url="$1"

  if is-wsl; then
    wslview "$url" > /dev/null 2>&1
    return
  fi

  if [[ "$url" == *"logixhealth"* ]] && command -v msedge &> /dev/null; then
    # We remove the output to prevent the "Opening in existing browser session." text from appearing
    # on Linux. (On Linux, if Edge is not yet open, it will launch normally and the terminal will
    # not block like it does for Chrome.)
    msedge "$url" > /dev/null
    return
  fi

  if command -v chrome &> /dev/null; then
    # Starting chrome from the terminal will block, so we have to have special handling.
    if is-ubuntu; then
      # - We remove the output to prevent the "Created TensorFlow Lite XNNPACK delegate for CPU."
      #   output from appearing.
      # - We cannot use aliases with "nohup" so we revert to using "google-chrome".
      nohup google-chrome "$url" > /dev/null 2>&1 &
    else
      # We remove the output to prevent the "Appending output to nohup.out" message.
      nohup chrome "$url" > /dev/null 2>&1 &
    fi
    return
  fi

  # macOS and Linux have the "open" command:
  # https://ss64.com/mac/open.html
  if command -v open &> /dev/null; then
    # We remove the output to prevent the "Opening in existing browser session." output from
    # appearing on Linux.
    open "$url" > /dev/null
    return
  fi

  echo "Git commit URL is at:"
  echo "$url"
)

# "pi" is short for "pipeline info".
pi() (
  set -euo pipefail # Exit on errors and undefined variables.

  if [[ -z "${REPOSITORIES_DIR:-}" ]]; then
    echo "Error: You can only use this command if your repositories directory is in one of the standard locations." >&2
    exit 1
  fi

  local scripts_path="$REPOSITORIES_DIR/infrastructure/0_Global_Library/typescript-scripts"
  if [[ ! -d "$scripts_path" ]]; then
    echo "Error: The directory does not exist at: $scripts_path" >&2
    exit 1
  fi

  builtin cd "$scripts_path"
  bun run get-pipeline-info-from-url "$@" | clip
)

# No global pip command is included on Windows:
# https://peps.python.org/pep-0773/#global-pip-command
if command -v python &> /dev/null && ! command -v pip &> /dev/null; then
  alias pip="python -m pip"
fi

set-claude-settings() (
  set -euo pipefail # Exit on errors and undefined variables.

  local settings_path="$HOME/.claude/settings.json"
  local tmp_file
  tmp_file=$(mktemp)
  trap 'rm -f "$tmp_file"' EXIT

  curl --silent --fail --show-error --location https://raw.githubusercontent.com/Zamiell/configs/refs/heads/main/claude/settings.json > "$tmp_file"

  if [[ -f "$settings_path" ]] && cmp --silent "$settings_path" "$tmp_file"; then
    echo "Error: The content of \"$settings_path\" is already up to date. Nothing to do." >&2
    exit 1
  fi

  mkdir -p "$HOME/.claude"
  cp "$tmp_file" "$settings_path"
  echo "Successfully updated: $settings_path"

  # Validate that the sound file is in place.
  local sound_path="$HOME/turn-blind1.mp3" # This must match what is in "settings.json".
  if [[ ! -s "$sound_path" ]]; then
    echo "Error: The sound file does not exist: $sound_path" >&2
    exit 1
  fi
)

alias set-env='encrypt "$HOME/.env"'

# Alias "start" to "open" on macOS and "xdg-open" on Linux. ("start" is a Windows-only command to
# open explorer at the given path.)
start() (
  set -euo pipefail # Exit on errors and undefined variables.

  if is-wsl; then
    wslview "$@"
  elif is-git-bash; then
    # We must use "command" to invoke "start" to prevent an infinite loop.
    command start "$@"
  elif is-mac-os; then
    open "$@"
  else
    xdg-open "$@"
  fi
)

# "tpr" is short for "test-pr".
tpr() (
  set -euo pipefail # Exit on errors and undefined variables.

  assert-in-git-repository

  read -r _host _organization _project repository_name <<< "$(get-git-remote-details)"

  local pull_request_id
  pull_request_id=$(get-azure-devops-active-pull-request-id-for-current-branch)

  if [[ -z "${REPOSITORIES_DIR:-}" ]]; then
    echo "Error: You can only use this command if your repositories directory is in one of the standard locations." >&2
    exit 1
  fi

  local logix_path="$REPOSITORIES_DIR/infrastructure/3_Applications/containers/logix-ci-cd-tasks"
  if [[ ! -d "$logix_path" ]]; then
    echo "Error: The directory does not exist at: $logix_path" >&2
    exit 1
  fi

  builtin cd "$logix_path"
  bun run test-pr "$@" "$repository_name" "$pull_request_id"
)

# We disable the mouse because it prevents highlighting text and pressing enter to copy it to the
# clipboard.
alias vim="vim -c 'set mouse='"

# Kills and restarts Palo Alto GlobalProtect.
vpn() (
  set -euo pipefail # Exit on errors and undefined variables.

  if ! command -v powershell.exe > /dev/null; then
    echo "Error: powershell.exe is not available. WSL Windows interop must be enabled." >&2
    return 1
  fi

  # shellcheck disable=SC2016
  powershell.exe -NoProfile -ExecutionPolicy Bypass -Command '
    $ErrorActionPreference = "Stop"

    $panGpaPath = Join-Path $env:ProgramFiles "Palo Alto Networks\GlobalProtect\PanGPA.exe"
    if (-not (Test-Path -LiteralPath $panGpaPath)) {
      throw "PanGPA.exe was not found in the Program Files directory."
    }

    Get-Process -Name PanGPA -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 2
    Start-Process -FilePath $panGpaPath
  '
)
