# First, ensure that the standard local binary location is included in the path.
prepend-path "$HOME/.local/bin"

# bun
# https://bun.com/
if ! command -v bun &> /dev/null; then
  prepend-path "$HOME/.bun/bin"
fi

# Chrome
if ! command -v chrome &> /dev/null; then
  prepend-path "/c/Program Files/Google/Chrome/Application"
fi
if ! command -v chrome &> /dev/null; then
  prepend-path "$HOME/AppData/Local/Google/Chrome/Application"
fi

# fnm
# https://github.com/Schniz/fnm
if ! command -v fnm &> /dev/null; then
  prepend-path "$HOME/AppData/Local/Microsoft/WinGet/Packages/Schniz.fnm_Microsoft.Winget.Source_8wekyb3d8bbwe"
  prepend-path "$HOME/.local/share/fnm"
fi

# golang
if ! command -v go &> /dev/null; then
  prepend-path "/usr/local/go/bin"
fi

# Microsoft Edge
if ! command -v msedge &> /dev/null; then
  prepend-path "/c/Program Files (x86)/Microsoft/Edge/Application"
fi

# tree
if ! command -v tree &> /dev/null; then
  prepend-path "/c/Program Files (x86)/GnuWin32/bin"
fi

# Node.js (through fnm)
if command -v fnm &> /dev/null && ! command -v node &> /dev/null; then
  eval "$(fnm env --shell bash)"
fi

# opencode
if ! command -v opencode &> /dev/null; then
  prepend-path "$HOME/.opencode/bin"
fi

# PostgreSQL
# (We do not use find to dynamically get the version for performance reasons.)
if ! command -v psql &> /dev/null; then
  prepend-path "/c/Program Files/PostgreSQL/18/bin"
fi

# pnpm
if ! command -v pnpm &> /dev/null; then
  prepend-path "$HOME/.local/share/pnpm/bin"
fi

# Python
# - We cannot check for the presence of the Python command since on Windows, it defaults to a
#   message about the Windows Store.
# - We do not use find to dynamically get the version for performance reasons.
# On Windows, the Microsoft Store installation goes to the "Local" directory.
prepend-path "$HOME/AppData/Local/Python/pythoncore-3.14-64/Scripts"
# On Windows, the "python.org" install goes to the "Roaming" directory.
prepend-path "$HOME/AppData/Roaming/Python/Python314/Scripts"
# On macOS, Python is installed in the "Library" directory.
prepend-path "$HOME/Library/Python/3.14/bin"

# Pulumi
if ! command -v pulumi &> /dev/null; then
  prepend-path "$HOME/.pulumi/bin"
fi

# Rust
if ! command -v rustup &> /dev/null; then
  prepend-path "$HOME/.cargo/bin"
fi

# zoxide
if ! command -v zoxide &> /dev/null; then
  prepend-path "$HOME/AppData/Local/Microsoft/WinGet/Packages/ajeetdsouza.zoxide_Microsoft.Winget.Source_8wekyb3d8bbwe"
fi
