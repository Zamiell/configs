# Only create the "cd" alias if the shell is interactive.
if [[ $- == *i* ]]; then
  # We have to use braces instead of parenthesis here.
  cd() {
    if command -v z &> /dev/null; then
      # Use "zoxide" if it is available.
      z "$@" && print-files-and-branches
    else
      builtin cd "$@" && print-files-and-branches
    fi
  }
fi

# "cd.." works on Windows for some reason and is convenient.
cd..() {
  cd ..
}

# "cdg" stands for "change directory git", which will change the working directory to the root of
# the current git repository. If used in a directory that is not part of a Git repository, it will
# throw an error.
cdg() {
  assert-in-git-repository

  local repo_root
  repo_root=$(git rev-parse --show-toplevel)

  cd "$repo_root" || return
}

if [[ -n "${REPOSITORIES_DIR:-}" ]]; then
  # "cdr" is short for "change directory repositories".
  alias cdr='builtin cd $REPOSITORIES_DIR'

  # Make various "cd" hotkeys for switching to specific personal repositories.
  set-cd-alias configs
  set-cd-alias notes
  set-cd-alias secrets

  # Make various "cd" hotkeys for switching to specific work repositories.
  set-cd-alias allscripts-external
  set-cd-alias database-services
  set-cd-alias databricks-data b # We need to use a custom abbreviation.
  set-cd-alias infrastructure
  set-cd-alias LogixApplications
fi
