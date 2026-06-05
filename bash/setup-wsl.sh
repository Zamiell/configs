#!/bin/bash

# Run this script with:
# curl https://raw.githubusercontent.com/Zamiell/configs/refs/heads/main/bash/setup-wsl.sh | bash

set -euo pipefail # Exit on errors and undefined variables.

if [[ ! -s "/etc/os-release" ]]; then
  echo "Error: This script is intended to be run inside Ubuntu WSL (Windows Subsystem for Linux)." >&2
  exit
fi

# shellcheck source=/dev/null
source /etc/os-release

if [[ "${ID:-}" != "ubuntu" ]]; then
  echo "Error: This script is intended to be run inside Ubuntu WSL (Windows Subsystem for Linux)." >&2
  exit
fi

# -----------
# Subroutines
# -----------

clone-work-repo() {
  if [[ -z "${1:-}" ]]; then
    echo "You must pass the repository URL as the first argument." >&2
    return 1
  fi
  local repository_url="$1"

  local directory_name="${repository_url##*/}"
  if [[ -z "$directory_name" ]]; then
    echo "Failed to derive the repository directory name from the repository URL of: $repository_url" >&2
    return 1
  fi

  local repository_path="$REPOSITORIES_DIR/$directory_name"
  if [[ ! -d "$repository_path" ]]; then
    if [[ ! -s "$HOME/.ssh/id_rsa" ]] && [[ ! -s "$HOME/.ssh/work/id_rsa" ]]; then
      echo "Warning: Skipping the git clone of \"repository_url\" since you do not seem to have an SSH key installed at \"$HOME/.ssh/id_rsa\" or \"$HOME/.ssh/work/id_rsa\"." >&2
      return
    fi

    git clone "$repository_url" "$repository_path"

    if is-james; then
      git -C "$repository_path" config user.name "James Nesta"
      git -C "$repository_path" config user.email "jnesta@logixhealth.com"
    fi
  fi
}

is-james() {
  [[ "$USER" == "jnesta" ]]
}

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

# Update the system.
sudo apt-get update
sudo apt-get upgrade --yes

# Install some operating system packages.
# - "qemu-system-x86" is required for "podman machine init" to work.
# - "gvproxy" is needed for "podman machine start" to work.
# - "virtiofsd" is needed for "podman machine start" to work.
sudo apt-get install --yes \
  age \
  bind9-dnsutils \
  gvproxy \
  jq \
  podman \
  python-is-python3 \
  qemu-system-x86 \
  ripgrep \
  shellcheck \
  unzip \
  virtiofsd

# Set up SSH.
mkdir -p "$HOME/.ssh"
if is-james; then
  if [[ ! -s "$HOME/.ssh/id_ed25519" ]]; then
    cp "/mnt/c/Users/jnesta/.ssh/id_ed25519" "$HOME/.ssh/id_ed25519"
    chmod 600 "$HOME/.ssh/id_ed25519"
  fi
  if [[ ! -s "$HOME/.ssh/id_ed25519.pub" ]]; then
    cp "/mnt/c/Users/jnesta/.ssh/id_ed25519.pub" "$HOME/.ssh/id_ed25519.pub"
  fi
  mkdir -p "$HOME/.ssh/work"
  if [[ ! -s "$HOME/.ssh/work/id_rsa" ]]; then
    cp "/mnt/c/Users/jnesta/.ssh/work/id_rsa" "$HOME/.ssh/work/id_rsa"
    chmod 600 "$HOME/.ssh/work/id_rsa"
  fi
  if [[ ! -s "$HOME/.ssh/work/id_rsa.pub" ]]; then
    cp "/mnt/c/Users/jnesta/.ssh/work/id_rsa.pub" "$HOME/.ssh/work/id_rsa.pub"
  fi
fi

# Set up company certificates.
CERT_PATH="/usr/local/share/ca-certificates/BEDROOTCA001.crt"
if [[ ! -s "$CERT_PATH" ]]; then
  sudo curl --silent --fail --show-error --location http://certs.logixhealth.com/BEDROOTCA001.crt --output "$CERT_PATH"
  sudo update-ca-certificates
fi

# Clone personal repositories.
if ! ssh-keygen -F github.com &> /dev/null; then
  ssh-keyscan github.com >> "$HOME/.ssh/known_hosts" 2> /dev/null
fi
REPOSITORIES_DIR="$HOME/repositories"
mkdir -p "$REPOSITORIES_DIR"
cd "$REPOSITORIES_DIR"
if [[ ! -d "$REPOSITORIES_DIR/configs" ]]; then
  if [[ -s "$HOME/.ssh/id_ed25519" ]]; then
    git clone git@github.com:Zamiell/configs.git
  else
    git clone https://github.com/Zamiell/configs.git
  fi
fi
if is-james; then
  if [[ ! -d "$REPOSITORIES_DIR/notes" ]]; then
    git clone git@github.com:Zamiell/notes.git
  fi
  if [[ ! -d "$REPOSITORIES_DIR/secrets" ]]; then
    git clone git@github.com:Zamiell/secrets.git
  fi
fi

# Load Git settings.
"$REPOSITORIES_DIR/configs/bash/set-git-settings.sh"
if is-james; then
  cp "$REPOSITORIES_DIR/configs/ubuntu-auto-install/post-install/.ssh/config" "$HOME/.ssh/config"
fi

# Load the Bash configs.
BASHRC_PATH="$HOME/.bashrc"
if ! grep --quiet "Load the commands from the \"configs\"" "$BASHRC_PATH"; then
  # shellcheck disable=SC2016
  echo '
# Load the commands from the "configs" GitHub repository: https://github.com/Zamiell/configs
CONFIGS_REPO_PATH="$HOME/repositories/configs"
# shellcheck source=/dev/null
source "$CONFIGS_REPO_PATH/bash/bashrc.sh"
' >> "$BASHRC_PATH"
fi

# Clone work repositories.
if ! ssh-keygen -F azuredevops.logixhealth.com &> /dev/null; then
  ssh-keyscan azuredevops.logixhealth.com >> "$HOME/.ssh/known_hosts" 2> /dev/null
fi
#clone-work-repo "ssh://azuredevops.logixhealth.com:22/LogixHealth/Software%20Engineering/_git/allscripts-external"
#clone-work-repo "ssh://azuredevops.logixhealth.com:22/LogixHealth/Analytics%20and%20Innovation/_git/database-services"
#clone-work-repo "ssh://azuredevops.logixhealth.com:22/LogixHealth/Infrastructure/_git/infrastructure"
#clone-work-repo "ssh://azuredevops.logixhealth.com:22/LogixHealth/Software%20Engineering/_git/LogixApplications"
if ! ssh-keygen -F ssh.dev.azure.com &> /dev/null; then
  ssh-keyscan ssh.dev.azure.com >> "$HOME/.ssh/known_hosts" 2> /dev/null
fi
#clone-work-repo "git@ssh.dev.azure.com:v3/logixhealth/Main/databricks-data"

# -----------------------------
# Install programming languages
# -----------------------------

# Install Golang.
if ! command -v go &> /dev/null; then
  curl --silent --fail --location --output /tmp/go.tar.gz "https://go.dev/dl/$LATEST_GO_VERSION.linux-amd64.tar.gz"
  sudo tar -C /usr/local -xzf /tmp/go.tar.gz
  rm /tmp/go.tar.gz
fi

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
  DEB_PATH="/tmp/packages-microsoft-prod.deb"
  curl --silent --fail --show-error --location --output "$DEB_PATH" "https://packages.microsoft.com/config/ubuntu/$VERSION_ID/packages-microsoft-prod.deb"
  sudo dpkg --install "$DEB_PATH"
  rm "$DEB_PATH"
  sudo apt-get update
  if apt-cache show powershell &> /dev/null; then
    sudo apt-get install powershell --yes
  else
    # In some cases, the version of Ubuntu can be so new that there is no corresponding aptitude
    # package.
    DOWNLOAD_URL=$(get-github-latest-release-url "PowerShell/PowerShell" "powershell_{version}-1.deb_amd64.deb")
    DEB_PATH="/tmp/${DOWNLOAD_URL##*/}"
    curl --silent --fail --show-error --location --output "$DEB_PATH" "$DOWNLOAD_URL"
    sudo apt-get install "$DEB_PATH" --yes
    rm "$DEB_PATH"
  fi
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
if ! command -v fzf &> /dev/null; then
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
  sudo apt-get update
  sudo apt-get install gh --yes
fi

# Install the GitHub Copilot CLI.
# https://github.com/features/copilot/cli/
if ! command -v copilot &> /dev/null; then
  # We need to supply "PREFIX" and "PATH" to prevent the installer from prompting us about adding
  # itself to the PATH.
  curl --silent --fail --show-error --location https://gh.io/copilot-install --cacert "$CERT_PATH" \
    | PREFIX="$HOME/.local" PATH="$HOME/.local/bin:$PATH" bash

  mkdir -p "$HOME/.copilot/hooks"
  cp "$REPOSITORIES_DIR/configs/copilot/settings.json" "$HOME/.copilot/settings.json"
  cp "$REPOSITORIES_DIR/configs/copilot/hooks/sound.json" "$HOME/.copilot/hooks/sound.json"
fi

# Install the Azure CLI.
# https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-linux?view=azure-cli-latest&pivots=apt#option-1-install-with-one-command
if ! command -v az &> /dev/null; then
  curl --silent --fail --show-error --location https://aka.ms/InstallAzureCLIDeb | sudo bash

  # Install the LogixHealth certificate.
  if [[ ! -s "/opt/az/lib/python3.13/site-packages/certifi/cacert.pem" ]]; then
    echo "Error: Failed to find the \"cacert.pem\" file in the Azure CLI directory." >&2
    exit
  fi

  export REQUESTS_CA_BUNDLE="/opt/az/lib/python3.13/site-packages/certifi/cacert.pem"
  CERTIFICATE_NAME="BEDROOTCA001"
  {
    echo
    echo "# $CERTIFICATE_NAME"
    curl --silent --fail --show-error --location "http://certs.logixhealth.com/$CERTIFICATE_NAME.crt"
  } | sudo tee -a "$REQUESTS_CA_BUNDLE" > /dev/null
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

# Install Pulumi.
if ! command -v pulumi &> /dev/null; then
  curl --silent --fail --show-error --location https://get.pulumi.com | sh
  export PATH="$PATH:$HOME/.pulumi/bin"
fi

# Install Helm.
# https://helm.sh/docs/intro/install/
if ! command -v helm &> /dev/null; then
  curl --silent --fail --show-error --location https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
  echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
  sudo apt-get update
  sudo apt-get install helm --yes
fi

# Install helmfmt.
# https://github.com/digitalstudium/helmfmt
if ! command -v helmfmt &> /dev/null; then
  curl --silent --fail --show-error --location https://github.com/digitalstudium/helmfmt/releases/latest/download/helmfmt_Linux_x86_64.tar.gz | sudo tar -xzf - -C /usr/local/bin/ helmfmt
fi

# Set up podman.
if ! podman machine inspect podman-machine-default > /dev/null 2>&1; then
  # On the latest version of Ubuntu (26.04), "podman machine init" does not work anymore without the
  # "qemu-utils" dependency also installed.
  podman machine init

  # On the latest version of Ubuntu (26.04), "podman machine start" does not work anymore without
  # some other manual fixes.
  sudo mkdir -p /usr/libexec/podman
  sudo ln -sf /usr/bin/gvproxy /usr/libexec/podman/gvproxy
  sudo ln -sf /usr/libexec/virtiofsd /usr/local/bin/virtiofsd
  sudo usermod -aG kvm "$USER"
  # The above "usermod" command requires a restart of the shell to take effect, so we cannot
  # immediately invoke "podman machine start".
fi

# Install the wslview shim. (See the comments in the "wslview" script.)
if [[ ! -s /usr/local/bin/wslview ]]; then
  sudo cp "$REPOSITORIES_DIR/configs/bash/wslview" /usr/local/bin/wslview
fi

echo -e "\nSuccessfully set up WSL."
