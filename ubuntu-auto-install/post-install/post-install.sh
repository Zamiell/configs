#!/bin/bash

# This script sets up a new Ubuntu Server to have all of the configuration and software that I need.

set -euo pipefail # Exit on errors and undefined variables.
set -x            # Echo all commands to make debugging easier.

# Constants
GITHUB_USERNAME="Zamiell"
FULL_NAME="James Nesta"
PERSONAL_EMAIL="j.nesta@gmail.com"
WORK_EMAIL="jnesta@logixhealth.com"
GITHUB_EMAIL="5511220+Zamiell@users.noreply.github.com"

# Get the directory of this script:
# https://stackoverflow.com/questions/59895/getting-the-source-directory-of-a-bash-script-from-within
DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

# Other variables
OS_USERNAME=$(id --name --user 1000)

# ----------------
# Helper functions
# ----------------

play_sound() {
  amixer sset Master unmute &> /dev/null
  play "/home/$OS_USERNAME/post-install/ff7.mp3" &> /dev/null
}

# ----------
# Validation
# ----------

if [[ $EUID -ne 0 ]]; then
  echo "Error: This script must be run as root" >&2
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
apt update
apt upgrade --yes

# Install SSH.
# https://documentation.ubuntu.com/server/how-to/security/openssh-server/index.html
apt install openssh-server --yes
systemctl enable ssh
systemctl start ssh

# Disable the message of the day.
touch "/home/$OS_USERNAME/.hushlogin"

# Install the BitWarden CLI.
if ! command -v bw &> /dev/null; then
  snap install bw
fi

# Login to BitWarden. (This command will prompt the user for the master password.)
if [[ -z "${BW_SESSION:-}" ]]; then
  play_sound # Signify that manual intervention is needed.

  if ! bw login --check &> /dev/null; then
    BW_SESSION=$(bw login $PERSONAL_EMAIL --raw)
  else
    BW_SESSION=$(bw unlock --raw)
  fi

  if [[ -z "$BW_SESSION" ]]; then
    echo "Error: Failed to get the BitWarden session key." >&2
    exit 1
  fi

  export BW_SESSION
fi

# Set up my environment variables.
ENV_PATH="/home/$OS_USERNAME/.env"
if [[ ! -f "$ENV_PATH" ]]; then
  bw get notes .env > "$ENV_PATH"
  echo >> "$ENV_PATH"
fi
chown "$OS_USERNAME:$OS_USERNAME" "$ENV_PATH"
# shellcheck source=/dev/null
source "$ENV_PATH"

# Set up my SSH keys.
mkdir --parents "/root/.ssh"
ROOT_PRIVATE_KEY_PATH="/root/.ssh/id_rsa"
if [[ ! -f "$ROOT_PRIVATE_KEY_PATH" ]]; then
  bw get notes ssh-private-key > "$ROOT_PRIVATE_KEY_PATH"
  echo >> "$ROOT_PRIVATE_KEY_PATH"
  chmod 600 "$ROOT_PRIVATE_KEY_PATH"
fi
ROOT_PUBLIC_KEY_PATH="/root/.ssh/id_rsa.pub"
if [[ ! -f "$ROOT_PUBLIC_KEY_PATH" ]]; then
  bw get notes ssh-public-key > "$ROOT_PUBLIC_KEY_PATH"
  echo >> "$ROOT_PUBLIC_KEY_PATH"
fi
mkdir --parents "/home/$OS_USERNAME/.ssh"
USER_PRIVATE_KEY_PATH="/home/$OS_USERNAME/.ssh/id_rsa"
if [[ ! -f "$USER_PRIVATE_KEY_PATH" ]]; then
  bw get notes ssh-private-key > "$USER_PRIVATE_KEY_PATH"
  echo >> "$USER_PRIVATE_KEY_PATH"
  chmod 600 "$USER_PRIVATE_KEY_PATH"
  chown "$OS_USERNAME:$OS_USERNAME" "$USER_PRIVATE_KEY_PATH"
fi
USER_PUBLIC_KEY_PATH="/home/$OS_USERNAME/.ssh/id_rsa.pub"
if [[ ! -f "$USER_PUBLIC_KEY_PATH" ]]; then
  bw get notes ssh-public-key > "$USER_PUBLIC_KEY_PATH"
  echo >> "$USER_PUBLIC_KEY_PATH"
  chown "$OS_USERNAME:$OS_USERNAME" "$USER_PUBLIC_KEY_PATH"
fi

# Connect to WiFi.
apt install wpasupplicant -y
NETPLAN_FILE_NAME="99-wifi.yaml"
NETPLAN_FILE_PATH="/etc/netplan/$NETPLAN_FILE_NAME"
if [[ ! -f "$NETPLAN_FILE_PATH" ]]; then
  cp "$DIR/netplan/$NETPLAN_FILE_NAME" "$NETPLAN_FILE_PATH"
  chmod 600 "$NETPLAN_FILE_PATH"
  WIFI_PASSWORD=$(bw get password wifi)
  sed --in-place "s/__PASSWORD__/$WIFI_PASSWORD/g" "$NETPLAN_FILE_PATH"
fi

# Install Git.
apt install git -y
git config --global user.name "$FULL_NAME"
git config --global user.email "$WORK_EMAIL"

# Install the GitHub CLI.
if ! command -v gh &> /dev/null; then
  # From: https://github.com/cli/cli/blob/trunk/docs/install_linux.md#debian
  (type -p wget &> /dev/null || (sudo apt update && sudo apt install wget -y)) \
    && sudo mkdir -p -m 755 /etc/apt/keyrings \
    && out=$(mktemp) && wget -nv "-O$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    && cat "$out" | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg &> /dev/null \
    && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && sudo mkdir -p -m 755 /etc/apt/sources.list.d \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list &> /dev/null \
    && sudo apt update \
    && sudo apt install gh -y

  # gh uses HTTPS by default.
  gh config set git_protocol ssh
fi

# Set up the "repositories" directory.
REPOSITORIES_PATH="/home/$OS_USERNAME/repositories"
mkdir --parents "$REPOSITORIES_PATH"
chown --recursive "$OS_USERNAME:$OS_USERNAME" "$REPOSITORIES_PATH"

# Clone this repository.
CONFIGS_PATH="$REPOSITORIES_PATH/configs"
if [[ ! -d "$CONFIGS_PATH" ]]; then
  gh repo clone Zamiell/configs "$CONFIGS_PATH"
  git -C "$CONFIGS_PATH" config user.name "$GITHUB_USERNAME"
  git -C "$CONFIGS_PATH" config user.email "$GITHUB_EMAIL"
  chown --recursive "$OS_USERNAME:$OS_USERNAME" "$CONFIGS_PATH"
fi

# Overwrite the profile that was set up in the "autoinstall.yaml" file with the one from the
# "configs" repository.
PROFILE_PATH="/home/$OS_USERNAME/.profile"
curl --silent --fail --show-error https://raw.githubusercontent.com/Zamiell/configs/refs/heads/main/bash/.bash_profile > "$PROFILE_PATH"
chown "$OS_USERNAME:$OS_USERNAME" "$PROFILE_PATH"

# Clean up.
rm -rf "$DIR"

echo "Please log out and then log back in order to have the remote Bash profile take effect."
play_sound
