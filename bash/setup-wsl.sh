#!/bin/bash

set -euo pipefail # Exit on errors and undefined variables.

if [[ "${ID:-}" != "ubuntu" ]]; then
  echo "Error: This script is intended to be run inside Ubuntu WSL (Windows Subsystem for Linux)." >&2
  exit
fi

# -----------
# Subroutines
# -----------

get-github-latest-release-url() {
  local repository="$1"
  if [[ -z "$repository" ]]; then
    echo "You must pass this function the GitHub author and repository name as the first argument." >&2
    exit 1
  fi

  local filename_template="$2"
  if [[ -z "$filename_template" ]]; then
    echo "You must pass this function the filename template as the second argument." >&2
    exit 1
  fi

  local latest_release_json
  latest_release_json=$(curl --silent --fail --show-error --location "https://api.github.com/repos/${repository}/releases/latest")

  local tag_name
  tag_name=$(jq --raw-output '.tag_name' <<< "$latest_release_json")

  # Check if TAG_NAME is empty or literal "null" (which jq returns if the key is missing).
  if [[ -z "$tag_name" ]] || [[ "$tag_name" == "null" ]]; then
    echo "Failed to fetch the latest version of: $repository" >&2
    exit 1
  fi

  local version
  version="${tag_name#v}"

  local filename
  filename="${filename_template//\{tag_name\}/$tag_name}"
  filename="${filename//\{version\}/$version}"
  echo "https://github.com/${repository}/releases/download/${tag_name}/${filename}"
}

install-binary-from-tar-url() {
  local download_url="$1"
  if [[ -z "$download_url" ]]; then
    echo "You must pass this function the tar download URL as the first argument." >&2
    exit 1
  fi

  local binary_name="$2"
  if [[ -z "$binary_name" ]]; then
    echo "You must pass this function the binary name as the second argument." >&2
    exit 1
  fi

  local filename
  filename="${download_url##*/}"

  local tmp_path
  tmp_path="/tmp/$filename"

  curl --silent --fail --show-error --location --output "$tmp_path" "$download_url"
  tar -xzf "$tmp_path" -C /tmp
  sudo mv "/tmp/$binary_name" /usr/local/bin/
  rm "$tmp_path"
}

# ----------
# Main setup
# ----------

# Update.
sudo apt-get update
sudo apt-get upgrade --yes
sudo apt-get install --yes \
  age \
  jq \
  podman \
  python-is-python3 \
  ripgrep \
  shellcheck \
  unzip \
  wslu

# Set up SSH.
if [[ "$USER" == "jnesta" ]]; then
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
if [[ "$USER" == "jnesta" ]]; then
  if [[ ! -d "$REPOSITORIES_DIR/notes" ]]; then
    git clone git@github.com:Zamiell/notes.git
  fi
  if [[ ! -d "$REPOSITORIES_DIR/secrets" ]]; then
    git clone git@github.com:Zamiell/secrets.git
  fi
fi

# Load Git settings.
"$REPOSITORIES_DIR/configs/bash/set-git-settings.sh"
if [[ "$USER" == "jnesta" ]]; then
  cp "$REPOSITORIES_DIR/configs/ubuntu-auto-install/post-install/.ssh/config" "$SSH_DIR/config"
fi

# Load the Bash configs.
BASHRC_PATH="$HOME/.bashrc"
if ! grep --quiet "Load the commands from the \"configs\"" "$BASHRC_PATH"; then
  # shellcheck disable=SC2016
  echo '
# Load the commands from the "configs" GitHub repository: https://github.com/Zamiell/configs
CONFIGS_REPO_PATH="~/repositories/configs"
# shellcheck source=/dev/null
source "$CONFIGS_REPO_PATH/bash/bashrc.sh"
' >> "$BASHRC_PATH"
fi

# Clone work repositories.
if ! ssh-keygen -F azuredevops.logixhealth.com &> /dev/null; then
  ssh-keyscan azuredevops.logixhealth.com >> "$HOME/.ssh/known_hosts" 2> /dev/null
fi
if [[ ! -d "$REPOSITORIES_DIR/allscripts-external" ]]; then
  git clone ssh://azuredevops.logixhealth.com:22/LogixHealth/Software%20Engineering/_git/allscripts-external
  if [[ "$USER" == "jnesta" ]]; then
    git -C "$REPOSITORIES_DIR/allscripts-external" config user.name "James Nesta"
    git -C "$REPOSITORIES_DIR/allscripts-external" config user.email "jnesta@logixhealth.com"
  fi
fi
if [[ ! -d "$REPOSITORIES_DIR/database-services" ]]; then
  git clone ssh://azuredevops.logixhealth.com:22/LogixHealth/Analytics%20and%20Innovation/_git/database-services
  if [[ "$USER" == "jnesta" ]]; then
    git -C "$REPOSITORIES_DIR/database-services" config user.name "James Nesta"
    git -C "$REPOSITORIES_DIR/database-services" config user.email "jnesta@logixhealth.com"
  fi
fi
if [[ ! -d "$REPOSITORIES_DIR/infrastructure" ]]; then
  git clone ssh://azuredevops.logixhealth.com:22/LogixHealth/Infrastructure/_git/infrastructure
  if [[ "$USER" == "jnesta" ]]; then
    git -C "$REPOSITORIES_DIR/infrastructure" config user.name "James Nesta"
    git -C "$REPOSITORIES_DIR/infrastructure" config user.email "jnesta@logixhealth.com"
  fi
fi
if [[ ! -d "$REPOSITORIES_DIR/LogixApplications" ]]; then
  git clone ssh://azuredevops.logixhealth.com:22/LogixHealth/Software%20Engineering/_git/LogixApplications
  if [[ "$USER" == "jnesta" ]]; then
    git -C "$REPOSITORIES_DIR/LogixApplications" config user.name "James Nesta"
    git -C "$REPOSITORIES_DIR/LogixApplications" config user.email "jnesta@logixhealth.com"
  fi
fi

# -----------------------------
# Install programming languages
# -----------------------------

# Install fnm.
# https://github.com/Schniz/fnm
if ! command -v fnm &> /dev/null; then
  # The "--skip-shell" is necessary to prevent fnm from modifying the ".bashrc" file.
  curl --silent --fail --show-error --location https://fnm.vercel.app/install | bash -s -- --skip-shell

  # Add it to PATH for the current session.
  FNM_PATH="$HOME/.local/share/fnm"
  export PATH="$FNM_PATH:$PATH"
  eval "$(fnm env --shell bash)"
fi

# Install Node.js
if ! command -v node &> /dev/null && command -v fnm &> /dev/null; then
  fnm install --lts
fi

# Install Bun.
# https://bun.sh/
if ! command -v bun &> /dev/null; then
  curl --silent --fail --show-error --location https://bun.com/install | bash
fi

# Install uv.
# https://docs.astral.sh/uv/getting-started/installation/
if ! command -v uv &> /dev/null; then
  curl --silent --fail --show-error --location https://astral.sh/uv/install.sh | sh
fi

# Install PowerShell.
# https://learn.microsoft.com/en-us/powershell/scripting/install/install-ubuntu
if ! command -v pwsh &> /dev/null; then
  # shellcheck source=/dev/null
  source /etc/os-release
  DEB_PATH="/tmp/packages-microsoft-prod.deb"
  curl --silent --fail --show-error --location --output "$DEB_PATH" "https://packages.microsoft.com/config/ubuntu/$VERSION_ID/packages-microsoft-prod.deb"
  sudo dpkg --install packages-microsoft-prod.deb
  rm "$DEB_PATH"
  sudo apt-get update
  sudo apt-get install powershell --yes
fi

# Install Terraform.
# https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli
if ! command -v terraform &> /dev/null; then
  curl --silent --fail --show-error --location https://apt.releases.hashicorp.com/gpg \
    | gpg --dearmor \
    | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
    | sudo tee /etc/apt/sources.list.d/hashicorp.list
  sudo apt-get update
  sudo apt-get install terraform --yes
fi

# Install `terraform-docs`.
# https://github.com/terraform-docs/terraform-docs
if ! command -v terraform-docs &> /dev/null; then
  DOWNLOAD_URL=$(get-github-latest-release-url "terraform-docs/terraform-docs" "terraform-docs-v{version}-linux-amd64.tar.gz")
  install-binary-from-tar-url "$DOWNLOAD_URL" "terraform-docs"
fi

# Install Pulumi
if ! command -v pulumi &> /dev/null; then
  curl --silent --fail --show-error --location https://get.pulumi.com | sh
fi

# --------------------------------
# Install quality of life software
# --------------------------------

# Install zoxide.
# https://github.com/ajeetdsouza/zoxide
if ! command -v zoxide &> /dev/null; then
  curl --silent --fail --show-error --location https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
fi

# Install fzf.
# https://github.com/junegunn/fzf
if command -v fzf &> /dev/null; then
  DOWNLOAD_URL=$(get-github-latest-release-url "junegunn/fzf" "fzf-{version}-linux_amd64.tar.gz")
  install-binary-from-tar-url "$DOWNLOAD_URL" "fzf"
fi

# -------------
# Install tools
# -------------

# Install the GitHub CLI.
# https://github.com/cli/cli/blob/trunk/docs/install_linux.md#debian
if ! command -v gh &> /dev/null; then
  sudo mkdir -p -m 755 /etc/apt/keyrings
  curl --silent --fail --show-error --location https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
  sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  sudo mkdir -p -m 755 /etc/apt/sources.list.d
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
  sudo apt update
  sudo apt install gh -y
fi

# Install the GitHub Copilot CLI.
# https://github.com/features/copilot/cli/
if ! command -v copilot &> /dev/null; then
  curl --silent --fail --show-error --location https://gh.io/copilot-install --cacert "$CERT_PATH" | bash
fi

# Install the Azure CLI.
# https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-linux?view=azure-cli-latest&pivots=apt#option-1-install-with-one-command
if ! command -v az &> /dev/null; then
  curl --silent --fail --show-error --location https://aka.ms/InstallAzureCLIDeb | sudo bash
fi
