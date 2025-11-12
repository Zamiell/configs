#!/bin/bash

# This script is used on a new Ubuntu Server to get all the installed software and settings that I need.

set -euo pipefail # Exit on errors and undefined variables.

# Get the directory of this script:
# https://stackoverflow.com/questions/59895/getting-the-source-directory-of-a-bash-script-from-within
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd)"

# Perform validation.
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" >&2
  exit 1
fi

# Connect to WiFi.
NETPLAN_FILE_NAME="99-wifi.yaml"
NETPLAN_FILE_PATH="/etc/netplan/$NETPLAN_FILE_NAME"
cp "$DIR/$NETPLAN_FILE_NAME" "$NETPLAN_FILE_PATH"
chmod 600 "$NETPLAN_FILE_PATH"
netplan apply

# Patch the OS.
apt-get update
apt-get upgrade --yes

# Install SSH.
# https://documentation.ubuntu.com/server/how-to/security/openssh-server/index.html
apt-get install openssh-server --yes
systemctl enable ssh
systemctl start ssh

# Install Cinnamon.
# The default installation includes Thunderbird, which is undesired.
# apt-get install cinnamon-desktop-environment-minimal --yes
