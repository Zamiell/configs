#!/bin/bash

# This script sets up a new Ubuntu Server to have all of the configuration and software that I need.

set -euo pipefail # Exit on errors and undefined variables.
set -x            # Echo commands for easier troubleshooting.

# Constants
FULL_NAME="James Nesta"
PERSONAL_EMAIL="j.nesta@gmail.com"
WORK_EMAIL="jnesta@logixhealth.com"
GITHUB_EMAIL="5511220+Zamiell@users.noreply.github.com"
GITHUB_USERNAME="Zamiell"

# Get the directory of this script:
# https://stackoverflow.com/questions/59895/getting-the-source-directory-of-a-bash-script-from-within
DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

# ----------
# Validation
# ----------

if [[ $EUID -eq 0 ]]; then
  echo "Error: This script cannot be run as root." >&2
  exit 1
fi

# By default, Ubuntu server does not have the ability to connect to a WiFi network because it needs
# the "wpasupplicant" package. (Putting this on the installation media is non-trivial because it
# needs to match the existing system and would quickly get out of date.) Thus, we require a wired
# connection.
if ! curl --silent --fail --location https://www.google.com &> /dev/null; then
  echo "Error: You must have an internet connection to run this script."
  exit 1
fi

# ----
# Main
# ----

# Patch the OS.
sudo apt update
sudo apt upgrade --yes

# Install SSH.
# https://documentation.ubuntu.com/server/how-to/security/openssh-server/index.html
if ! dpkg --status openssh-server &> /dev/null; then
  sudo apt install openssh-server --yes
  sudo systemctl enable ssh
  sudo systemctl start ssh
fi

# Disable the message of the day.
touch "$HOME/.hushlogin"

# Install the BitWarden CLI.
# https://bitwarden.com/help/cli/#tab-snap-bI3gMs3A3z4pl0fwvRie9
if ! command -v bw &> /dev/null; then
  sudo snap install bw
fi

# Login to BitWarden. (This command will prompt the user for the master password.)
if [[ -z "${BW_SESSION:-}" ]]; then
  BITWARDEN_PASSWORD_ARG=()
  if [[ -f "$HOME/bitwarden_password" ]]; then
    BITWARDEN_PASSWORD_ARG=(--passwordfile "$HOME/bitwarden_password")
  fi

  if bw login --check &> /dev/null; then
    BW_SESSION=$(bw unlock --raw "${BITWARDEN_PASSWORD_ARG[@]}")
  else
    BW_SESSION=$(bw login "$PERSONAL_EMAIL" --raw "${BITWARDEN_PASSWORD_ARG[@]}")
  fi

  if [[ -z "$BW_SESSION" ]]; then
    echo "Error: Failed to get the BitWarden session key." >&2
    exit 1
  fi
fi

# Set up environment variables.
ENV_PATH="$HOME/.env"
if [[ ! -s "$ENV_PATH" ]]; then
  bw get notes .env --session "$BW_SESSION" > "$ENV_PATH"
  echo >> "$ENV_PATH"
fi
# shellcheck source=/dev/null
source "$ENV_PATH"

# Set up SSH keys.
mkdir --parents "$HOME/.ssh"
PRIVATE_KEY_PATH="$HOME/.ssh/id_rsa"
if [[ ! -s "$PRIVATE_KEY_PATH" ]]; then
  bw get notes ssh-private-key --session "$BW_SESSION" > "$PRIVATE_KEY_PATH"
  echo >> "$PRIVATE_KEY_PATH"
  chmod 600 "$PRIVATE_KEY_PATH"
fi
PUBLIC_KEY_PATH="$HOME/.ssh/id_rsa.pub"
if [[ ! -s "$PUBLIC_KEY_PATH" ]]; then
  bw get notes ssh-public-key --session "$BW_SESSION" > "$PUBLIC_KEY_PATH"
  echo >> "$PUBLIC_KEY_PATH"
fi

# Connect to WiFi.
sudo apt install wpasupplicant --yes
NETPLAN_FILE_NAME="99-wifi.yaml"
NETPLAN_FILE_PATH="/etc/netplan/$NETPLAN_FILE_NAME"
if [[ ! -s "$NETPLAN_FILE_PATH" ]]; then
  sudo cp "$DIR/etc/netplan/$NETPLAN_FILE_NAME" "$NETPLAN_FILE_PATH"
  sudo chmod 600 "$NETPLAN_FILE_PATH"
  WIFI_PASSWORD=$(bw get password wifi --session "$BW_SESSION")
  sudo sed --in-place "s/__PASSWORD__/$WIFI_PASSWORD/g" "$NETPLAN_FILE_PATH"
fi

# Install Git.
if ! command -v git &> /dev/null; then
  sudo apt install git --yes
  git config --global user.name "$FULL_NAME"
  git config --global user.email "$WORK_EMAIL"
fi

# Install the GitHub CLI.
if ! command -v gh &> /dev/null; then
  # From: https://github.com/cli/cli/blob/trunk/docs/install_linux.md#debian
  (type -p wget &> /dev/null || (sudo apt update && sudo apt install wget --yes)) \
    && sudo mkdir -p -m 755 /etc/apt/keyrings \
    && out=$(mktemp) && wget -nv "-O$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    && cat "$out" | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg &> /dev/null \
    && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && sudo mkdir -p -m 755 /etc/apt/sources.list.d \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list &> /dev/null \
    && sudo apt update \
    && sudo apt install gh --yes

  # gh uses HTTPS by default.
  gh config set git_protocol ssh

  if [[ -z "$GH_TOKEN" ]]; then
    echo "Error: The \"GH_TOKEN\" environment variable is empty. This is needed by the \"gh\" command to authenticate to GitHub. It should be present in the \".env\" file (which comes from BitWarden)." >&2
    exit 1
  fi
fi

# Set up the "repositories" directory.
REPOSITORIES_PATH="$HOME/repositories"
mkdir --parents "$REPOSITORIES_PATH"

# Clone this repository.
CONFIGS_PATH="$REPOSITORIES_PATH/configs"
if [[ ! -d "$CONFIGS_PATH" ]]; then
  KNOWN_HOSTS_PATH="$HOME/.ssh/known_hosts"
  if ! grep --quiet github.com "$KNOWN_HOSTS_PATH"; then
    ssh-keyscan github.com >> "$KNOWN_HOSTS_PATH"
  fi
  gh repo clone Zamiell/configs "$CONFIGS_PATH"
  git -C "$CONFIGS_PATH" config user.name "$GITHUB_USERNAME"
  git -C "$CONFIGS_PATH" config user.email "$GITHUB_EMAIL"
fi

# Install the remote configs from this repository.
BASHRC_PATH="$HOME/.bashrc"
if ! grep --quiet BASH_PROFILE_REMOTE_PATH "$BASHRC_PATH"; then
  echo >> "$BASHRC_PATH"
  curl --silent --fail --show-error https://raw.githubusercontent.com/Zamiell/configs/refs/heads/main/bash/.bash_profile >> "$BASHRC_PATH"
fi

# Install a desktop environment.
# - sway     - The window manager.
# - xwayland - A compatibility layer for X11 applications. By default, sway will enable xwayland, so
#              even if we do not have any X11 applications, it is still needed to prevent errors.
# - foot     - The terminal.
sudo apt install sway xwayland foot --yes

# Set sway on startup.
PROFILE_PATH="$HOME/.profile"
# shellcheck disable=SC2016
if ! grep --quiet "exec dbus-run-session sway" "$PROFILE_PATH"; then
  echo '
# Start the window manager.
if [[ -z "$WAYLAND_DISPLAY" ]] && [[ "$XDG_VTNR" -eq 1 ]]; then
  exec dbus-run-session sway > ~/sway-startup.log 2>&1
fi' >> "$PROFILE_PATH"
fi

# ---
# End
# ---

# Stop the automatic execution of this script.
PROFILE_MARKER="--- TEMP ---" # This has to match the command in "autoinstall.yaml".
if grep --quiet --regexp "$PROFILE_MARKER" "$PROFILE_PATH"; then
  sed --in-place "/$PROFILE_MARKER/,/$PROFILE_MARKER/d" "$PROFILE_PATH"
fi

# Clean up.
POST_INSTALL_PATH="/post-install"
if [[ -d "$POST_INSTALL_PATH" ]]; then
  sudo rm -rf "$POST_INSTALL_PATH"
fi
BITWARDEN_PASSWORD_PATH="$HOME/bitwarden_password"
if [[ -f "$BITWARDEN_PASSWORD_PATH" ]]; then
  rm "$BITWARDEN_PASSWORD_PATH"
fi

# Enable the sudo password. (We only needed it to be disabled in order to run this script without
# any prompts.)
SUDOERS_FILE_PATH="/etc/sudoers.d/90-cloud-init-users"
if [[ -f "$SUDOERS_FILE_PATH" ]]; then
  sudo rm "$SUDOERS_FILE_PATH"
fi

# We want to reboot so that the new Ubuntu kernel can take effect. (There is a warning about this
# when SSHing to the machine.)
reboot
