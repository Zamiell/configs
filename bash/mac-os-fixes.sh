# Homebrew
# https://brew.sh/
# (Homebrew must come first so that other programs can enter the PATH.)
if is-mac-os; then
  if [[ ! -s "/opt/homebrew/bin/brew" ]]; then
    echo "Error: On macOS, these Bash configs require that you have Homebrew package manager installed. Run: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"" >&2
    return 1
  fi

  brew_cache="$HOME/.cache/brew-shellenv.bash"
  if [[ ! -s "$brew_cache" || "/opt/homebrew/bin/brew" -nt "$brew_cache" ]]; then
    mkdir -p "$HOME/.cache"
    /opt/homebrew/bin/brew shellenv > "$brew_cache"
  fi
  # shellcheck source=/dev/null
  source "$brew_cache"
  unset brew_cache

  if ! command -v gsed &> /dev/null; then
    echo "Error: On macOS, these Bash configs require the GNU version of sed to be installed (because the BSD version is very old). Run: brew install gnu-sed" >&2
    return 1
  fi

  alias sed="gsed"
fi
