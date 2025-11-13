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
#sudo apt upgrade --yes # TODO: Uncomment

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
  if bw login --check &> /dev/null; then
    BW_SESSION=$(bw unlock --raw)
  else
    BW_SESSION=$(bw login $PERSONAL_EMAIL --raw)
  fi

  if [[ -z "$BW_SESSION" ]]; then
    echo "Error: Failed to get the BitWarden session key." >&2
    exit 1
  fi

  export BW_SESSION
fi

# Set up environment variables.
ENV_PATH="$HOME/.env"
if [[ ! -f "$ENV_PATH" ]]; then
  bw get notes .env > "$ENV_PATH"
  echo >> "$ENV_PATH"
fi
# shellcheck source=/dev/null
source "$ENV_PATH"

# Set up SSH keys.
mkdir --parents "$HOME/.ssh"
USER_PRIVATE_KEY_PATH="$HOME/.ssh/id_rsa"
if [[ ! -f "$USER_PRIVATE_KEY_PATH" ]]; then
  bw get notes ssh-private-key > "$USER_PRIVATE_KEY_PATH"
  echo >> "$USER_PRIVATE_KEY_PATH"
  chmod 600 "$USER_PRIVATE_KEY_PATH"
fi
USER_PUBLIC_KEY_PATH="$HOME/.ssh/id_rsa.pub"
if [[ ! -f "$USER_PUBLIC_KEY_PATH" ]]; then
  bw get notes ssh-public-key > "$USER_PUBLIC_KEY_PATH"
  echo >> "$USER_PUBLIC_KEY_PATH"
fi

# Connect to WiFi.
sudo apt install wpasupplicant --yes
NETPLAN_FILE_NAME="99-wifi.yaml"
NETPLAN_FILE_PATH="/etc/netplan/$NETPLAN_FILE_NAME"
if [[ ! -f "$NETPLAN_FILE_PATH" ]]; then
  sudo cp "$DIR/netplan/$NETPLAN_FILE_NAME" "$NETPLAN_FILE_PATH"
  sudo chmod 600 "$NETPLAN_FILE_PATH"
  WIFI_PASSWORD=$(bw get password wifi)
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
fi

# Set up the "repositories" directory.
REPOSITORIES_PATH="$HOME/repositories"
mkdir --parents "$REPOSITORIES_PATH"

# Clone this repository.
CONFIGS_PATH="$REPOSITORIES_PATH/configs"
if [[ ! -d "$CONFIGS_PATH" ]]; then
  gh repo clone Zamiell/configs "$CONFIGS_PATH"
  git -C "$CONFIGS_PATH" config user.name "$GITHUB_USERNAME"
  git -C "$CONFIGS_PATH" config user.email "$GITHUB_EMAIL"
fi

# Overwrite the profile that was set up in the "autoinstall.yaml" file with the one from the
# "configs" repository.
PROFILE_PATH="$HOME/.profile"
if grep post-install.sh "$PROFILE_PATH"; then
  curl --silent --fail --show-error https://raw.githubusercontent.com/Zamiell/configs/refs/heads/main/bash/.bash_profile > "$PROFILE_PATH"
fi

# Clean up.
POST_INSTALL_PATH="$HOME/post-install"
if [[ -d "$POST_INSTALL_PATH" ]]; then
  rm -rf "$POST_INSTALL_PATH"
fi

reboot
