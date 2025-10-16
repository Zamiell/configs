#!/bin/bash

set -euo pipefail # Exit on errors and undefined variables.

# ----------
# Validation
# ----------

# Ensure OS compatibility.
# (Otherwise, some of the installation URLs below will have to be changed.)
source /etc/os-release
if [[ "$UBUNTU_CODENAME" != "noble" ]]; then
  echo "Error: This script is meant to be run on Linux Mint that is based on Ubuntu noble (24)." >&2
  exit
fi

# -----------
# Bash Config
# -----------

if ! command -v curl &> /dev/null; then
  sudo apt update
  sudo apt install curl -y
fi

if ! grep --quiet "# https://github.com/Zamiell/configs/blob/main/bash/.bash_profile" ~/.bashrc; then
  echo >> ~/.bashrc
  echo "# https://github.com/Zamiell/configs/blob/main/bash/.bash_profile" >> ~/.bashrc
  curl --silent "https://raw.githubusercontent.com/Zamiell/configs/refs/heads/main/bash/.bash_profile" >> ~/.bashrc
fi

# ---------------
# Configure Linux
# ---------------

# Show hidden files in Nemo (explorer).
gsettings set org.nemo.preferences show-hidden-files true

# TODO: Flag up to maximize

# -----------------------------
# Bindings for existing hotkeys
# -----------------------------

# Flag + L --> Lock screen
gsettings set org.cinnamon.desktop.keybindings.media-keys screensaver "['<Super>l']"

# --------------
# Custom hotkeys
# --------------

# Remove all existing hotkeys.
dconf reset -f /org/cinnamon/desktop/keybindings/custom-keybindings/

# A counter to automatically number the hotkeys, starting at 0.
HOTKEY_LIST=()
HOTKEY_INDEX=0

# Creates a custom hotkey by setting its name, command, and binding.
# Arguments:
#   $1: The numeric index (e.g., 0, 1, 2)
#   $2: The descriptive name (e.g., 'Launch/Focus Terminal')
#   $3: The command to execute (e.g., 'bash -c "wmctrl..."')
#   $4: The keybinding (e.g., "['<Control>5']")
create_hotkey() {
  local name="$1"
  local command="$2"
  local binding="$3"
  local base_path="/org/cinnamon/desktop/keybindings/custom-keybindings/custom$HOTKEY_INDEX"

  # Write the new configuration
  dconf write "$base_path/name" "'$name'"
  dconf write "$base_path/command" "'$command'"
  dconf write "$base_path/binding" "$binding"

  # Add this hotkey's ID to our master list for activation
  HOTKEY_LIST+=("custom$HOTKEY_INDEX")

  ((++HOTKEY_INDEX))
}

create_hotkey \
  "Launch/Focus Terminal" \
  'bash -c "wmctrl -x -a gnome-terminal-server.Gnome-terminal || gnome-terminal"' \
  "['<Control>5']"

create_hotkey \
  "Launch/Focus Visual Studio Code" \
  'bash -c "wmctrl -x -a Code || code"' \
  "['<Control>6']"

create_hotkey \
  "Launch/Focus Google Chrome" \
  'bash -c "wmctrl -x -a Google-chrome || google-chrome"' \
  "['<Control>9']"

create_hotkey \
  "Launch/Focus Microsoft Edge" \
  'bash -c "wmctrl -x -a Edge || msedge"' \
  "['<Control>grave']"

create_hotkey \
  "Launch/Focus Obsidian" \
  'bash -c "wmctrl -x -a obsidian || obsidian"' \
  "['<Control><Shift>grave']"

create_hotkey \
  "Launch/Focus Firefox" \
  'bash -c "wmctrl -x -a firefox || firefox"' \
  "['<Control><Shift><Alt>grave']"

# Activate the hotkeys.
formatted_list=$(printf "'%s'," "${HOTKEY_LIST[@]}")
formatted_list="[${formatted_list%,}]"
dconf write /org/cinnamon/desktop/keybindings/custom-list "$formatted_list"

# ------------
# Certificates
# ------------

if ! command -v certutil &> /dev/null; then
  sudo apt update
  sudo apt install libnss3-tools -y
fi

LOGIXHEALTH_CERT_NAME="BEDROOTCA001"
COMPANY_CERT_PATH="/usr/local/share/ca-certificates/$LOGIXHEALTH_CERT_NAME.crt"
if [[ ! -f "$COMPANY_CERT_PATH" ]]; then
  echo "Error: The LogixHealth certificate does not exist at: $COMPANY_CERT_PATH" >&2
  exit
fi

# Make Google Chrome trust the LogixHealth certificate.
# (The first line is necessary to check to see if it already exists.)
certutil -d "sql:$HOME/.pki/nssdb" -L -n "$LOGIXHEALTH_CERT_NAME" > /dev/null 2>&1 \
  || certutil -d "sql:$HOME/.pki/nssdb" -A -t "C,," -n "$LOGIXHEALTH_CERT_NAME" -i "$COMPANY_CERT_PATH"

# Make Firefox trust the LogixHealth certificate.
if [[ ! -d "$HOME/.mozilla" ]]; then
  echo "Error: The \".mozilla\" directory does not exist. Open Firefox at least one time and then run this script again." >&2
  exit
fi
FIREFOX_CERTIFICATE_DATABASE_PATH=$(find "$HOME/.mozilla/firefox/" -maxdepth 2 -name "cert9.db" -print -quit | xargs dirname 2> /dev/null)
if [[ -z "$FIREFOX_CERTIFICATE_DATABASE_PATH" ]]; then
  echo "Error: Failed to find the Firefox certificate store inside of the \".mozilla\" directory." >&2
  exit
fi
certutil -d "sql:$FIREFOX_CERTIFICATE_DATABASE_PATH" -L -n "$LOGIXHEALTH_CERT_NAME" > /dev/null 2>&1 \
  || certutil -d "sql:$FIREFOX_CERTIFICATE_DATABASE_PATH" -A -t "C,," -n "$LOGIXHEALTH_CERT_NAME" -i "$COMPANY_CERT_PATH"

# (Microsoft Edge automatically uses the system's certificate store.)

# --------------
# Install Intune
# --------------

# From:
# https://github.com/MicrosoftDocs/memdocs/blob/main/intune/intune-service/user-help/microsoft-intune-app-linux.md

if [ ! -f "/usr/share/keyrings/microsoft.gpg" ]; then
  curl --silent "https://packages.microsoft.com/keys/microsoft.asc" | gpg --dearmor > microsoft.gpg
  sudo install -o root -g root -m 644 microsoft.gpg /usr/share/keyrings/
  rm microsoft.gpg
fi

if ! grep -q "packages.microsoft.com" /etc/apt/sources.list.d/*.list; then
  sudo sh -c 'echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/ubuntu/24.04/prod noble main" >> /etc/apt/sources.list.d/microsoft-ubuntu-noble-prod.list'
fi

if ! dpkg -s intune-portal &> /dev/null; then
  sudo apt update
  sudo apt install intune-portal -y
fi

# -----------
# Install Bun
# -----------

if ! command -v unzip &> /dev/null; then
  sudo apt update
  sudo apt install unzip -y
fi

if ! command -v bun &> /dev/null; then
  curl --silent --fail --show-error --location "https://bun.com/install" | bash
fi

# ----------------
# Install Obsidian
# ----------------

# curl --silent --fail --show-error --location "https://github.com/obsidianmd/obsidian-releases/releases/download/v1.9.14/Obsidian-1.9.14.AppImage" --remote-name
# TODO
