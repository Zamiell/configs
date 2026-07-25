# --------
# Browsers
# --------

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

# -----
# Other
# -----

# bun
# https://bun.com/
if command -v bun &> /dev/null; then
  append-path "$HOME/.bun/bin"
fi

# Claude Code
# https://www.claude.com/product/claude-code
if command -v claude &> /dev/null; then
  append-path "$HOME/.local/bin"
fi

# fnm
# https://github.com/Schniz/fnm
if command -v fnm &> /dev/null; then
  append-path "$HOME/AppData/Local/Microsoft/WinGet/Packages/Schniz.fnm_Microsoft.Winget.Source_8wekyb3d8bbwe"
  append-path "$HOME/.local/share/fnm"
fi

# golang
if command -v go &> /dev/null; then
  append-path "/usr/local/go/bin"
fi

# tree
if command -v tree &> /dev/null; then
  append-path "/c/Program Files (x86)/GnuWin32/bin"
fi

# Node.js (through fnm)
if command -v fnm &> /dev/null && ! command -v node &> /dev/null; then
  eval "$(fnm env --shell bash)"
fi

# opencode
if command -v opencode &> /dev/null; then
  append-path "$HOME/.opencode/bin"
fi

# PostgreSQL
# (We do not use find to dynamically get the version for performance reasons.)
if command -v psql &> /dev/null; then
  append-path "/c/Program Files/PostgreSQL/18/bin"
fi

# Python
# (We do not use find to dynamically get the version for performance reasons.)
# On Windows, the Microsoft Store installation goes to the "Local" directory.
append-path "$HOME/AppData/Local/Python/pythoncore-3.14-64/Scripts"
# On Windows, the "python.org" install goes to the "Roaming" directory.
append-path "$HOME/AppData/Roaming/Python/Python314/Scripts"
# On macOS, Python is installed in the "Library" directory.
append-path "$HOME/Library/Python/3.14/bin"

# zoxide
if command -v zoxide &> /dev/null; then
  append-path "$HOME/AppData/Local/Microsoft/WinGet/Packages/ajeetdsouza.zoxide_Microsoft.Winget.Source_8wekyb3d8bbwe"
fi
