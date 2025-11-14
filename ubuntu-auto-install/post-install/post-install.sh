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
BW_CLIENTID="user.c73c6208-71e9-48f5-ac11-b3940010eeee"

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
  # Make the error message easy to see so that it does not get lost in the spam of the initial boot.
  echo "---------------------------------------------------------------"
  echo "Error: You must have an internet connection to run this script."
  echo "---------------------------------------------------------------"
  exit 1
fi

# ----------------
# Helper functions
# ----------------

bitwarden_login() {
  if [[ -n "${BW_SESSION:-}" ]]; then
    return
  fi

  if [[ -z "${BW_CLIENTSECRET:-}" ]]; then
    BITWARDEN_API_CLIENT_SECRET_PATH="/post-install/bitwarden_api_client_secret"
    if [[ -s "$BITWARDEN_API_CLIENT_SECRET_PATH" ]]; then
      BW_CLIENTSECRET=$(cat $BITWARDEN_API_CLIENT_SECRET_PATH)
    fi
  fi

  if [[ -z "${BW_PASSWORD:-}" ]]; then
    BITWARDEN_MASTER_PASSWORD_PATH="/post-install/bitwarden_master_password"
    if [[ -s "$BITWARDEN_MASTER_PASSWORD_PATH" ]]; then
      BW_PASSWORD=$(cat $BITWARDEN_MASTER_PASSWORD_PATH)
    else
      # "-s" is for silent mode, which hides the input.
      # "-r" is recommended by shellcheck.
      # "-p" is to provide a prompt.
      read -s -r -p "Type in your BitWarden master password: " BW_PASSWORD
    fi
  fi

  if ! bw login --check &> /dev/null; then
    if [[ -n "${BW_CLIENTSECRET:-}" ]]; then
      set +x
      BW_CLIENTID="$BW_CLIENTID" BW_CLIENTSECRET="$BW_CLIENTSECRET" bw login --apikey
      set -x
    else
      set +x
      echo "$BW_PASSWORD" | bw login "$PERSONAL_EMAIL"
      set -x
    fi
  fi

  set +x
  BW_SESSION=$(echo "$BW_PASSWORD" | bw unlock --raw)
  set -x

  if [[ -z "$BW_SESSION" ]]; then
    echo "Error: Failed to get a BitWarden session key." >&2
    return 1
  fi
}

# -----------------
# Phase 1 - Pre-GUI
# -----------------

# Load information about the system for later.
# shellcheck source=/dev/null
source /etc/os-release

# Set the timezone.
sudo timedatectl set-timezone America/New_York

# Patch the OS.
sudo apt-get update
sudo apt-get upgrade --yes

# Install SSH.
# https://documentation.ubuntu.com/server/how-to/security/openssh-server/index.html
if ! dpkg --status openssh-server &> /dev/null; then
  sudo apt-get install openssh-server --yes
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

# Set up environment variables.
ENV_PATH="$HOME/.env"
if [[ ! -s "$ENV_PATH" ]]; then
  bitwarden_login
  bw get notes .env --session "$BW_SESSION" > "$ENV_PATH"
  echo >> "$ENV_PATH"
fi
# shellcheck source=/dev/null
source "$ENV_PATH"

# Set up SSH keys.
mkdir --parents "$HOME/.ssh"
PRIVATE_KEY_PATH="$HOME/.ssh/id_rsa"
if [[ ! -s "$PRIVATE_KEY_PATH" ]]; then
  bitwarden_login
  bw get notes ssh-private-key --session "$BW_SESSION" > "$PRIVATE_KEY_PATH"
  echo >> "$PRIVATE_KEY_PATH"
  chmod 600 "$PRIVATE_KEY_PATH"
fi
PUBLIC_KEY_PATH="$HOME/.ssh/id_rsa.pub"
if [[ ! -s "$PUBLIC_KEY_PATH" ]]; then
  bitwarden_login
  bw get notes ssh-public-key --session "$BW_SESSION" > "$PUBLIC_KEY_PATH"
  echo >> "$PUBLIC_KEY_PATH"
fi

# Install Git.
if ! command -v git &> /dev/null; then
  sudo apt-get install git --yes
  git config --global user.name "$FULL_NAME"
  git config --global user.email "$WORK_EMAIL"
fi

# Install the GitHub CLI.
if ! command -v gh &> /dev/null; then
  # From: https://github.com/cli/cli/blob/trunk/docs/install_linux.md#debian
  (type -p wget &> /dev/null || (sudo apt-get update && sudo apt-get install wget --yes)) \
    && sudo mkdir -p -m 755 /etc/apt/keyrings \
    && out=$(mktemp) && wget -nv "-O$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    && cat "$out" | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg &> /dev/null \
    && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && sudo mkdir -p -m 755 /etc/apt/sources.list.d \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list &> /dev/null \
    && sudo apt-get update \
    && sudo apt-get install gh --yes

  # gh uses HTTPS by default.
  gh config set git_protocol ssh

  if [[ -z "$GH_TOKEN" ]]; then
    echo "Error: The \"GH_TOKEN\" environment variable is empty. This is needed by the \"gh\" command to authenticate to GitHub. It should be present in the \".env\" file (which comes from BitWarden)." >&2
    exit 1
  fi
fi

# Install the public key for "github.com".
KNOWN_HOSTS_PATH="$HOME/.ssh/known_hosts"
if ! grep --quiet github.com "$KNOWN_HOSTS_PATH"; then
  ssh-keyscan github.com >> "$KNOWN_HOSTS_PATH"
fi

# Set up the "repositories" directory.
REPOSITORIES_PATH="$HOME/repositories"
mkdir --parents "$REPOSITORIES_PATH"

CONFIGS_PATH="$REPOSITORIES_PATH/configs"
if [[ -d "$CONFIGS_PATH" ]]; then
  # Make sure this repository is up to date.
  git -C "$CONFIGS_PATH" pull
else
  # Clone this repository.
  gh repo clone Zamiell/configs "$CONFIGS_PATH"
  git -C "$CONFIGS_PATH" config user.name "$GITHUB_USERNAME"
  git -C "$CONFIGS_PATH" config user.email "$GITHUB_EMAIL"
fi

# Install the remote configs from this repository.
BASHRC_PATH="$HOME/.bashrc"
if ! grep --quiet BASH_PROFILE_REMOTE_PATH "$BASHRC_PATH"; then
  echo >> "$BASHRC_PATH"
  cp "$CONFIGS_PATH/bash/.bash_profile" "$BASHRC_PATH"
fi

# -------------
# Phase 2 - GUI
# -------------

# Install KDE Plasma.
if ! dpkg --status kde-plasma-desktop &> /dev/null; then
  sudo apt-get install kde-plasma-desktop --yes
fi

# On Ubuntu, Netplan is the default system for configuring network interfaces, but KDE's network
# app is part of the NetworkManager framework and only shows connections it manages. Thus, we need
# to pass control to NetworkManager.
sudo cp "$CONFIGS_PATH/ubuntu-auto-install/post-install/etc/netplan/01-network-manager.yaml" /etc/netplan/

# Copy the Simple Desktop Display Manager (SDDM) config. (SDDM is the login manager.)
sudo cp "$CONFIGS_PATH/ubuntu-auto-install/post-install/etc/sddm.conf" /etc/

# Disable Bluetooth. (This will automatically remove the Bluetooth icon from the system tray.)
sudo systemctl disable bluetooth.service
sudo systemctl stop bluetooth.service

# Disable Discover. (This will automatically remove the "Updates" icon from the system tray.)
# https://old.reddit.com/r/kde/comments/f2bquo/how_to_stop_discover_from_autostarting/
# - Normally, icons in the system tray can be removed by deleting the corresponding entry from the
#   "extraItems" key. However, "Updates" is a special case, because it has no corresponding entry.
# - We do not need Discover because we will handle system updates manually.
mkdir --parents ~/.config/autostart
cp /etc/xdg/autostart/org.kde.discover.notifier.desktop ~/.config/autostart/
echo "Hidden=true" >> ~/.config/autostart/org.kde.discover.notifier.desktop

# The rest of GUI configuration uses the `kwriteconfig5` command, which requires that the user has
# logged on to the system at least once so that the relevant files in the ".config" directory get
# created. This script should be executed again on the next boot. (It is designed to be idempotent.)
if [[ -s "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" ]]; then
  # In order to find the files corresponding to GUI settings, use this command:
  # find ~/.config -type f -mmin -1

  # Right click start menu / application launcher --> Configure Application Launcher --> General -->
  # Icon --> Choose --> Browse --> [png file]
  cp "$CONFIGS_PATH/ubuntu-auto-install/post-install/.config/windows10.png" "$HOME/.config/"
  kwriteconfig5 --file plasma-org.kde.plasma.desktop-appletsrc --group Containments --group 2 --group Applets --group 3 --group Configuration --group General --key icon /home/jnesta/.config/windows10.png

  # Right click taskbar --> Enter Edit Mode --> Mouse over system tray --> Configure --> Entries -->
  # Check "Always show all entries"
  kwriteconfig5 --file plasma-org.kde.plasma.desktop-appletsrc --group Containments --group 8 --group General --key showAllItems true

  # By default, the following icons are shown:
  # - Volume (org.kde.plasma.volume)
  # - Networks (org.kde.plasma.networkmanagement)
  # By default, the following icons are hidden:
  # - Notifications (org.kde.plasma.notifications)
  # - Updates (Discover Notifier_org.kde.DiscoverNotifier)
  # - Clipboard (org.kde.plasma.clipboard)
  # - Vaults (org.kde.plasma.vault)
  # - Battery and Brightness (org.kde.plasma.battery)
  # - Disks & Devices (org.kde.plasma.devicenotifier)
  # - Display Configuration (org.kde.kscreen)
  # Now that every icon is shown from the previous change, we can get rid of the specific ones that we
  # do not want to see. "extraItems" controls which applets are actually shown in the system tray. The
  # default value is:
  # org.kde.plasma.networkmanagement,org.kde.plasma.manage-inputmethod,org.kde.plasma.mediacontroller,org.kde.plasma.devicenotifier,org.kde.plasma.keyboardlayout,org.kde.kupapplet,org.kde.plasma.volume,org.kde.plasma.bluetooth,org.kde.plasma.battery,org.kde.plasma.clipboard,org.kde.plasma.vault,org.kde.plasma.notifications,org.kde.kscreen
  # We want to remove the following:
  # - Notifications (org.kde.plasma.notifications)
  # - Clipboard (org.kde.plasma.clipboard)
  # - Vaults (org.kde.plasma.vault)
  # - Display Configuration (org.kde.kscreen)
  kwriteconfig5 --file plasma-org.kde.plasma.desktop-appletsrc --group Containments --group 8 --group General --key extraItems "org.kde.plasma.networkmanagement,org.kde.plasma.manage-inputmethod,org.kde.plasma.mediacontroller,org.kde.plasma.devicenotifier,org.kde.plasma.keyboardlayout,org.kde.kupapplet,org.kde.plasma.volume,org.kde.plasma.bluetooth,org.kde.plasma.battery"

  # Right click clock --> Configure Digital Clock --> Appearance --> Uncheck "Show date"
  kwriteconfig5 --file plasma-org.kde.plasma.desktop-appletsrc --group Containments --group 2 --group Applets --group 17 --group Configuration --group Appearance --key showDate false

  # Right click clock --> Configure Digital Clock --> Appearance --> Text display: Manual (8pt Noto Sans)
  # (The default is 10pt Noto Sans.)
  kwriteconfig5 --file plasma-org.kde.plasma.desktop-appletsrc --group Containments --group 2 --group Applets --group 17 --group Configuration --group Appearance --key autoFontAndSize false
  kwriteconfig5 --file plasma-org.kde.plasma.desktop-appletsrc --group Containments --group 2 --group Applets --group 17 --group Configuration --group Appearance --key fontFamily "Noto Sans"
  kwriteconfig5 --file plasma-org.kde.plasma.desktop-appletsrc --group Containments --group 2 --group Applets --group 17 --group Configuration --group Appearance --key fontSize 8
  kwriteconfig5 --file plasma-org.kde.plasma.desktop-appletsrc --group Containments --group 2 --group Applets --group 17 --group Configuration --group Appearance --key fontStyleName Regular

  # Get rid of the "Peek at Desktop" button in the bottom-right corner.
  PLASMASHELL_METHOD="org.kde.PlasmaShell.evaluateScript"
  if qdbus org.kde.plasmashell /PlasmaShell | grep --quiet "$PLASMASHELL_METHOD"; then
    qdbus org.kde.plasmashell /PlasmaShell "$PLASMASHELL_METHOD" "panels()[0].widgets().forEach(w => { if (w.type == 'org.kde.plasma.showdesktop') w.remove() })"
  fi

  # Settings --> Workspace Behavior --> Screen Locking --> Uncheck "After 5 minutes"
  kwriteconfig5 --file kscreenlockerrc --group Daemon --key Autolock false

  # Settings --> Input Devices --> Touchpad --> Right-click -->
  # Change "Press bottom-right-corner" to "Press anywhere with two fingers"
  kwriteconfig5 --file touchpadxlibinputrc --group "VEN_0488:00 0488:104B Touchpad" --key clickMethodAreas false
  kwriteconfig5 --file touchpadxlibinputrc --group "VEN_0488:00 0488:104B Touchpad" --key clickMethodClickfinger true

  # KDialog --> Options (in top-right corner) --> Check "Show Hidden Files"
  kwriteconfig5 --file kdeglobals --group "KFileDialog Settings" --key "Show hidden files" true

  # Unfortunately, "systemctl restart --user plasma-plasmashell.service" does not work to make some
  # GUI setting changes take effect, so we have to wait for the next reboot. (This was tested with the
  # touchpad change.)
fi

# ----------------------
# Phase 3 - Applications
# ----------------------

# Install Variety. (This is similar to Bing Wallpaper for Windows.)
if ! dpkg --status variety &> /dev/null; then
  sudo apt-get install variety --yes
  # TODO: Configure it
fi

# Install the Microsoft package signing key. (This is needed for Edge and Intune.)
MICROSOFT_GPG_KEY_PATH="/usr/share/keyrings/microsoft-edge.gpg"
if [[ ! -s "$MICROSOFT_GPG_KEY_PATH" ]]; then
  curl --silent --fail --show-error --location https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee "$MICROSOFT_GPG_KEY_PATH" > /dev/null
fi

# Install Microsoft Edge.
MICROSOFT_EDGE_REPOSITORY_PATH="/etc/apt/sources.list.d/microsoft-edge.list"
if [[ ! -s "$MICROSOFT_EDGE_REPOSITORY_PATH" ]]; then
  echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-edge.gpg] https://packages.microsoft.com/repos/edge stable main' | sudo tee "$MICROSOFT_EDGE_REPOSITORY_PATH" > /dev/null
  sudo apt-get update
fi
if ! dpkg --status microsoft-edge-stable &> /dev/null; then
  sudo apt-get install microsoft-edge-stable --yes
fi

# Install Google Chrome.
if ! dpkg --status google-chrome-stable &> /dev/null; then
  GOOGLE_CHROME_PATH="/tmp/google-chrome.deb"
  curl --silent --fail --show-error --location --output "$GOOGLE_CHROME_PATH" https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
  sudo apt-get install "$GOOGLE_CHROME_PATH" --yes
  rm "$GOOGLE_CHROME_PATH"
fi

# Install Firefox.
if ! snap info firefox | grep -q "^installed:"; then
  sudo snap install firefox
fi

# Install Microsoft Intune.
if ! dpkg --status packages-microsoft-prod &> /dev/null; then
  MICROSOFT_LINUX_REPOSITORY_PATH="/tmp/packages-microsoft-prod.deb"
  curl --silent --fail --show-error --location --output "$MICROSOFT_LINUX_REPOSITORY_PATH" "https://packages.microsoft.com/config/$ID/$VERSION_ID/packages-microsoft-prod.deb"
  sudo apt-get install "$MICROSOFT_LINUX_REPOSITORY_PATH" --yes
  rm "$MICROSOFT_LINUX_REPOSITORY_PATH"
  sudo apt-get update
fi
if ! dpkg --status intune-portal &> /dev/null; then
  sudo apt-get install intune-portal --yes
fi

# Install the VPN client.
if [[ ! -s "/etc/apt/sources.list.d/yuezk-ubuntu-globalprotect-openconnect-noble.sources" ]]; then
  sudo add-apt-repository ppa:yuezk/globalprotect-openconnect --yes
fi
if ! dpkg --status globalprotect-openconnect &> /dev/null; then
  sudo apt-get install globalprotect-openconnect --yes
fi
# TODO: VPN script?

# -------
# Cleanup
# -------

# Stop the automatic execution of this script.
PROFILE_MARKER="--- TEMP ---" # This has to match the command in "autoinstall.yaml".
PROFILE_PATH="$HOME/.profile"
if grep --quiet --regexp "$PROFILE_MARKER" "$PROFILE_PATH"; then
  sed --in-place "/$PROFILE_MARKER/,/$PROFILE_MARKER/d" "$PROFILE_PATH"
fi

POST_INSTALL_PATH="/post-install"
if [[ -d "$POST_INSTALL_PATH" ]]; then
  sudo rm -rf "$POST_INSTALL_PATH"
fi

# Enable the sudo password. (We only needed it to be disabled in order to run this script without
# any prompts.)
SUDOERS_FILE_PATH="/etc/sudoers.d/90-cloud-init-users"
if [[ -f "$SUDOERS_FILE_PATH" ]]; then
  sudo rm "$SUDOERS_FILE_PATH"
fi

# Some changes to GUI settings require a reboot to take effect.
reboot
