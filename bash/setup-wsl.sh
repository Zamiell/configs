#!/bin/bash

sudo apt update
sudo apt upgrade --yes

# Set up SSH.
SSH_DIR="$HOME/.ssh"
mkdir "$SSH_DIR"
cp "/mnt/c/Users/jnesta/.ssh/id_ed25519" "$SSH_DIR/id_ed25519"
chmod 600 "$SSH_DIR/id_ed25519"
cp "/mnt/c/Users/jnesta/.ssh/id_ed25519.pub" "$SSH_DIR/id_ed25519.pub"
mkdir "$SSH_DIR/work"
cp "/mnt/c/Users/jnesta/.ssh/work/id_rsa" "$SSH_DIR/work/id_rsa"
chmod 600 "$SSH_DIR/work/id_rsa"
cp "/mnt/c/Users/jnesta/.ssh/work/id_rsa.pub" "$SSH_DIR/work/id_rsa.pub"

# Set up company certificates.
CERT_PATH="/usr/local/share/ca-certificates/BEDROOTCA001.crt"
sudo curl --silent --fail --show-error --location http://certs.logixhealth.com/BEDROOTCA001.crt --output "$CERT_PATH" && sudo update-ca-certificates

# CLone repositories.
ssh-keyscan github.com >> "$HOME/.ssh/known_hosts" 2> /dev/null
REPOSITORIES_DIR="$HOME/repositories"
mkdir "$REPOSITORIES_DIR"
cd "$REPOSITORIES_DIR"
git clone git@github.com:Zamiell/configs.git
git clone git@github.com:Zamiell/notes.git

# Load the Bash configs.
echo '
# Load the commands from the "configs" GitHub repository: https://github.com/Zamiell/configs
CONFIGS_REPO_PATH="/home/jnesta/repositories/configs"
# shellcheck source=/dev/null
source "$CONFIGS_REPO_PATH/bash/bashrc.sh"
' >> ~/.bashrc

# Install GitHub Copilot CLI.
curl -fsSL https://gh.io/copilot-install --cacert "$CERT_PATH" | bash
