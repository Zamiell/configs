#!/bin/bash

# We do not set these Git settings every time normal Bash profile loads because it was tested to
# cost around 1.3 seconds. Instead, this script should be run once on a new computer.

set -euo pipefail # Exit on errors and undefined variables.

# -----------
# Subroutines
# -----------

# Get the current username in an operating system agnostic way.
get-username() (
  set -euo pipefail # Exit on errors and undefined variables.

  if [[ -n "${USER:-}" ]]; then # macOS/Linux
    echo "$USER"
  elif [[ -n "${USERNAME:-}" ]]; then # Windows
    echo "$USERNAME"
  else
    echo "Failed to derive the operating system username." >&2
    return 1
  fi
)

is-developer-mode-enabled() (
  set -euo pipefail # Exit on errors and undefined variables.

  local reg_output
  reg_output=$(MSYS_NO_PATHCONV=1 reg query 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' /v AllowDevelopmentWithoutDevLicense 2> /dev/null)
  echo "$reg_output" | grep --quiet "0x1"
)

is-git-bash() (
  set -euo pipefail # Exit on errors and undefined variables.

  local kernel_name
  kernel_name=$(uname -s) # The "--kernel-name" flag is not supported on macOS.
  [[ "$kernel_name" =~ ^MINGW || "$kernel_name" =~ ^MSYS_NT ]]
)

# ------------
# Git settings
# ------------

# https://git-scm.com/docs/git-config/#Documentation/git-config.txt-coreautocrlf
# Default value: input
# Explicitly setting it to false prevents Git from changing line endings at any point, which can
# prevent issues when Windows users collaborate with MacOS/Linus users.
git config --global core.autocrlf false

# https://git-scm.com/docs/git-config/#Documentation/git-config.txt-coreignoreCase
# Default value: false (on Linux machines) or true (on Windows machines)
# Explicitly setting it to false can prevent problems with interop between Linux & Windows.
git config --global core.ignorecase false

# https://git-scm.com/docs/git-config#Documentation/git-config.txt-coresymlinks
# Default value: true in some cases and false in some cases
# Explicitly setting this to true is necessary for symlinks to be created properly when cloning a
# repository on Windows. Note that this setting will not actually do anything unless Developer Mode
# is also enabled: https://learn.microsoft.com/en-us/windows/advanced-settings/developer-mode
if is-git-bash; then
  git config --global core.symlinks true

  if ! is-developer-mode-enabled; then
    echo "Warning: Developer Mode is not enabled, so Linux-style symbolic links will not work properly. You should turn on Developer Mode. See: https://learn.microsoft.com/en-us/windows/advanced-settings/developer-mode" >&2
  fi
fi

# https://git-scm.com/docs/git-config/#Documentation/git-config.txt-diffcolorMoved
# Default value: false
# Setting zebra can make git diffs easier to read by having a different color for moved lines.
git config --global diff.colorMoved zebra

# https://git-scm.com/docs/git-config/#Documentation/git-config.txt-fetchprune
# Default value: false
# Automatically remove any remote-tracking references that no longer exist on the remote.
git config --global fetch.prune true

# https://git-scm.com/docs/git-config/#Documentation/git-config.txt-fetchpruneTags
# Default value: false
# Automatically remove any tags that no longer exist on the remote.
git config --global fetch.pruneTags true

# https://git-scm.com/docs/git-config#Documentation/git-config.txt-httpsslBackend
# Default value: openssl
# On Windows, we need to tell Git to use the Windows Certificate Store for resolving HTTPS website.
# This is necessary in situations where self-signed company certificates are present in the Windows
# Certificate Store.
if is-git-bash; then
  git config --global http.sslBackend schannel
fi

# https://git-scm.com/docs/git-config/#Documentation/git-config.txt-pullrebase
# Default value: false
# Setting this prevents spurious merge commits.
git config --global pull.rebase true

# https://git-scm.com/docs/git-config/#Documentation/git-config.txt-pushautoSetupRemote
# Default value: false
# Setting this automates having "git pull" and "git push" work properly after setting up a new
# branch.
git config --global push.autoSetupRemote true

OS_USERNAME=$(get-username)
if [[ "$OS_USERNAME" == "james" || "$OS_USERNAME" == "jnesta" ]]; then
  git config --global user.name "Zamiell"
  git config --global user.email "5511220+Zamiell@users.noreply.github.com"
fi
