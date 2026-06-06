# -----------------
# Terminal Settings
# -----------------

# Make writing to Bash command history immediate:
# https://askubuntu.com/questions/67283/is-it-possible-to-make-writing-to-bash-history-immediate
# This fixes the bug where closing one terminal window will remove the command history that was
# written by other terminal windows.
shopt -s histappend # This is "off" by default.
PROMPT_COMMAND+=("history -a")

# Only modify other terminal settings if the shell is interactive.
if [[ $- == *i* ]]; then
  # Prevent "Last login: Mon Jan  1 12:00:00 on ttys000" from appearing on macOS. (Unfortunately, this
  # will only take effect on the next shell.)
  touch "$HOME/.hushlogin"

  # Emulate the Git Bash for Windows prompt on non-Windows platforms.
  if ! command -v __git_ps1 &> /dev/null; then
    GIT_SH_PROMPT_PATH_MACOS="/Library/Developer/CommandLineTools/usr/share/git-core/git-prompt.sh"
    GIT_SH_PROMPT_PATH_UBUNTU="/usr/lib/git-core/git-sh-prompt"
    if [[ -s "$GIT_SH_PROMPT_PATH_MACOS" ]]; then
      # shellcheck source=/dev/null
      source "$GIT_SH_PROMPT_PATH_MACOS"
    elif [[ -s "$GIT_SH_PROMPT_PATH_UBUNTU" ]]; then
      # shellcheck source=/dev/null
      source "$GIT_SH_PROMPT_PATH_UBUNTU"
    else
      echo "Error: Cannot find the \"__git_ps1\" function declared." >&2
      return 1
    fi
  fi

  if [[ -s "/etc/os-release" ]]; then
    source /etc/os-release
  fi

  if is-ubuntu || is-mac-os; then
    # We copy the prompt from Git Bash for Windows:
    # https://github.com/git-for-windows/build-extra/blob/main/git-extra/git-prompt.sh
    PS1='\[\033]0;\W\007\]'  # set window title (modified to only show directory name)
    PS1="$PS1"'\n'           # new line
    PS1="$PS1"'\[\033[32m\]' # change to green
    PS1="$PS1"'\u@\h '       # user@host<space>
    PS1="$PS1"'\[\033[35m\]' # change to purple
    PS1="$PS1"'$MSYSTEM '    # show MSYSTEM
    PS1="$PS1"'\[\033[33m\]' # change to brownish yellow
    PS1="$PS1"'\w'           # current working directory
    GIT_EXEC_PATH="$(git --exec-path 2> /dev/null)"
    COMPLETION_PATH="${GIT_EXEC_PATH%/libexec/git-core}"
    COMPLETION_PATH="${COMPLETION_PATH%/lib/git-core}"
    COMPLETION_PATH="$COMPLETION_PATH/share/git/completion"
    PS1="$PS1"'\[\033[36m\]' # change color to cyan
    PS1="$PS1"'`__git_ps1`'  # bash function
    PS1="$PS1"'\[\033[0m\]'  # change color
    PS1="$PS1"'\n'           # new line
    PS1="$PS1"'$ '           # prompt: always $
  fi

  # bun auto-complete for e.g. "bun run"
  # See the comment in the "bun-completions.sh" file.
  if command -v bun &> /dev/null; then
    mkdir -p "$HOME/.bun"
    source "$DIR/other/bun-completions.sh"
  fi

  # npm auto-complete for e.g. "npm run"
  if command -v npm &> /dev/null; then
    _npm_bin="$(command -v npm)"
    _npm_cache="$HOME/.cache/npm-completion.bash"
    if [[ ! -s "$_npm_cache" || "$_npm_bin" -nt "$_npm_cache" ]]; then
      mkdir -p "$HOME/.cache"
      npm completion > "$_npm_cache"
    fi
    # shellcheck source=/dev/null
    source "$_npm_cache"
    unset _npm_bin _npm_cache
  fi

  # zoxide (a better cd)
  # https://github.com/ajeetdsouza/zoxide
  if command -v zoxide &> /dev/null; then
    # We can use "zoxide init bash --cmd cd" to replace the "cd" command, but we do not need to do
    # this because we overwrite the "cd" command anyway.
    _zoxide_bin="$(command -v zoxide)"
    _zoxide_cache="$HOME/.cache/zoxide-init.bash"
    if [[ ! -s "$_zoxide_cache" || "$_zoxide_bin" -nt "$_zoxide_cache" ]]; then
      mkdir -p "$HOME/.cache"
      zoxide init bash > "$_zoxide_cache"
    fi
    # shellcheck source=/dev/null
    source "$_zoxide_cache"
    unset _zoxide_bin
    unset _zoxide_cache

    # Overwrite the "zi" command so that it functions similar to our custom "cd" command.
    zi() {
      __zoxide_zi "$@" && print-files-and-branches
    }
  fi

  # fzf (for fuzzy matching file paths)
  # https://github.com/junegunn/fzf
  if command -v fzf &> /dev/null; then
    _fzf_bin="$(command -v fzf)"
    _fzf_cache="$HOME/.cache/fzf-init.bash"
    if [[ ! -s "$_fzf_cache" || "$_fzf_bin" -nt "$_fzf_cache" ]]; then
      mkdir -p "$HOME/.cache"
      fzf --bash > "$_fzf_cache"
    fi
    # shellcheck source=/dev/null
    source "$_fzf_cache"
    unset _fzf_bin
    unset _fzf_cache

    # https://github.com/junegunn/fzf?tab=readme-ov-file#advanced-topics
    # "--scheme=path" - Optimize the scoring for file paths.
    export FZF_COMPLETION_OPTS="--scheme=path"

    # Change fzf's "Alt + C" hotkey to use zoxide, if available.
    if command -v zi &> /dev/null; then
      bind '"\ec": "zi\n"'
    fi
  fi
fi
