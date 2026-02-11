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

# ----------
# Validation
# ----------

if [[ "$EUID" -eq 0 ]]; then
  echo "Error: This script cannot be run as root." >&2
  exit 1
fi

# By default, Ubuntu server does not have the ability to connect to a WiFi network because it needs
# the "wpasupplicant" package. Putting this on the installation media is non-trivial because it
# needs to match the existing system and would quickly get out of date. Thus, we first check for the
# presence of a wired connection.
ONLINE="false"
# Only wait for 20 seconds.
for ((i = 1; i <= 20; i++)); do
  if curl --silent --fail --show-error --location --connect-timeout 1 https://www.google.com &> /dev/null; then
    ONLINE="true"
    break
  fi
  sleep 1
done
if [[ "$ONLINE" == "false" ]]; then
  # Make the error message easy to see so that it does not get lost in the spam of the initial boot.
  echo "---------------------------------------------------------------" >&2
  echo "Error: You must have an internet connection to run this script." >&2
  echo "---------------------------------------------------------------" >&2
  exit 1
fi

# -----------------
# Phase 1 - Pre-GUI
# -----------------

# Load information about the system for later.
# shellcheck source=/dev/null
source /etc/os-release

# Set the timezone.
sudo timedatectl set-timezone America/New_York

# Patch the OS.
sudo apt-get update -qq
sudo apt-get upgrade -qq --yes

# Install basic software.
sudo apt-get install -qq --yes zip unzip

# Install SSH.
# https://documentation.ubuntu.com/server/how-to/security/openssh-server/index.html
if ! dpkg --status openssh-server &> /dev/null; then
  sudo apt-get install -qq --yes openssh-server
  sudo systemctl enable ssh
  sudo systemctl start ssh
fi
# (SSH keys are already set up from "autoinstall.yaml".)

# Copy the SSH config.
cp /post-install/.ssh/config "$HOME/.ssh/config"

# Disable the message of the day.
touch "$HOME/.hushlogin"

# Install Git.
if ! command -v git &> /dev/null; then
  sudo apt-get install -qq --yes git
  git config --global user.name "$FULL_NAME"
  git config --global user.email "$WORK_EMAIL"
fi

# Install the GitHub CLI.
if ! command -v gh &> /dev/null; then
  # From: https://github.com/cli/cli/blob/trunk/docs/install_linux.md#debian
  sudo mkdir -p -m 755 /etc/apt/keyrings \
    && curl --silent --fail --show-error --location https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg &> /dev/null \
    && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && sudo mkdir -p -m 755 /etc/apt/sources.list.d \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list &> /dev/null \
    && sudo apt-get update -qq \
    && sudo apt-get install -qq --yes gh

  # gh uses HTTPS by default.
  gh config set git_protocol ssh
fi

# Install the public key for "github.com".
if ! ssh-keygen -F github.com &> /dev/null; then
  ssh-keyscan github.com >> "$HOME/.ssh/known_hosts"
fi

# Set up the "repositories" directory.
REPOSITORIES_PATH="$HOME/repositories"
mkdir -p "$REPOSITORIES_PATH"

# Ensure that our SSH keys are in place.
SSH_PRIVATE_KEY_PATH="$HOME/.ssh/id_ed25519"
if [[ ! -s "$SSH_PRIVATE_KEY_PATH" ]]; then
  echo "Error: The \"$SSH_PRIVATE_KEY_PATH\" file does not exist or is 0 bytes." >&2
  exit 1
fi
SSH_PUBLIC_KEY_PATH="$HOME/.ssh/id_ed25519.pub"
if [[ ! -s "$SSH_PUBLIC_KEY_PATH" ]]; then
  echo "Error: The \"$SSH_PUBLIC_KEY_PATH\" file does not exist or is 0 bytes." >&2
  exit 1
fi

# Set up the "configs" repository.
CONFIGS_PATH="$REPOSITORIES_PATH/configs"
if [[ -d "$CONFIGS_PATH" ]]; then
  # Make sure this repository is up to date.
  git -C "$CONFIGS_PATH" pull
else
  # Clone this repository.
  git clone git@github.com:Zamiell/configs.git "$CONFIGS_PATH"
  git -C "$CONFIGS_PATH" config user.name "$GITHUB_USERNAME"
  git -C "$CONFIGS_PATH" config user.email "$GITHUB_EMAIL"
fi

# Install the remote configs from this repository.
BASHRC_PATH="$HOME/.bashrc"
if ! grep --quiet BASH_PROFILE_REMOTE_PATH "$BASHRC_PATH"; then
  if [[ ! -s "$BASHRC_PATH" ]]; then
    echo "# shellcheck shell=bash" > "$BASHRC_PATH"
  fi

  echo >> "$BASHRC_PATH"
  cat "$CONFIGS_PATH/bash/.bash_profile" >> "$BASHRC_PATH"
fi

# Set up the LogixHealth certificate.
ROOT_CERT_PATH="/usr/local/share/ca-certificates/BEDROOTCA001.crt"
sudo cp "$CONFIGS_PATH/certs/BEDROOTCA001.crt" "$ROOT_CERT_PATH"
sudo update-ca-certificates

# Set up the "secrets" repository.
SECRETS_PATH="$REPOSITORIES_PATH/secrets"
if [[ -d "$SECRETS_PATH" ]]; then
  # Make sure this repository is up to date.
  git -C "$SECRETS_PATH" pull
else
  # Clone this repository.
  git clone git@github.com:Zamiell/secrets.git "$SECRETS_PATH"
  git -C "$SECRETS_PATH" config user.name "$GITHUB_USERNAME"
  git -C "$SECRETS_PATH" config user.email "$GITHUB_EMAIL"
fi

# Set the ".env" file.
sudo apt-get install -qq --yes age
age --decrypt --identity "$SSH_PRIVATE_KEY_PATH" --output "$HOME/.env" "$SECRETS_PATH/.env.age"

# -------------
# Phase 2 - GUI
# -------------

sudo apt-get install -qq --yes kde-plasma-desktop

# Copy the Simple Desktop Display Manager (SDDM) config. (SDDM is the login manager.)
# (This handles automatic login.)
sudo cp "$CONFIGS_PATH/ubuntu-auto-install/post-install/etc/sddm.conf" /etc/

# Some GUI apps require a GPG key, such as connecting to WiFi and VS Code.
# (We add "(Personal)" since it is assumed in the GUI that all keys will have comments.)
if ! gpg --list-secret-keys "$PERSONAL_EMAIL"; then
  gpg --batch --passphrase "" --quick-generate-key "$FULL_NAME (Personal) <$PERSONAL_EMAIL>" default default 0
fi

# Disable Bluetooth. (This will automatically remove the Bluetooth icon from the system tray.)
sudo systemctl disable bluetooth.service
sudo systemctl stop bluetooth.service

# Disable Discover. (This will automatically remove the "Updates" icon from the system tray.)
# https://old.reddit.com/r/kde/comments/f2bquo/how_to_stop_discover_from_autostarting/
# - Normally, icons in the system tray can be removed by deleting the corresponding entry from the
#   "extraItems" key. However, "Updates" is a special case, because it has no corresponding entry.
# - We do not need Discover because we will handle system updates manually.
mkdir -p "$HOME/.config/autostart"
cp /etc/xdg/autostart/org.kde.discover.notifier.desktop "$HOME/.config/autostart/"
echo "Hidden=true" >> "$HOME/.config/autostart/org.kde.discover.notifier.desktop"

# Right click Desktop --> Configure Desktop and Wallpaper... --> Icons --> Sorting --> Name
qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript 'd=desktops();for(i=0;i<d.length;i++){d[i].currentConfigGroup=Array("General");d[i].writeConfig("sortMode","0");d[i].reloadConfig();}'

# Right click Desktop --> Configure Desktop and Wallpaper... --> Icons --> Lock in place
qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript 'd=desktops();for(i=0;i<d.length;i++){d[i].currentConfigGroup=Array("General");d[i].writeConfig("locked","true");d[i].reloadConfig();}'

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

  # ------------------
  # Dolphin (Explorer)
  # ------------------

  # Hamburger menu --> Show Hidden Files
  kwriteconfig5 --file ~/.local/share/dolphin/view_properties/global/.directory --group Settings --key HiddenFilesShown true

  # ------------------------------
  # System Settings --> Appearance
  # ------------------------------

  # System Settings --> Appearance --> Window Decorations --> Change "Breeze" to "Win10OS-light".
  # This gives Window 10 icons in the top-right of a window.
  # From: https://store.kde.org/p/1464171
  # This must be done manually. When I tried to install just the "Window Decorations" theme, 3 dots
  # appeared in the top left of all windows.

  # System Settings --> Appearance --> Cursors --> Change "Breeze" to "PRA-DMZ".
  # This changes the cursors to Windows 10 cursors.
  # From: https://store.kde.org/p/1258818
  if [[ ! -d "$HOME/.icons/Win10OS-cursors" ]]; then
    mkdir -p "$HOME/.icons"
    tar -xf "$CONFIGS_PATH/ubuntu-auto-install/post-install/misc/PRA-DMZ.tar.gz" -C "$HOME/.icons/"
  fi
  if [[ $(kreadconfig5 --file kcminputrc --group Mouse --key cursorTheme) != "PRA-DMZ" ]]; then
    # We can't use "kpackagetool5" to install this because it is an X11 theme.
    kwriteconfig5 --file kcminputrc --group Mouse --key cursorTheme PRA-DMZ
  fi

  # -----------------------------
  # System Settings --> Workspace
  # -----------------------------

  # System Settings --> Workspace --> Workspace Behavior --> General Behavior --> Animation speed
  # --> Instant
  kwriteconfig5 --file kdeglobals --group KDE --key AnimationDurationFactor 0

  # System Settings --> Workspace --> Workspace Behavior --> Desktop Effects --> Uncheck "Login"
  # (Smoothly fade to teh desktop when logging in)
  kwriteconfig5 --file kwinrc --group Plugins --key kwin4_effect_loginEnabled false

  # System Settings --> Workspace --> Workspace Behavior --> Desktop Effects --> Uncheck "Logout"
  # (Smoothly fade to the logout screen)
  kwriteconfig5 --file kwinrc --group Plugins --key kwin4_effect_logoutEnabled false

  # System Settings --> Workspace --> Workspace Behavior --> Desktop Effects --> Uncheck "Maximize"
  # (Animation for a window going to maximize/restore from maximize)
  kwriteconfig5 --file kwinrc --group Plugins --key kwin4_effect_maximizeEnabled false

  # System Settings --> Workspace --> Workspace Behavior --> Desktop Effects --> Uncheck "Squash"
  # (Squash windows when they are minimized)
  kwriteconfig5 --file kwinrc --group Plugins --key kwin4_effect_squashEnabled false

  # System Settings --> Workspace --> Workspace Behavior --> Desktop Effects --> Uncheck "Scale"
  # (Make windows smoothly scale in and out when they are shown or hidden)
  kwriteconfig5 --file kwinrc --group Plugins --key kwin4_effect_scaleEnabled false

  # System Settings --> Workspace --> Workspace Behavior --> Screen Locking
  # --> Uncheck "After 5 minutes"
  kwriteconfig5 --file kscreenlockerrc --group Daemon --key Autolock false

  # System Settings --> Workspace --> Window Management --> Window Behavior
  # --> Focus stealing preventing: None
  kwriteconfig5 --file kwinrc --group Windows --key FocusStealingPreventionLevel --type int 0

  # System Settings --> Workspace --> Window Management --> Task Switcher
  # --> Change "Breeze" to "ClassicKDE".
  # This changes the Alt-Tab UI to something simpler and faster.
  # From: https://store.kde.org/p/2024371
  if ! kpackagetool5 --list --type KWin/WindowSwitcher | grep "ClassicKde"; then
    kpackagetool5 --type KWin/WindowSwitcher --install "$CONFIGS_PATH/ubuntu-auto-install/post-install/misc/ClassicKde.tar.gz"
  fi
  if [[ $(kreadconfig5 --file kwinrc --group TabBox --key LayoutName) != "ClassicKde" ]]; then
    kwriteconfig5 --file kwinrc --group TabBox --key LayoutName ClassicKde
  fi

  # System Settings --> Workspace --> Shortcuts --> Shortcuts --> KWin --> Maximize Window
  # ("Meta+PgUp" by default)
  kwriteconfig5 --file kglobalshortcutsrc --group kwin --key "Window Maximize" "Meta+Up,Maximize Window"

  # System Settings --> Workspace --> Shortcuts --> Shortcuts --> KWin --> Minimize Window
  # ("Meta+PgDown" by default)
  kwriteconfig5 --file kglobalshortcutsrc --group kwin --key "Window Minimize" "Meta+Down,Minimize Window"

  # System Settings --> Workspace --> Shortcuts --> Shortcuts --> KWin
  # --> Quick Tile Window to the Top
  # ("Meta+Up" by default)
  kwriteconfig5 --file kglobalshortcutsrc --group kwin --key "Window Quick Tile Top" "none,Quick Tile Window to the Top"

  # System Settings --> Workspace --> Shortcuts --> Shortcuts --> KWin
  # --> Quick Tile Window to the Bottom
  # ("Meta+Down" by default)
  kwriteconfig5 --file kglobalshortcutsrc --group kwin --key "Window Quick Tile Bottom" "none,Quick Tile Window to the Bottom"

  # System Settings --> Workspace --> Shortcuts --> Shortcuts --> Plasma --> Walk through activities
  # ("Meta+Tab" by default)
  # kwriteconfig5 --file kglobalshortcutsrc --group kwin --key "next activity" "none,none,Walk through activities"
  # TODO

  # System Settings --> Workspace --> Shortcuts --> Shortcuts --> Plasma
  # --> Walk through activities (Reverse)
  # ("Meta+Shift+Tab" by default)
  # kwriteconfig5 --file kglobalshortcutsrc --group kwin --key "previous activity" "none,none,Walk through activities (Reverse)"
  # TODO

  # System Settings --> Workspace --> Shortcuts --> Custom Shortcuts
  # --> Disable the 3 vanilla groups.
  kwriteconfig5 --file khotkeysrc --group Data_1 --key Enabled false
  kwriteconfig5 --file khotkeysrc --group Data_2 --key Enabled false
  kwriteconfig5 --file khotkeysrc --group Data_3 --key Enabled false

  # ----------------------------
  # System Settings --> Hardware
  # ----------------------------

  # System Settings --> Hardware --> Input Devices --> Mouse --> Pointer speed --> 8 (from 6)
  kwriteconfig5 --file kcminputrc --group Mouse --key XLbInptPointerAcceleration 0.4

  # System Settings --> Hardware --> Input Devices --> Touchpad --> Right-click
  # --> Change "Press bottom-right-corner" to "Press anywhere with two fingers"
  kwriteconfig5 --file touchpadxlibinputrc --group "VEN_0488:00 0488:104B Touchpad" --key clickMethodAreas false
  kwriteconfig5 --file touchpadxlibinputrc --group "VEN_0488:00 0488:104B Touchpad" --key clickMethodClickfinger true
  kcminit kcm_touchpad

  # -------
  # Cleanup
  # -------

  # We do not want this script to run on every boot.
  if [[ -f "$FIRST_LOGIN_SETUP_DESKTOP_PATH" ]]; then
    rm "$FIRST_LOGIN_SETUP_DESKTOP_PATH"
  fi

  # Restart the desktop shell (which manages the panels, widgets, desktop background) to make some
  # changes take effect.
  systemctl restart --user plasma-plasmashell.service

  # Restart the window manager to make some changes take effect.
  qdbus org.kde.KWin /KWin reconfigure

  # (Unfortunately, some settings will not take effect until the next reboot, like the touchpad
  # change.)
else
  # We have just installed the GUI and have not yet logged on for the first time, so the relevant
  # files in the ".config" directory do not yet exist. Make this script run again on the next boot.
  # (It is designed to be idempotent.)
  cp "$CONFIGS_PATH/ubuntu-auto-install/post-install/.config/autostart/first-login-setup.desktop" "$FIRST_LOGIN_SETUP_DESKTOP_PATH"
fi

# Install the GObject introspection bindings for libsecret. (This is needed to create the default
# keyring programmatically.)
sudo apt-get install -qq --yes gir1.2-secret-1

# Create a default keyring with an empty password. This is necessary because SDDM auto-login
# bypasses PAM, which means "pam_gnome_keyring" never gets the password to create/unlock the
# "login" keyring. Without a default keyring, apps like Microsoft Intune will fail to store
# authentication tokens. This must be placed after the GUI has installed.
python3 -c "
import gi
gi.require_version('Secret', '1')
from gi.repository import Secret
service = Secret.Service.get_sync(Secret.ServiceFlags.OPEN_SESSION)
if Secret.Collection.for_alias_sync(service, 'default', Secret.CollectionFlags.NONE, None) is None:
    Secret.Collection.create_sync(service, 'Login', 'default', Secret.CollectionCreateFlags.NONE, None)
"

# -----------------
# Phase 3 - Hotkeys
# -----------------

# Install Autokey.
if ! dpkg --status autokey-qt &> /dev/null; then
  # https://github.com/autokey/autokey/wiki/Installing#debian-and-derivatives
  LATEST_AUTOKEY_VERSION=$(curl --silent --fail --show-error --location --output /dev/null --write-out "%{url_effective}" https://github.com/autokey/autokey/releases/latest | sed 's|.*/||' | sed 's/^v//')

  AUTOKEY_COMMON_PATH="/tmp/autokey-common.deb"
  curl --silent --fail --show-error --location --output "$AUTOKEY_COMMON_PATH" "https://github.com/autokey/autokey/releases/download/v${LATEST_AUTOKEY_VERSION}/autokey-common_${LATEST_AUTOKEY_VERSION}_all.deb"
  sudo apt-get install -qq --yes "$AUTOKEY_COMMON_PATH"
  rm "$AUTOKEY_COMMON_PATH"

  AUTOKEY_QT_PATH="/tmp/autokey-qt.deb"
  curl --silent --fail --show-error --location --output "$AUTOKEY_QT_PATH" "https://github.com/autokey/autokey/releases/download/v${LATEST_AUTOKEY_VERSION}/autokey-qt_${LATEST_AUTOKEY_VERSION}_all.deb"
  sudo apt-get install -qq --yes "$AUTOKEY_QT_PATH"
  rm "$AUTOKEY_QT_PATH"

  mkdir -p "$HOME/.config/autokey"
  ln --symbolic "$CONFIGS_PATH/autokey/data" "$HOME/.config/autokey/data"
fi

# --------------------------------
# Phase 4 - Uninstall Applications
# --------------------------------

# KDE Plasma installs some applications that are unwanted.
sudo apt-get purge --yes byobu # Byobu Terminal
sudo apt-get autoremove --yes

# ------------------------------
# Phase 5 - Install Applications
# ------------------------------

# Install the Microsoft package signing key. (This is needed for Edge and Intune.)
MICROSOFT_GPG_KEY_PATH="/usr/share/keyrings/microsoft-edge.gpg"
if [[ ! -s "$MICROSOFT_GPG_KEY_PATH" ]]; then
  curl --silent --fail --show-error --location https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee "$MICROSOFT_GPG_KEY_PATH" > /dev/null
fi

# Install Microsoft Edge.
MICROSOFT_EDGE_REPOSITORY_PATH="/etc/apt/sources.list.d/microsoft-edge.list"
if [[ ! -s "$MICROSOFT_EDGE_REPOSITORY_PATH" ]]; then
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-edge.gpg] https://packages.microsoft.com/repos/edge stable main" | sudo tee "$MICROSOFT_EDGE_REPOSITORY_PATH" > /dev/null
  sudo apt-get update -qq
fi
sudo apt-get install -qq --yes microsoft-edge-stable

# Make Microsoft Edge trust the company cert.
sudo apt install -qq --yes libnss3-tools
NSSDB="sql:$HOME/.pki/nssdb"
CERT_NICKNAME="LogixHealth Root CA"
if ! certutil -L -d "$NSSDB" -n "$CERT_NICKNAME" > /dev/null 2>&1; then
  certutil -d "$NSSDB" -A -t "C,," -n "$CERT_NICKNAME" -i "$ROOT_CERT_PATH"
fi

# Make Firefox trust the company cert.
FIREFOX_POLICIES_PATH="/etc/firefox/policies/policies.json"
if ! grep ImportEnterpriseRoots "$FIREFOX_POLICIES_PATH"; then
  cat << EOF | sudo tee /etc/firefox/policies/policies.json > /dev/null
  {
    "policies": {
      "Certificates": {
        "ImportEnterpriseRoots": true
      }
    }
  }
EOF
fi

# Install Google Chrome.
if ! dpkg --status google-chrome-stable &> /dev/null; then
  GOOGLE_CHROME_PATH="/tmp/google-chrome.deb"
  curl --silent --fail --show-error --location --output "$GOOGLE_CHROME_PATH" https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
  sudo apt-get install -qq --yes "$GOOGLE_CHROME_PATH"
  rm "$GOOGLE_CHROME_PATH"
fi

# Install Firefox.
if ! snap info firefox | grep -q "^installed:"; then
  sudo snap install firefox
fi

# Install Visual Studio Code.
if ! command -v code &> /dev/null; then
  sudo snap install --classic code
fi

# Install fnm.
if ! command -v fnm &> /dev/null; then
  # The "--skip-shell" is necessary to prevent fnm from modifying the ".bashrc" file.
  curl --silent --fail --show-error --location https://fnm.vercel.app/install | bash -s -- --skip-shell

  # Add it to PATH.
  FNM_PATH="$HOME/.local/share/fnm"
  export PATH="$FNM_PATH:$PATH"
  eval "$(fnm env --shell bash)"
fi

# Install Node.js
if ! command -v node &> /dev/null && command -v fnm &> /dev/null; then
  fnm install --lts
fi

# Install Bun.
if ! command -v bun &> /dev/null; then
  curl --silent --fail --show-error --location https://bun.sh/install | bash

  # Bun does not have a flag like fnm's "--skip-shell", so the added entries to the ".bashrc" file
  # have to be manually deleted.
  sed -i '/^# bun$/,+2d' ~/.bashrc ~/.bash_profile 2> /dev/null
fi

# Alias Python.
sudo apt-get install -qq --yes python-is-python3

# Install Microsoft Intune.
if ! dpkg --status packages-microsoft-prod &> /dev/null; then
  MICROSOFT_LINUX_REPOSITORY_PATH="/tmp/packages-microsoft-prod.deb"
  curl --silent --fail --show-error --location --output "$MICROSOFT_LINUX_REPOSITORY_PATH" "https://packages.microsoft.com/config/$ID/$VERSION_ID/packages-microsoft-prod.deb"
  sudo apt-get install -qq --yes "$MICROSOFT_LINUX_REPOSITORY_PATH"
  rm "$MICROSOFT_LINUX_REPOSITORY_PATH"
  sudo apt-get update -qq
fi
sudo apt-get install -qq --yes intune-portal

# Install the VPN client.
if [[ ! -s "/etc/apt/sources.list.d/yuezk-ubuntu-globalprotect-openconnect-noble.sources" ]]; then
  sudo add-apt-repository ppa:yuezk/globalprotect-openconnect --yes
fi
sudo apt-get install -qq --yes globalprotect-openconnect

# Install other software.
sudo apt install -qq --yes podman

# -----------------
# Phase 6 - Network
# -----------------

# On Ubuntu, Netplan is the default system for configuring network interfaces, but KDE's network
# app is part of the NetworkManager framework and only shows connections it manages. Thus, we need
# to pass control to NetworkManager. This will kill network connectivity until the next reboot, so
# we must do this as the last thing in the script.
NETWORK_MANAGER_YAML_PATH="/etc/netplan/01-network-manager.yaml"
if [[ ! -s "$NETWORK_MANAGER_YAML_PATH" ]]; then
  sudo find /etc/netplan -type f -name "*.yaml" -delete
  sudo cp "$CONFIGS_PATH/ubuntu-auto-install/post-install/etc/netplan/01-network-manager.yaml" "$NETWORK_MANAGER_YAML_PATH"
  sudo chmod 600 "$NETWORK_MANAGER_YAML_PATH"
  sudo netplan apply
  sudo systemctl stop systemd-networkd-wait-online.service
  sudo systemctl disable systemd-networkd-wait-online.service
  sudo systemctl stop systemd-networkd.service
  sudo systemctl disable systemd-networkd.service
  sudo systemctl enable NetworkManager.service
  sudo systemctl start NetworkManager.service
  sudo systemctl enable NetworkManager-wait-online.service
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
