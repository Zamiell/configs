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
if ! curl --silent --fail --show-error --location https://www.google.com &> /dev/null; then
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
  # Disable command echoing in this function to prevent sensitive information from showing on the
  # screen.
  set +x

  if [[ -n "${BW_SESSION:-}" ]]; then
    set -x
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
      read -s -r -p "Type in your BitWarden master password and press enter. (The input will be masked.) " BW_PASSWORD && echo
    fi
  fi

  export BW_CLIENTID
  export BW_CLIENTSECRET
  export BW_PASSWORD

  if ! bw login --check &> /dev/null; then
    if [[ -n "${BW_CLIENTSECRET:-}" ]]; then
      bw login --apikey
    else
      bw login "$PERSONAL_EMAIL" --passwordenv BW_PASSWORD
    fi
  fi

  BW_SESSION=$(bw unlock --raw --passwordenv BW_PASSWORD)

  unset BW_CLIENTID
  unset BW_CLIENTSECRET
  unset BW_PASSWORD

  if [[ -z "$BW_SESSION" ]]; then
    echo "Error: Failed to get a BitWarden session key." >&2
    set -x
    return 1
  fi

  set -x
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
NETWORK_MANAGER_YAML_PATH="/etc/netplan/01-network-manager.yaml"
if [[ ! -s "$NETWORK_MANAGER_YAML_PATH" ]]; then
  sudo cp "$CONFIGS_PATH/ubuntu-auto-install/post-install/etc/netplan/01-network-manager.yaml" "$NETWORK_MANAGER_YAML_PATH"
  sudo netplan apply
  sudo systemctl stop systemd-networkd-wait-online.service
  sudo systemctl disable systemd-networkd-wait-online.service
  sudo systemctl stop systemd-networkd.service
  sudo systemctl disable systemd-networkd.service
  sudo systemctl enable NetworkManager.service
  sudo systemctl start NetworkManager.service
  sudo systemctl enable NetworkManager-wait-online.service
fi

# Copy the Simple Desktop Display Manager (SDDM) config. (SDDM is the login manager.)
# (This handles automatic login.)
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
# created.
FIRST_LOGIN_SETUP_DESKTOP_PATH="$HOME/.config/autostart/first-login-setup.desktop"
if [[ -s "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" ]]; then
  # In order to find the files corresponding to GUI settings, use this command:
  # find ~/.config -type f -mmin -1

  # ------------------------------------------
  # Start Menu + Taskbar + System Tray + Clock
  # ------------------------------------------

  # Changing the configuration for these things from the CLI is brittle because the numeric
  # groupings can change. Thus, we revert to setting things up in the way that we want and then
  # backing up the configuration file.
  cp "$CONFIGS_PATH/ubuntu-auto-install/post-install/.config/windows10.png" "$HOME/.config/"
  cp "$CONFIGS_PATH/ubuntu-auto-install/post-install/.config/plasma-org.kde.plasma.desktop-appletsrc" "$HOME/.config/"

  # Start Menu:
  # - Right click start menu / application launcher --> Configure Application Launcher --> General
  #   --> Icon --> Choose --> Browse --> [windows10.png]

  # Taskbar:
  # - Replace the "Icons-only Task Manager" widget with "Task Manager".

  # System Tray:
  # - Right click taskbar --> Enter Edit Mode --> Mouse over system tray --> Configure --> Entries
  #   --> Check "Always show all entries"

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
  # Now that every icon is shown from the previous change, we can get rid of the specific ones that
  # we do not want to see. "extraItems" controls which applets are actually shown in the system
  # tray. The default value is:
  # org.kde.plasma.networkmanagement,org.kde.plasma.manage-inputmethod,org.kde.plasma.mediacontroller,org.kde.plasma.devicenotifier,org.kde.plasma.keyboardlayout,org.kde.kupapplet,org.kde.plasma.volume,org.kde.plasma.bluetooth,org.kde.plasma.battery,org.kde.plasma.clipboard,org.kde.plasma.vault,org.kde.plasma.notifications,org.kde.kscreen
  # We want to remove the following:
  # - Notifications (org.kde.plasma.notifications)
  # - Clipboard (org.kde.plasma.clipboard)
  # - Vaults (org.kde.plasma.vault)
  # - Display Configuration (org.kde.kscreen)

  # Clock:
  # - Right click clock --> Configure Digital Clock --> Appearance --> Uncheck "Show date"
  # - Right click clock --> Configure Digital Clock --> Appearance --> Text display: Manual (8pt
  #   Noto Sans)
  #   (The default is 10pt Noto Sans.)

  # Other:
  # - Removed "Peek at Desktop".
  # - Removed pinned applications.

  # --------
  # Explorer
  # --------

  # KDialog --> Options (in top-right corner) --> Check "Show Hidden Files"
  kwriteconfig5 --file kdeglobals --group "KFileDialog Settings" --key "Show hidden files" true

  # ------------------
  # Appearance / Theme
  # ------------------

  # System Settings --> Window Management --> Task Switcher --> Change "Breeze" to "ClassicKDE".
  # This changes the Alt-Tab UI to something simpler and faster.
  # From: https://store.kde.org/p/2024371
  if [[ $(kreadconfig5 --file kwinrc --group TabBox --key LayoutName) == "ClassicKde" ]]; then
    kpackagetool5 --type KWin/WindowSwitcher --install "$CONFIGS_PATH/ubuntu-auto-install/post-install/misc/ClassicKde.tar.gz"
    kwriteconfig5 --file kwinrc --group TabBox --key LayoutName ClassicKde
    # (This requires a reboot to take effect.)
  fi

  # System Settings --> Appearance --> Cursors --> Change "Breeze" to "PRA-DMZ".
  # This changes the cursors to Windows 10 cursors.
  # From: https://store.kde.org/p/1258818
  if [[ $(kreadconfig5 --file kcminputrc --group Mouse --key cursorTheme) != "PRA-DMZ" ]]; then
    # This is an X11 theme, so we can't use "kpackagetool5" to install.
    tar -xf "$CONFIGS_PATH/ubuntu-auto-install/post-install/misc/PRA-DMZ.tar.gz" -C ~/.icons/
    kwriteconfig5 --file kcminputrc --group Mouse --key cursorTheme PRA-DMZ
  fi

  # System Settings --> Appearance --> Window Decorations --> Change "Breeze" to "Win10OS-light".
  # This gives Window 10 icons in the top-right of a window.
  # https://store.kde.org/p/1383080
  # TODO

  # -------
  # Display
  # -------

  # System Settings --> Workspace Behavior --> Screen Locking --> Uncheck "After 5 minutes"
  kwriteconfig5 --file kscreenlockerrc --group Daemon --key Autolock false

  # --------
  # Hardware
  # --------

  # System Settings --> Input Devices --> Touchpad --> Right-click -->
  # Change "Press bottom-right-corner" to "Press anywhere with two fingers"
  kwriteconfig5 --file touchpadxlibinputrc --group "VEN_0488:00 0488:104B Touchpad" --key clickMethodAreas false
  kwriteconfig5 --file touchpadxlibinputrc --group "VEN_0488:00 0488:104B Touchpad" --key clickMethodClickfinger true

  # ----------
  # Animations
  # ----------

  # System Settings --> Workspace Behavior --> General Behavior --> Animation speed --> Instant
  kwriteconfig5 --file kdeglobals --group KDE --key AnimationDurationFactor 0

  # System Settings --> Workspace Behavior --> Desktop Effects --> Uncheck "Login"
  # (Smoothly fade to teh desktop when logging in)
  kwriteconfig5 --file kwinrc --group Plugins --key kwin4_effect_loginEnabled false

  # System Settings --> Workspace Behavior --> Desktop Effects --> Uncheck "Logout"
  # (Smoothly fade to the logout screen)
  kwriteconfig5 --file kwinrc --group Plugins --key kwin4_effect_logoutEnabled false

  # System Settings --> Workspace Behavior --> Desktop Effects --> Uncheck "Maximize"
  # (Animation for a window going to maximize/restore from maximize)
  kwriteconfig5 --file kwinrc --group Plugins --key kwin4_effect_maximizeEnabled false

  # System Settings --> Workspace Behavior --> Desktop Effects --> Uncheck "Squash"
  # (Squash windows when they are minimized)
  kwriteconfig5 --file kwinrc --group Plugins --key kwin4_effect_squashEnabled false

  # System Settings --> Workspace Behavior --> Desktop Effects --> Uncheck "Scale"
  # (Make windows smoothly scale in and out when they are shown or hidden)
  kwriteconfig5 --file kwinrc --group Plugins --key kwin4_effect_scaleEnabled false

  # -------
  # Hotkeys
  # -------

  # System Settings --> Shortcuts --> Shortcuts --> KWin --> Maximize Window
  # ("Meta+PgUp" by default)
  kwriteconfig5 --file kglobalshortcutsrc --group kwin --key "Window Maximize" "Meta+Up,Meta+PgUp,Maximize Window"

  # System Settings --> Shortcuts --> Shortcuts --> KWin --> Minimize Window
  # ("Meta+PgDown" by default)
  kwriteconfig5 --file kglobalshortcutsrc --group kwin --key "Window Minimize" "Meta+Down,Meta+PgDown,Minimize Window"

  # System Settings --> Shortcuts --> Shortcuts --> KWin --> Quick Tile Window to the Top
  # ("Meta+Up" by default)
  kwriteconfig5 --file kglobalshortcutsrc --group kwin --key "Window Quick Tile Top" "none,Meta+Up,Quick Tile Window to the Top"

  # System Settings --> Shortcuts --> Shortcuts --> KWin --> Quick Tile Window to the Bottom
  # ("Meta+Down" by default)
  kwriteconfig5 --file kglobalshortcutsrc --group kwin --key "Window Quick Tile Bottom" "none,Meta+Down,Quick Tile Window to the Top"

  # -------
  # Cleanup
  # -------

  # We do not want this script to run on every boot.
  if [[ -f "$FIRST_LOGIN_SETUP_DESKTOP_PATH" ]]; then
    rm "$FIRST_LOGIN_SETUP_DESKTOP_PATH"
  fi

  # Restart KDE Plasma to make the settings take effect.
  systemctl restart --user plasma-plasmashell.service
  # (Unfortunately, some settings will not take effect until the next reboot, like the touchpad
  # change.)
else
  # We have just installed the GUI and have not yet logged on for the first time, so the relevant
  # files in the ".config" directory do not yet exist. Make this script run again on the next boot.
  # (It is designed to be idempotent.)
  cp "$CONFIGS_PATH/ubuntu-auto-install/post-install/.config/autostart/first-login-setup.desktop" "$FIRST_LOGIN_SETUP_DESKTOP_PATH"
fi

# ----------------------
# Phase 3 - Applications
# ----------------------

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

# Install Visual Studio Code.
if ! command -v bw &> /dev/null; then
  sudo snap install --classic code
fi

# Install Kate. (This is similar to Notepad++ on Windows.)
if ! command -v kate &> /dev/null; then
  sudo snap install --classic kate
fi

# Install nvm.
if ! command -v nvm &> /dev/null; then
  curl --silent --fail --show-error --location https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash

  # Add it to path.
  export NVM_DIR="$HOME/.nvm"
  # shellcheck source=/dev/null
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm
  # shellcheck source=/dev/null
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # This loads nvm bash_completion
fi

# Install Node.js
if ! command -v node &> /dev/null; then
  nvm install --lts
fi

# Install Bun.
if ! command -v bun &> /dev/null; then
  if ! dpkg --status unzip &> /dev/null; then
    sudo apt-get install unzip --yes
  fi

  curl --silent --fail --show-error --location https://bun.sh/install | bash
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

# If the GUI was just installed for the first time, reboot the system to load the GUI.
if [[ -z "${DISPLAY:-}" ]] && [[ -z "${SSH_CONNECTION:-}" ]]; then
  sudo reboot
fi
