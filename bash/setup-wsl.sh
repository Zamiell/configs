#!/bin/bash

set -euo pipefail # Exit on errors and undefined variables.

# Update.
sudo apt update
sudo apt upgrade --yes
sudo apt install --yes \
  age \
  jq \
  shellcheck \
  unzip \
  wslu

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

# Clone personal repositories.
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
if [[ ! -d "$REPOSITORIES_DIR/secrets" ]]; then
  git clone git@github.com:Zamiell/secrets.git
fi

# Load Git settings.
"$REPOSITORIES_DIR/configs/bash/set-git-settings.sh"
cp "$REPOSITORIES_DIR/configs/ubuntu-auto-install/post-install/.ssh/config" "$SSH_DIR/config"

# Load the Bash configs.
BASHRC_PATH="$HOME/.bashrc"
if ! grep --quiet "Load the commands from the \"configs\"" "$BASHRC_PATH"; then
  # shellcheck disable=SC2016
  echo '
# Load the commands from the "configs" GitHub repository: https://github.com/Zamiell/configs
CONFIGS_REPO_PATH="/home/jnesta/repositories/configs"
# shellcheck source=/dev/null
source "$CONFIGS_REPO_PATH/bash/bashrc.sh"
' >> "$BASHRC_PATH"
fi

# Clone work repositories.
if ! ssh-keygen -F azuredevops.logixhealth.com &> /dev/null; then
  ssh-keyscan azuredevops.logixhealth.com >> "$HOME/.ssh/known_hosts" 2> /dev/null
fi
if [[ ! -d "$REPOSITORIES_DIR/database-services" ]]; then
  git clone ssh://azuredevops.logixhealth.com:22/LogixHealth/Analytics%20and%20Innovation/_git/database-services
fi
if [[ ! -d "$REPOSITORIES_DIR/infrastructure" ]]; then
  git clone ssh://azuredevops.logixhealth.com:22/LogixHealth/Infrastructure/_git/infrastructure
fi
if [[ ! -d "$REPOSITORIES_DIR/LogixApplications" ]]; then
  git clone ssh://azuredevops.logixhealth.com:22/LogixHealth/Software%20Engineering/_git/LogixApplications
fi

# ----------------
# Install software
# ----------------

# Install GitHub Copilot CLI.
# https://github.com/features/copilot/cli/
if ! command -v copilot &> /dev/null; then
  curl --silent --fail --show-error --location https://gh.io/copilot-install --cacert "$CERT_PATH" | bash
fi

# Install Bun.
# https://bun.sh/
if ! command -v bun &> /dev/null; then
  curl --silent --fail --show-error --location https://bun.com/install | bash
fi

# Install zoxide.
# https://github.com/ajeetdsouza/zoxide
if ! command -v zoxide &> /dev/null; then
  curl --silent --fail --show-error --location https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
fi

# Install fzf.
# https://github.com/junegunn/fzf
if command -v fzf &> /dev/null; then
  LATEST_RELEASE_JSON=$(curl --silent --fail --show-error --location https://api.github.com/repos/junegunn/fzf/releases/latest)
  TAG_NAME=$(jq --raw-output '.tag_name' <<< "$LATEST_RELEASE_JSON")
  # Check if TAG_NAME is empty or literal "null" (which jq returns if the key is missing)
  if [[ -z "$TAG_NAME" ]] || [[ "$TAG_NAME" == "null" ]]; then
    echo "Failed to fetch the latest version of fzf."
    exit
  fi
  VERSION="${TAG_NAME#v}"
  FILENAME="fzf-${VERSION}-linux_amd64.tar.gz"
  DOWNLOAD_URL="https://github.com/junegunn/fzf/releases/download/${TAG_NAME}/${FILENAME}"
  TMP_PATH="/tmp/$FILENAME"
  curl --silent --fail --show-error --location --output "$TMP_PATH" "$DOWNLOAD_URL"
  tar -xzf "/tmp/$FILENAME" -C /tmp
  sudo mv /tmp/fzf /usr/local/bin/
  rm "$TMP_PATH"
fi
