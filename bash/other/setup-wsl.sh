#!/bin/bash

# To install WSL:
# wsl --install Ubuntu

# To install WSL to a specific location:
# wsl --install Ubuntu --location "D:\VMs\WSL"

# To import an existing WSL installation:
# wsl --import-in-place Ubuntu "D:\WSL\Ubuntu\ext4.vhdx"

# Once WSL is installed, run this script with:
# curl https://raw.githubusercontent.com/Zamiell/configs/refs/heads/main/bash/other/setup-wsl.sh | bash

set -euo pipefail # Exit on errors and undefined variables.

PERSONAL=$([[ "$USER" == "james" ]] && echo "true" || echo "false")

if [[ ! -s "/etc/os-release" ]]; then
  echo "Error: This script is intended to be run inside Ubuntu WSL (Windows Subsystem for Linux)." >&2
  exit
fi

source /etc/os-release

if [[ "${ID:-}" != "ubuntu" ]]; then
  echo "Error: This script is intended to be run inside Ubuntu WSL (Windows Subsystem for Linux)." >&2
  exit
fi

# region: Subroutines
# -----------
# Subroutines
# -----------

clone-work-repo() {
  if [[ -z "${1:-}" ]]; then
    echo "Error: You must pass the repository URL as the first argument." >&2
    return 1
  fi
  local repository_url="$1"

  local directory_name="${repository_url##*/}"
  if [[ -z "$directory_name" ]]; then
    echo "Error: Failed to derive the repository directory name from the repository URL of: $repository_url" >&2
    return 1
  fi

  if [[ -z "${REPOSITORIES_DIR:-}" ]]; then
    echo "Error: The \"REPOSITORIES_DIR\" environment variable must be set to use this function." >&2
    return 1
  fi

  local repository_path="$REPOSITORIES_DIR/$directory_name"
  if [[ -d "$repository_path" ]]; then
    return
  fi

  if [[ ! -s "$HOME/.ssh/id_rsa" ]] && [[ ! -s "$HOME/.ssh/work/id_rsa" ]]; then
    echo "Warning: Skipping the git clone of \"repository_url\" since you do not seem to have an SSH key installed at \"$HOME/.ssh/id_rsa\" or \"$HOME/.ssh/work/id_rsa\"." >&2
    return
  fi

  echo "Cloning the repository of: $repository_url"
  git clone "$repository_url" "$repository_path"

  if is-james; then
    git -C "$repository_path" config user.name "James Nesta"
    git -C "$repository_path" config user.email "jnesta@logixhealth.com"
  fi

  if [[ -s "$repository_path/package-lock.json" ]]; then
    (cd "$repository_path" && npm ci)
  fi
  if [[ -s "$repository_path/bun.lock" ]]; then
    (cd "$repository_path" && bun ci)
  fi
  if [[ -s "$repository_path/pyproject.toml" ]]; then
    (cd "$repository_path" && uv sync --frozen)
  fi
}

is-james() {
  [[ "$USER" == "james" ]] || [[ "$USER" == "jnesta" ]]
}

run-with-preserved-bashrc() {
  local bashrc_path="$HOME/.bashrc"
  local bashrc_backup
  bashrc_backup=$(mktemp)

  local bashrc_existed=false
  if [[ -e "$bashrc_path" ]]; then
    bashrc_existed=true
    cp "$bashrc_path" "$bashrc_backup"
  fi

  local exit_status=0
  "$@" || exit_status=$?

  if "$bashrc_existed"; then
    cp "$bashrc_backup" "$bashrc_path"
  else
    rm --force "$bashrc_path"
  fi
  rm "$bashrc_backup"

  return "$exit_status"
}

get-github-latest-release-url() {
  local repository="$1"
  if [[ -z "$repository" ]]; then
    echo "Error: You must pass this function the GitHub author and repository name as the first argument." >&2
    return 1
  fi

  local filename_template="$2"
  if [[ -z "$filename_template" ]]; then
    echo "Error: You must pass this function the filename template as the second argument." >&2
    return 1
  fi

  local latest_release_json
  latest_release_json=$(curl --silent --fail --show-error --location "https://api.github.com/repos/${repository}/releases/latest")

  local tag_name
  tag_name=$(jq --raw-output '.tag_name' <<< "$latest_release_json")

  # Check if TAG_NAME is empty or literal "null" (which jq returns if the key is missing).
  if [[ -z "$tag_name" ]] || [[ "$tag_name" == "null" ]]; then
    echo "Error: Failed to fetch the latest version of: $repository" >&2
    return 1
  fi

  local tag_version
  tag_version="${tag_name##*/}"

  local version
  version="${tag_version#v}"

  local filename
  filename="${filename_template//\{tag_name\}/$tag_name}"
  filename="${filename//\{tag_version\}/$tag_version}"
  filename="${filename//\{version\}/$version}"
  echo "https://github.com/${repository}/releases/download/${tag_name}/${filename}"
}

install-binary-from-tar-url() {
  local download_url="$1"
  if [[ -z "$download_url" ]]; then
    echo "Error: You must pass this function the tar download URL as the first argument." >&2
    return 1
  fi

  local binary_name="$2"
  if [[ -z "$binary_name" ]]; then
    echo "Error: You must pass this function the binary name as the second argument." >&2
    return 1
  fi

  local filename
  filename="${download_url##*/}"

  local tmp_path
  tmp_path="/tmp/$filename"

  curl --silent --fail --show-error --location --output "$tmp_path" "$download_url"
  tar -xzf "$tmp_path" -C /tmp

  local destination_path="$HOME/.local/bin/"
  mkdir -p "$destination_path"
  mv "/tmp/$binary_name" "$destination_path"
  rm "$tmp_path"
}

install-vscode-extensions() {
  if [[ -z "${1:-}" ]]; then
    echo "Error: You must pass this function the file path as the first argument." >&2
    return 1
  fi
  local file_path="$1"

  if [[ ! -s "$file_path" ]]; then
    echo "Error: The file does not exist at: $file_path" >&2
    return 1
  fi

  local jq_filter
  case "$file_path" in
    *.code-workspace)
      jq_filter='.extensions | if type == "array" then .[] else .recommendations[] end'
      ;;
    *.json)
      jq_filter=".recommendations[]"
      ;;
    *)
      echo "Error: The file must be a \".json\" file or a \".code-workspace\" file: $file_path" >&2
      return 1
      ;;
  esac

  # "code" is located at: /mnt/c/Users/$USER/AppData/Local/Programs/Microsoft VS Code/bin/code
  if ! command -v code &> /dev/null; then
    echo "Error: The \"code\" command is not available. Install the \"WSL\" extension in Visual Studio Code and then re-run this script." >&2
    return 1
  fi

  local extensions_output
  if ! extensions_output=$(
    bunx json5 "$file_path" \
      | jq --raw-output "$jq_filter"
  ); then
    echo "Error: Failed to parse the Visual Studio Code extensions from: $file_path" >&2
    return 1
  fi

  local -a extensions
  mapfile -t extensions <<< "$extensions_output"

  local -A installed_extensions
  local installed_extension
  while IFS= read -r installed_extension; do
    installed_extensions["${installed_extension,,}"]=1
  done < <(code --list-extensions)

  local extension
  for extension in "${extensions[@]}"; do
    if [[ -z "${installed_extensions[${extension,,}]:-}" ]]; then
      echo "Installing Visual Studio Code extension: $extension"
      code --install-extension "$extension"
    fi
  done
}

# endregion

# region: Main setup
# ----------
# Main setup
# ----------

# Update the system.
sudo apt-get update -qq
sudo apt-get upgrade -qq --yes
sudo apt-get auto-remove -qq --yes

# Install some operating system packages.
declare -a packages=(
  "age"
  "bind9-dnsutils"
  "build-essential"
  "git-delta"
  "gvproxy" # Needed for "podman machine start" to work.
  "jq"
  "podman"
  "python-is-python3"
  "qemu-system-x86" # Required for "podman machine init" to work.
  "ripgrep"
  "shellcheck"
  "tree"
  "unzip"
  "virtiofsd" # Needed for "podman machine start" to work.
)

for package in "${packages[@]}"; do
  if ! dpkg -s "$package" > /dev/null 2>&1; then
    echo "Installing aptitude package: $package"
    sudo apt-get install -qq --yes "$package"
  fi
done

# Set up the company certificate.
if [[ $PERSONAL == "false" ]]; then
  CERT_PATH="/usr/local/share/ca-certificates/BEDROOTCA001.crt"
  if [[ ! -s "$CERT_PATH" ]]; then
    echo "Installing the LogixHealth certificate to: $CERT_PATH"
    sudo curl --silent --fail --show-error --location http://certs.logixhealth.com/BEDROOTCA001.crt --output "$CERT_PATH"
    sudo update-ca-certificates
  fi
fi

# Set up SSH.
mkdir -p "$HOME/.ssh"
if is-james; then
  PRIVATE_KEY_FILE_NAME="id_ed25519"
  PUBLIC_KEY_FILE_NAME="$PRIVATE_KEY_FILE_NAME.pub"

  HOST_SSH_DIRECTORY_PATH="/mnt/c/Users/$USER/.ssh"
  GUEST_SSH_DIRECTORY_PATH="$HOME/.ssh"
  mkdir -p "$GUEST_SSH_DIRECTORY_PATH"

  SSH_PRIVATE_KEY_PATH_PERSONAL="$GUEST_SSH_DIRECTORY_PATH/$PRIVATE_KEY_FILE_NAME"
  if [[ ! -s "$SSH_PRIVATE_KEY_PATH_PERSONAL" ]]; then
    echo "Installing the private SSH key (personal) to: $SSH_PRIVATE_KEY_PATH_PERSONAL"
    cp "$HOST_SSH_DIRECTORY_PATH/$PRIVATE_KEY_FILE_NAME" "$SSH_PRIVATE_KEY_PATH_PERSONAL"
    chmod 600 "$SSH_PRIVATE_KEY_PATH_PERSONAL"
  fi

  SSH_PUBLIC_KEY_PATH_PERSONAL="$GUEST_SSH_DIRECTORY_PATH/$PUBLIC_KEY_FILE_NAME"
  if [[ ! -s "$SSH_PUBLIC_KEY_PATH_PERSONAL" ]]; then
    echo "Installing the public SSH key (personal) to: $SSH_PUBLIC_KEY_PATH_PERSONAL"
    cp "$HOST_SSH_DIRECTORY_PATH/$PUBLIC_KEY_FILE_NAME" "$SSH_PUBLIC_KEY_PATH_PERSONAL"
  fi

  if [[ $PERSONAL == "false" ]]; then
    PRIVATE_KEY_FILE_NAME_WORK="id_rsa"
    PUBLIC_KEY_FILE_NAME_WORK="$PRIVATE_KEY_FILE_NAME_WORK.pub"

    HOST_SSH_DIRECTORY_PATH_WORK="$HOST_SSH_DIRECTORY_PATH/work"
    GUEST_SSH_DIRECTORY_PATH_WORK="$GUEST_SSH_DIRECTORY_PATH/work"
    mkdir -p "$GUEST_SSH_DIRECTORY_PATH_WORK"

    SSH_PRIVATE_KEY_PATH_WORK="$GUEST_SSH_DIRECTORY_PATH_WORK/$PRIVATE_KEY_FILE_NAME_WORK"
    if [[ ! -s "$SSH_PRIVATE_KEY_PATH_WORK" ]]; then
      echo "Installing the private SSH key (work) to: $SSH_PRIVATE_KEY_PATH_WORK"
      cp "$HOST_SSH_DIRECTORY_PATH_WORK/$PRIVATE_KEY_FILE_NAME_WORK" "$SSH_PRIVATE_KEY_PATH_WORK"
      chmod 600 "$SSH_PRIVATE_KEY_PATH_WORK"
    fi

    SSH_PUBLIC_KEY_PATH_WORK="$GUEST_SSH_DIRECTORY_PATH_WORK/$PUBLIC_KEY_FILE_NAME"
    if [[ ! -s "$SSH_PUBLIC_KEY_PATH_WORK" ]]; then
      echo "Installing the public SSH key (work) to: $SSH_PUBLIC_KEY_PATH_WORK"
      cp "$HOST_SSH_DIRECTORY_PATH_WORK/$PUBLIC_KEY_FILE_NAME_WORK" "$SSH_PUBLIC_KEY_PATH_WORK"
    fi
  fi
fi

# Before installing things, add the standard binary location to the PATH.
export PATH="$HOME/.local/bin:$PATH"

# endregion

# region: Install programming languages
# -----------------------------
# Install programming languages
# -----------------------------

# Install Golang.
# https://go.dev/doc/install
if [[ ! -x "/usr/local/go/bin/go" ]]; then
  echo "Installing Golang."
  LATEST_GO_VERSION=$(curl --silent --fail --show-error --location https://go.dev/VERSION?m=text | head --lines=1)
  curl --silent --fail --location --output /tmp/go.tar.gz "https://go.dev/dl/$LATEST_GO_VERSION.linux-amd64.tar.gz"
  sudo tar -C /usr/local -xzf /tmp/go.tar.gz
  rm /tmp/go.tar.gz
  export PATH="/usr/local/go/bin:$PATH"
fi

# Install fnm.
# https://github.com/Schniz/fnm
if [[ ! -x "$HOME/.local/share/fnm/fnm" ]]; then
  echo "Installing fnm and Node.js."

  # The "--skip-shell" is necessary to prevent fnm from modifying the ".bashrc" file.
  curl --silent --fail --show-error --location https://fnm.vercel.app/install | bash -s -- --skip-shell

  # Add it to PATH for the current session.
  export PATH="$HOME/.local/share/fnm:$PATH"
  eval "$(fnm env --shell bash)"

  fnm install --lts
fi

# Install pnpm.
# https://pnpm.io/installation#on-posix-systems
if [[ ! -x "$HOME/.local/share/pnpm/bin/pnpm" ]]; then
  echo "Installing pnpm."
  install-pnpm() {
    curl --silent --fail --show-error --location https://get.pnpm.io/install.sh | sh
  }
  #run-with-preserved-bashrc install-pnpm
  install-pnpm # TODO
  export PATH="$HOME/.local/share/pnpm/bin:$PATH"
fi

# Install Bun.
# https://bun.sh/
# (This is needed before cloning repositories so that we can install the dependencies at the same
# time.)
if [[ ! -x "$HOME/.bun/bin/bun" ]]; then
  echo "Installing bun."
  install-bun() {
    curl --silent --fail --show-error --location https://bun.com/install | bash
  }
  #run-with-preserved-bashrc install-bun
  install-bun # TODO
  export PATH="$HOME/.bun/bin:$PATH"
fi

# Install uv.
# https://docs.astral.sh/uv/getting-started/installation/
if [[ ! -x "$HOME/.local/bin/uv" ]]; then
  echo "Installing uv."
  install-uv() {
    curl --silent --fail --show-error --location https://astral.sh/uv/install.sh | sh
  }
  #run-with-preserved-bashrc install-uv
  install-uv # TODO
fi

# Install PowerShell.
# https://learn.microsoft.com/en-us/powershell/scripting/install/install-ubuntu
if [[ ! -x "/usr/bin/pwsh" ]]; then
  echo "Installing PowerShell."
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

# Install Rust.
# https://rust-lang.org/tools/install/
if [[ ! -x "$HOME/.cargo/bin/rustup" ]]; then
  echo "Installing Rust."
  curl --silent --fail --show-error --location --proto '=https' --tlsv1.2 https://sh.rustup.rs | sh -s -- -y --no-modify-path
  # shellcheck source=/dev/null
  source "$HOME/.cargo/env"
fi

# endregion

# region: Install quality of life software
# --------------------------------
# Install quality of life software
# --------------------------------

# Install zoxide.
# https://github.com/ajeetdsouza/zoxide
if [[ ! -x "$HOME/.local/bin/zoxide" ]]; then
  echo "Installing zoxide."
  curl --silent --fail --show-error --location https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
fi

# Install fzf.
# https://github.com/junegunn/fzf
if [[ ! -x "$HOME/.local/fzf" ]]; then
  echo "Installing fzf."
  DOWNLOAD_URL=$(get-github-latest-release-url "junegunn/fzf" "fzf-{version}-linux_amd64.tar.gz")
  install-binary-from-tar-url "$DOWNLOAD_URL" "fzf"
fi

# endregion

# region: Install tools
# -------------
# Install tools
# -------------

# Install the GitHub CLI.
# https://github.com/cli/cli/blob/trunk/docs/install_linux.md#debian
if [[ ! -x /usr/bin/gh ]]; then
  echo "Installing the GitHub CLI."
  sudo mkdir -p -m 755 /etc/apt/keyrings
  curl --silent --fail --show-error --location https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
  sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  sudo mkdir -p -m 755 /etc/apt/sources.list.d
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
  sudo apt-get update
  sudo apt-get install gh --yes

  # By default, the GitHub CLI will use HTTPS as the protocol when checking out pull requests.
  /usr/bin/gh config set git_protocol ssh --host github.com
fi

# Install the GitHub Copilot CLI.
# https://github.com/features/copilot/cli/
if [[ ! -x "$HOME/.local/bin/copilot" ]]; then
  echo "Installing the GitHub Copilot CLI."

  # We need to supply "PREFIX" to prevent the installer from prompting us about adding itself to the
  # PATH.
  COPILOT_CERT_ARGS=()
  if [[ $PERSONAL == "false" ]]; then
    COPILOT_CERT_ARGS+=(--cacert "$CERT_PATH")
  fi

  curl --silent --fail --show-error --location "${COPILOT_CERT_ARGS[@]}" https://gh.io/copilot-install \
    | PREFIX="$HOME/.local" bash
fi

# Install the Codex CLI.
# https://learn.chatgpt.com/docs/codex/cli#getting-started
if [[ ! -x "$HOME/.local/bin/codex" ]]; then
  echo "Installing the Codex CLI."
  install-codex-cli() {
    curl --silent --fail --show-error --location https://chatgpt.com/codex/install.sh | CODEX_NON_INTERACTIVE=1 sh
  }
  #run-with-preserved-bashrc install-codex-cli
  install-codex-cli # TODO
fi

# Install OpenCode.
if [[ ! -x "$HOME/.opencode/bin/opencode" ]]; then
  echo "Installing OpenCode."
  curl --silent --fail --show-error --location https://opencode.ai/install | bash -s -- --no-modify-path
fi

# Install the Azure CLI.
# https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-linux?view=azure-cli-latest&pivots=apt#option-1-install-with-one-command
if [[ ! -x /usr/bin/az ]]; then
  echo "Installing the Azure CLI."
  curl --silent --fail --show-error --location https://aka.ms/InstallAzureCLIDeb | sudo bash

  if [[ $PERSONAL == "false" ]]; then
    # Install the LogixHealth certificate.
    REQUESTS_CA_BUNDLE=$("/opt/az/bin/python3" -c "import certifi; print(certifi.where())")
    if [[ ! -s "$REQUESTS_CA_BUNDLE" ]]; then
      echo "Error: Failed to find the Azure CLI CA bundle at: $REQUESTS_CA_BUNDLE" >&2
      exit 1
    fi

    export REQUESTS_CA_BUNDLE
    CERTIFICATE_NAME="BEDROOTCA001"
    {
      echo
      echo "# $CERTIFICATE_NAME"
      curl --silent --fail --show-error --location "http://certs.logixhealth.com/$CERTIFICATE_NAME.crt"
    } | sudo tee -a "$REQUESTS_CA_BUNDLE" > /dev/null
  fi
fi

# Install Terraform.
# https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli
if [[ ! -x /usr/bin/terraform ]]; then
  echo "Installing Terraform."
  curl --silent --fail --show-error --location https://apt.releases.hashicorp.com/gpg \
    | gpg --dearmor \
    | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
    | sudo tee /etc/apt/sources.list.d/hashicorp.list
  sudo apt-get update
  sudo apt-get install terraform --yes
fi

# Install TFLint.
# https://github.com/terraform-linters/tflint
if [[ ! -x "$HOME/.local/bin/tflint" ]]; then
  echo "Installing TFLint."
  TFLINT_ZIP_PATH="/tmp/tflint_linux_amd64.zip"
  TFLINT_CHECKSUMS_PATH="/tmp/tflint_checksums.txt"
  curl --silent --fail --show-error --location --output "$TFLINT_ZIP_PATH" \
    https://github.com/terraform-linters/tflint/releases/latest/download/tflint_linux_amd64.zip
  curl --silent --fail --show-error --location --output "$TFLINT_CHECKSUMS_PATH" \
    https://github.com/terraform-linters/tflint/releases/latest/download/checksums.txt
  (cd /tmp && sha256sum --ignore-missing --check "$TFLINT_CHECKSUMS_PATH")
  unzip -o "$TFLINT_ZIP_PATH" -d /tmp
  TFLINT_BINARY_PATH="/tmp/tflint"
  install --verbose "$TFLINT_BINARY_PATH" "$HOME/.local/bin/"
  rm "$TFLINT_ZIP_PATH" "$TFLINT_CHECKSUMS_PATH" "$TFLINT_BINARY_PATH"
fi

# Install `terraform-docs`.
# https://github.com/terraform-docs/terraform-docs
if [[ ! -x "$HOME/.local/bin/terraform-docs" ]]; then
  echo "Installing terraform-docs."
  DOWNLOAD_URL=$(get-github-latest-release-url "terraform-docs/terraform-docs" "terraform-docs-v{version}-linux-amd64.tar.gz")
  install-binary-from-tar-url "$DOWNLOAD_URL" "terraform-docs"
fi

# Install Pulumi.
if [[ ! -x "$HOME/.pulumi/bin/pulumi" ]]; then
  echo "Installing Pulumi."
  curl --silent --fail --show-error --location https://get.pulumi.com | sh
  export PATH="$HOME/.pulumi/bin:$PATH"
fi

# Install kubectl and kubelogin.
# https://learn.microsoft.com/en-us/cli/azure/aks?view=azure-cli-latest#az-aks-install-cli
# The latest kubectl version is listed at: https://kubernetes.io/releases/
# The latest kubelogin version is listed at: https://github.com/Azure/kubelogin/releases
# The "SSL_CERT_FILE" and "REQUESTS_CA_BUNDLE" are both needed to prevent the error:
# ERROR: Connection error while attempting to download client (<urlopen error [SSL: CERTIFICATE_VERIFY_FAILED] certificate verify failed: Missing Authority Key Identifier (_ssl.c:1032)>)
# The "--client-version" and "--kubelogin-version" flags are needed to prevent warnings from appearing.
if [[ ! -x "/usr/local/bin/kubectl" ]]; then
  echo "Installing kubectl and kubelogin."
  export KUBECTL_VERSION="1.35.2" \
    && export KUBELOGIN_VERSION="0.2.16" \
    && sudo az aks install-cli --client-version "$KUBECTL_VERSION" --kubelogin-version "$KUBELOGIN_VERSION"
fi

# Install kustomize.
if [[ ! -x "$HOME/.local/bin/kustomize" ]]; then
  echo "Installing kustomize."
  DOWNLOAD_URL=$(get-github-latest-release-url "kubernetes-sigs/kustomize" "kustomize_{tag_version}_linux_amd64.tar.gz")
  install-binary-from-tar-url "$DOWNLOAD_URL" "kustomize"
fi

# Install Helm.
# https://helm.sh/docs/intro/install/
if [[ ! -x "/usr/sbin/helm" ]]; then
  echo "Installing Helm."
  curl --silent --fail --show-error --location https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
  echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
  sudo apt-get update
  sudo apt-get install helm --yes
fi

# Install helmfmt.
# https://github.com/digitalstudium/helmfmt
if [[ ! -x "$HOME/.local/bin/helmfmt" ]]; then
  echo "Installing helmfmt."
  curl --silent --fail --show-error --location https://github.com/digitalstudium/helmfmt/releases/latest/download/helmfmt_Linux_x86_64.tar.gz | tar -xzf - -C "$HOME/.local/bin/" helmfmt
fi

# Install the OPA CLI.
# https://www.openpolicyagent.org/docs/cli
if [[ ! -x "$HOME/.local/bin/opa" ]]; then
  echo "Installing the OPA CLI."
  OPA_BINARY_PATH="/tmp/opa"
  curl --silent --fail --show-error --location --output "$OPA_BINARY_PATH" https://openpolicyagent.org/downloads/latest/opa_linux_amd64
  install --verbose "$OPA_BINARY_PATH" "$HOME/.local/bin/"
  rm "$OPA_BINARY_PATH"
fi

# endregion

# region: Repositories
# ------------
# Repositories
# ------------

# Clone personal repositories.
if ! ssh-keygen -F github.com &> /dev/null; then
  echo "Installing the GitHub SSH key."
  ssh-keyscan github.com >> "$HOME/.ssh/known_hosts" 2> /dev/null
fi
REPOSITORIES_DIR="$HOME/repositories"
mkdir -p "$REPOSITORIES_DIR"
cd "$REPOSITORIES_DIR"
if [[ ! -d "$REPOSITORIES_DIR/configs" ]]; then
  echo "Cloning the \"configs\" repository."
  if [[ -s "$HOME/.ssh/id_ed25519" ]]; then
    git clone git@github.com:Zamiell/configs.git
  else
    git clone https://github.com/Zamiell/configs.git
  fi
  (cd "$REPOSITORIES_DIR/configs" && bun ci)
fi
if is-james; then
  if [[ ! -d "$REPOSITORIES_DIR/notes" ]]; then
    echo "Cloning the \"notes\" repository."
    git clone git@github.com:Zamiell/notes.git
  fi
  if [[ ! -d "$REPOSITORIES_DIR/secrets" ]]; then
    echo "Cloning the \"secrets\" repository."
    git clone git@github.com:Zamiell/secrets.git
  fi
fi

# Load Git settings.
"$REPOSITORIES_DIR/configs/bash/other/set-git-settings.sh"
if is-james; then
  if ! cmp --silent "$REPOSITORIES_DIR/configs/app-settings/ssh/config" "$HOME/.ssh/config"; then
    echo "Installing the SSH config to: $HOME/.ssh/config"
    cp "$REPOSITORIES_DIR/configs/app-settings/ssh/config" "$HOME/.ssh/config"
  fi
fi

# Load the Bash configs.
BASHRC_PATH="$HOME/.bashrc"
if ! grep --quiet "Load the commands from the \"configs\"" "$BASHRC_PATH"; then
  echo "Modifying: $BASHRC_PATH"
  # shellcheck disable=SC2016
  echo '
# Load the commands from the "configs" GitHub repository: https://github.com/Zamiell/configs
CONFIGS_REPO_PATH="$HOME/repositories/configs"
# shellcheck source=/dev/null
source "$CONFIGS_REPO_PATH/bash/bashrc.sh"
' >> "$BASHRC_PATH"
fi

# Install the wslview shim. (See the comments in the "wslview" script.)
if [[ ! -x "$HOME/.local/bin/wslview" ]]; then
  echo "Installing wslview."
  cp "$REPOSITORIES_DIR/configs/bash/other/wslview" "$HOME/.local/bin/wslview"
fi

# Decrypt environment variables.
if is-james && [[ ! -s "$HOME/.env" ]]; then
  echo "Decrypting: $HOME/.env"
  age --decrypt --identity "$HOME/.ssh/id_ed25519" --output "$HOME/.env" "$REPOSITORIES_DIR/secrets/.env.age"
  chmod 600 "$HOME/.env"
fi

# Clone work repositories.
if [[ $PERSONAL == "false" ]]; then
  if ! ssh-keygen -F azuredevops.logixhealth.com &> /dev/null; then
    echo "Installing the Azure DevOps Server SSH key."
    ssh-keyscan azuredevops.logixhealth.com >> "$HOME/.ssh/known_hosts" 2> /dev/null
  fi

  clone-work-repo "ssh://azuredevops.logixhealth.com:22/LogixHealth/Software%20Engineering/_git/allscripts-external"
  clone-work-repo "ssh://azuredevops.logixhealth.com:22/LogixHealth/Analytics%20and%20Innovation/_git/database-services"
  clone-work-repo "ssh://azuredevops.logixhealth.com:22/LogixHealth/Infrastructure/_git/infrastructure"
  clone-work-repo "ssh://azuredevops.logixhealth.com:22/LogixHealth/Software%20Engineering/_git/LogixApplications"

  if ! ssh-keygen -F ssh.dev.azure.com &> /dev/null; then
    echo "Installing the Azure DevOps Services SSH key."
    ssh-keyscan ssh.dev.azure.com >> "$HOME/.ssh/known_hosts" 2> /dev/null
  fi

  clone-work-repo "git@ssh.dev.azure.com:v3/logixhealth/Main/databricks-data"
fi

# endregion

# region: Configure applications
# ----------------------
# Configure applications
# ----------------------

# Set up podman.
if ! podman machine inspect podman-machine-default > /dev/null 2>&1; then
  echo "Setting up podman."

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

# Install Visual Studio Code extensions.
install-vscode-extensions "$REPOSITORIES_DIR/configs/.vscode/extensions.json"
if [[ $PERSONAL == "false" ]]; then
  install-vscode-extensions "$REPOSITORIES_DIR/infrastructure/infrastructure.code-workspace"
fi

# Install GitHub Copilot CLI settings.
if is-james; then
  if ! cmp --silent "$REPOSITORIES_DIR/configs/copilot/settings.json" "$HOME/.copilot/settings.json"; then
    echo "Installing: $HOME/.copilot/settings.json"
    mkdir -p "$HOME/.copilot"
    cp "$REPOSITORIES_DIR/configs/app-settings/copilot/settings.json" "$HOME/.copilot/settings.json"
  fi

  if ! cmp --silent "$REPOSITORIES_DIR/configs/copilot/hooks/sound.json" "$HOME/.copilot/hooks/sound.json"; then
    echo "Installing GitHub Copilot CLI settings: $HOME/.copilot/hooks/sound.json"
    mkdir -p "$HOME/.copilot/hooks"
    cp "$REPOSITORIES_DIR/configs/app-settings/copilot/hooks/sound.json" "$HOME/.copilot/hooks/sound.json"
  fi
fi

# endregion

echo -e "\nSuccessfully set up WSL."
