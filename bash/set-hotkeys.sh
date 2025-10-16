#!/bin/bash

# -----------------------------
# Bindings for existing hotkeys
# -----------------------------

# Flag + L --> Lock screen
gsettings set org.cinnamon.desktop.keybindings.media-keys screensaver "['<Super>l']"

# --------------
# Custom hotkeys
# --------------

# Remove all existing hotkeys.
dconf reset -f /org/cinnamon/desktop/keybindings/custom-keybindings/

# A counter to automatically number the hotkeys, starting at 0.
HOTKEY_LIST=()
HOTKEY_INDEX=0

# Creates a custom hotkey by setting its name, command, and binding.
# Arguments:
#   $1: The numeric index (e.g., 0, 1, 2)
#   $2: The descriptive name (e.g., 'Launch/Focus Terminal')
#   $3: The command to execute (e.g., 'bash -c "wmctrl..."')
#   $4: The keybinding (e.g., "['<Control>5']")
create_hotkey() {
  local name="$1"
  local command="$2"
  local binding="$3"
  local base_path="/org/cinnamon/desktop/keybindings/custom-keybindings/custom$HOTKEY_INDEX"

  echo "Setting hotkey #$HOTKEY_INDEX: $name"

  # Reset the slot to ensure a clean state
  dconf reset -f "$base_path/"

  # Write the new configuration
  dconf write "$base_path/name" "'$name'"
  dconf write "$base_path/command" "'$command'"
  dconf write "$base_path/binding" "$binding"

  # Add this hotkey's ID to our master list for activation
  HOTKEY_LIST+=("custom$HOTKEY_INDEX")

  ((HOTKEY_INDEX++))
}

create_hotkey \
  "Launch/Focus Terminal" \
  'bash -c "wmctrl -x -a gnome-terminal-server.Gnome-terminal || gnome-terminal"' \
  "['<Control>5']"

create_hotkey \
  "Launch/Focus Visual Studio Code" \
  'bash -c "wmctrl -x -a Code || code"' \
  "['<Control>6']"

create_hotkey \
  "Launch/Focus Google Chrome" \
  'bash -c "wmctrl -x -a Google-chrome || google-chrome"' \
  "['<Control>9']"

create_hotkey \
  "Launch/Focus Microsoft Edge" \
  'bash -c "wmctrl -x -a Edge || msedge"' \
  "['<Control>asciitilde']"

create_hotkey \
  "Launch/Focus Obsidian" \
  'bash -c "wmctrl -x -a obsidian || obsidian"' \
  "['<Control><Shift>asciitilde']"

create_hotkey \
  "Launch/Focus Firefox" \
  'bash -c "wmctrl -x -a firefox || firefox"' \
  "['<Control><Shift><Alt>asciitilde']"

# Activate the hotkeys.
formatted_list=$(printf "'%s'," "${HOTKEY_LIST[@]}")
formatted_list="[${formatted_list%,}]"
dconf write /org/cinnamon/desktop/keybindings/custom-list "$formatted_list"
