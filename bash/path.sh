# ----
# Path
# ----

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

# Add browsers to the path, which is necessary for the GitHub CLI.
if ! command -v chrome &> /dev/null && [[ -s "/c/Program Files/Google/Chrome/Application/chrome.exe" ]]; then
  export PATH="/c/Program Files/Google/Chrome/Application:$PATH"
fi
if ! command -v chrome &> /dev/null && [[ -s "$HOME/AppData/Local/Google/Chrome/Application/chrome.exe" ]]; then
  export PATH="$HOME/AppData/Local/Google/Chrome/Application:$PATH"
fi
if ! command -v chrome &> /dev/null && command -v google-chrome &> /dev/null; then
  alias chrome="google-chrome"
fi
if ! command -v msedge &> /dev/null && [[ -s "/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe" ]]; then
  export PATH="/c/Program Files (x86)/Microsoft/Edge/Application:$PATH"
fi
if ! command -v msedge &> /dev/null && command -v microsoft-edge &> /dev/null; then
  alias msedge="microsoft-edge"
fi
if is-wsl; then
  export BROWSER="wslview"
  export GH_BROWSER="wslview"
fi

# bun
# https://bun.com/
append-path "$HOME/.bun/bin"

# Claude Code
# https://www.claude.com/product/claude-code
append-path "$HOME/.local/bin"

# fnm
# https://github.com/Schniz/fnm
append-path "$HOME/AppData/Local/Microsoft/WinGet/Packages/Schniz.fnm_Microsoft.Winget.Source_8wekyb3d8bbwe"
append-path "$HOME/.local/share/fnm"

# gitleaks
append-path "$HOME/OneDrive - LogixHealth Inc/Documents/Programs/gitleaks/gitleaks_8.28.0_windows_x64"

# GnuWin32
append-path "/c/Program Files (x86)/GnuWin32/bin"

# Node.js (through fnm)
if command -v fnm &> /dev/null && ! command -v node &> /dev/null; then
  eval "$(fnm env --shell bash)"
fi

# PostgreSQL
# (We do not use find to dynamically get the version for performance reasons.)
append-path "/c/Program Files/PostgreSQL/18/bin"

# "Programs" directory in OneDrive
append-path "/c/Users/jnesta/OneDrive - LogixHealth Inc/Documents/Programs"

# Python
# (We do not use find to dynamically get the version for performance reasons.)
# On Windows, the Microsoft Store installation goes to the "Local" directory.
append-path "$HOME/AppData/Local/Python/pythoncore-3.14-64/Scripts"
# On Windows, the "python.org" install goes to the "Roaming" directory.
append-path "$HOME/AppData/Roaming/Python/Python314/Scripts"
# On macOS, Python is installed in the "Library" directory.
append-path "$HOME/Library/Python/3.14/bin"

# terraform-docs
append-path "$HOME/OneDrive - LogixHealth Inc/Documents/Programs/terraform-docs"

# terragrunt
append-path "$HOME/OneDrive - LogixHealth Inc/Documents/Programs/terragrunt"

# zig
append-path "/d/Apps/Misc/zig"

# zoxide
append-path "$HOME/AppData/Local/Microsoft/WinGet/Packages/ajeetdsouza.zoxide_Microsoft.Winget.Source_8wekyb3d8bbwe"
