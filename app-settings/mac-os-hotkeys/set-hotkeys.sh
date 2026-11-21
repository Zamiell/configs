#!/bin/bash

set -euo pipefail # Exit on errors and undefined variables.

# Sets custom macOS keyboard shortcuts (the ones found in "System Settings --> Keyboard --> Keyboard
# Shortcuts"). These are stored in the "AppleSymbolicHotKeys" dictionary of the
# "com.apple.symbolichotkeys" preferences domain.
#
# Each hotkey has three parameters:
# 1. The ASCII code of the character (or 65535 for keys that have none).
# 2. The virtual key code.
# 3. The modifier flags: Shift = 131072, Control = 262144, Option = 524288, Command = 1048576

if [[ "$(uname)" != "Darwin" ]]; then
  echo "Error: This script only works on macOS." >&2
  exit 1
fi

DOMAIN="com.apple.symbolichotkeys"
UPDATED=false

# Prints the current value of a hotkey field, or nothing if it does not exist. We go through
# "defaults" (instead of reading the plist file directly) so that cached values are respected.
get_hotkey_field() {
  local key_path="$1"

  defaults export "$DOMAIN" - | plutil -extract "AppleSymbolicHotKeys.$key_path" raw -o - - 2> /dev/null || true
}

set_hotkey() {
  local id="$1"
  local description="$2"
  local enabled="$3" # "true" or "false"
  local ascii_code="$4"
  local key_code="$5"
  local modifiers="$6"

  if [[ "$(get_hotkey_field "$id.enabled")" == "$enabled" ]] \
    && [[ "$(get_hotkey_field "$id.value.parameters.0")" == "$ascii_code" ]] \
    && [[ "$(get_hotkey_field "$id.value.parameters.1")" == "$key_code" ]] \
    && [[ "$(get_hotkey_field "$id.value.parameters.2")" == "$modifiers" ]]; then
    echo "The \"$description\" hotkey is already up to date."
    return
  fi

  defaults write "$DOMAIN" AppleSymbolicHotKeys -dict-add "$id" "
    <dict>
      <key>enabled</key><$enabled/>
      <key>value</key>
      <dict>
        <key>parameters</key>
        <array>
          <integer>$ascii_code</integer>
          <integer>$key_code</integer>
          <integer>$modifiers</integer>
        </array>
        <key>type</key><string>standard</string>
      </dict>
    </dict>
  "
  echo "Successfully updated: $description"
  UPDATED=true
}

# Disable "Save picture of selected area as a file" so that it does not conflict with the below
# hotkey. (We also restore it to the default shortcut of Command + Shift + 4.)
set_hotkey 30 "Save picture of selected area as a file" false 52 21 1179648

# Set "Copy picture of selected area to the clipboard" to Control + Shift + S. (This matches the
# behavior of the same hotkey on Windows.)
set_hotkey 31 "Copy picture of selected area to the clipboard" true 115 1 393216

# Apply the changes without having to log out.
if [[ "$UPDATED" == true ]]; then
  /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
fi
