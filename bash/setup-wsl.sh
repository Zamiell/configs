#!/bin/bash

set -euo pipefail # Exit on errors and undefined variables.

# Update.
sudo apt update
sudo apt upgrade --yes

# Set up SSH.
SSH_DIR="$HOME/.ssh"
mkdir -p "$SSH_DIR"
if [[ ! -s "/mnt/c/Users/jnesta/.ssh/id_ed25519" ]]; then
  cp "/mnt/c/Users/jnesta/.ssh/id_ed25519" "$SSH_DIR/id_ed25519"
  chmod 600 "$SSH_DIR/id_ed25519"
fi
if [[ ! -s "/mnt/c/Users/jnesta/.ssh/id_ed25519.pub" ]]; then
  cp "/mnt/c/Users/jnesta/.ssh/id_ed25519.pub" "$SSH_DIR/id_ed25519.pub"
fi
mkdir -p "$SSH_DIR/work"
if [[ ! -s "/mnt/c/Users/jnesta/.ssh/work/id_rsa" ]]; then
  cp "/mnt/c/Users/jnesta/.ssh/work/id_rsa" "$SSH_DIR/work/id_rsa"
  chmod 600 "$SSH_DIR/work/id_rsa"
fi
if [[ ! -s "/mnt/c/Users/jnesta/.ssh/work/id_rsa.pub" ]]; then
  cp "/mnt/c/Users/jnesta/.ssh/work/id_rsa.pub" "$SSH_DIR/work/id_rsa.pub"
fi

# Set up company certificates.
CERT_PATH="/usr/local/share/ca-certificates/BEDROOTCA001.crt"
if [[ ! -s "$CERT_PATH" ]]; then
  sudo curl --silent --fail --show-error --location http://certs.logixhealth.com/BEDROOTCA001.crt --output "$CERT_PATH" && sudo update-ca-certificates
fi

# Clone repositories.
if ! ssh-keygen -F github.com &> /dev/null; then
  ssh-keyscan github.com >> "$HOME/.ssh/known_hosts" 2> /dev/null
fi
REPOSITORIES_DIR="$HOME/repositories"
mkdir -p "$REPOSITORIES_DIR"
cd "$REPOSITORIES_DIR"
if [[ ! -d "$REPOSITORIES_DIR/configs" ]]; then
  git clone git@github.com:Zamiell/configs.git
fi
if [[ ! -d "$REPOSITORIES_DIR/notes" ]]; then
  git clone git@github.com:Zamiell/notes.git
fi

# Load Git settings.
"$REPOSITORIES_DIR/configs/bash/set-git-settings.sh"

# Load the Bash configs.
BASHRC_PATH="$HOME/.bashrc"
if ! grep --quiet "Load the commands from the \"configs\"" "$BASHRC_PATH"
  echo '
# Load the commands from the "configs" GitHub repository: https://github.com/Zamiell/configs
CONFIGS_REPO_PATH="/home/jnesta/repositories/configs"
# shellcheck source=/dev/null
source "$CONFIGS_REPO_PATH/bash/bashrc.sh"
' >> "$BASHRC_PATH"
fi

# Install GitHub Copilot CLI.
if ! command -v copilot; then
  curl --silent --fail --show-error --location https://gh.io/copilot-install --cacert "$CERT_PATH" | bash
fi
