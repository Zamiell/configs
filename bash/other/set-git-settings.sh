#!/bin/bash

# We do not set these Git settings every time the normal Bash profile loads because it was tested to
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
if [[ "$(git config --global core.autocrlf)" != "false" ]]; then
  echo "Setting Git config: core.autocrlf false"
  git config --global core.autocrlf false
fi

# https://git-scm.com/docs/git-config/#Documentation/git-config.txt-coreignoreCase
# Default value: false (on Linux machines) or true (on Windows machines)
# Explicitly setting it to false can prevent problems with interop between Linux & Windows.
if [[ "$(git config --global core.ignorecase)" != "false" ]]; then
  echo "Setting Git config: core.ignorecase false"
  git config --global core.ignorecase false
fi

# https://git-scm.com/docs/git-config#Documentation/git-config.txt-corepager
# Default value: less
# `pager` is better than `less`.
if [[ "$(git config --global core.pager)" != "delta" ]]; then
  echo "Setting Git config: core.pager delta"
  git config --global core.pager delta
fi

# https://git-scm.com/docs/git-config#Documentation/git-config.txt-coresymlinks
# Default value: true in some cases and false in some cases
# Explicitly setting this to true is necessary for symlinks to be created properly when cloning a
# repository on Windows. Note that this setting will not actually do anything unless Developer Mode
# is also enabled: https://learn.microsoft.com/en-us/windows/advanced-settings/developer-mode
if is-git-bash; then
  if [[ "$(git config --global core.symlinks)" != "true" ]]; then
    echo "Setting Git config: core.symlinks true"
    git config --global core.symlinks true
  fi

  if ! is-developer-mode-enabled; then
    echo "Warning: Developer Mode is not enabled, so Linux-style symbolic links will not work properly. You should turn on Developer Mode. See: https://learn.microsoft.com/en-us/windows/advanced-settings/developer-mode" >&2
  fi
fi

# https://github.com/dandavison/delta/#line-numbers
# Default value: false
# It is helpful to see line numbers in git diffs.
if [[ "$(git config --global delta.line-numbers)" != "true" ]]; then
  echo "Setting Git config: delta.line-numbers true"
  git config --global delta.line-numbers true
fi

# https://git-scm.com/docs/git-config/#Documentation/git-config.txt-diffcolorMoved
# Default value: false
# Setting zebra can make git diffs easier to read by having a different color for moved lines.
if [[ "$(git config --global diff.colorMoved)" != "zebra" ]]; then
  echo "Setting Git config: diff.colorMoved zebra"
  git config --global diff.colorMoved zebra
fi

# https://git-scm.com/docs/git-config/#Documentation/git-config.txt-fetchprune
# Default value: false
# Automatically remove any remote-tracking references that no longer exist on the remote.
if [[ "$(git config --global fetch.prune)" != "true" ]]; then
  echo "Setting Git config: fetch.prune true"
  git config --global fetch.prune true
fi

# https://git-scm.com/docs/git-config/#Documentation/git-config.txt-fetchpruneTags
# Default value: false
# Automatically remove any tags that no longer exist on the remote.
if [[ "$(git config --global fetch.pruneTags)" != "true" ]]; then
  echo "Setting Git config: fetch.pruneTags true"
  git config --global fetch.pruneTags true
fi

# https://git-scm.com/docs/git-config#Documentation/git-config.txt-httpsslBackend
# Default value: openssl
# On Windows, we need to tell Git to use the Windows Certificate Store for resolving HTTPS website.
# This is necessary in situations where self-signed company certificates are present in the Windows
# Certificate Store.
if is-git-bash; then
  if [[ "$(git config --global http.sslBackend)" != "schannel" ]]; then
    echo "Setting Git config: http.sslBackend schannel"
    git config --global http.sslBackend schannel
  fi
fi

# https://git-scm.com/docs/git-config/#Documentation/git-config.txt-pullrebase
# Default value: false
# Setting this prevents spurious merge commits.
if [[ "$(git config --global pull.rebase)" != "true" ]]; then
  echo "Setting Git config: pull.rebase true"
  git config --global pull.rebase true
fi

# https://git-scm.com/docs/git-config/#Documentation/git-config.txt-pushautoSetupRemote
# Default value: false
# Setting this automates having "git pull" and "git push" work properly after setting up a new
# branch.
if [[ "$(git config --global push.autoSetupRemote)" != "true" ]]; then
  echo "Setting Git config: push.autoSetupRemote true"
  git config --global push.autoSetupRemote true
fi

OS_USERNAME=$(get-username)
if [[ "$OS_USERNAME" == "james" || "$OS_USERNAME" == "jnesta" ]]; then
  if [[ "$(git config --global user.name)" != "Zamiell" ]]; then
    echo "Setting Git config: user.name Zamiell"
    git config --global user.name "Zamiell"
  fi

  if [[ "$(git config --global user.email)" != "5511220+Zamiell@users.noreply.github.com" ]]; then
    echo "Setting Git config: user.email 5511220+Zamiell@users.noreply.github.com"
    git config --global user.email "5511220+Zamiell@users.noreply.github.com"
  fi
fi
