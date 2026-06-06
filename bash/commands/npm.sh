# ------------
# npm Commands
# ------------

exec-package() (
  set -euo pipefail # Exit on errors and undefined variables.

  if [[ -z "${1-}" ]]; then
    echo "Error: The package name is required. Usage: ${FUNCNAME[0]} <package_name>" >&2
    return 1
  fi

  local package_manager
  package_manager="$(get-package-manager)"

  local -a exec_command
  case $package_manager in
    npm)
      exec_command=(npx)
      ;;
    yarn)
      exec_command=(npx)
      ;;
    pnpm)
      exec_command=(pnpm exec)
      ;;
    bun)
      exec_command=(bunx)
      ;;
    *)
      echo "Error: Not able to determine the exec command for the package manager of: $package_manager" >&2
      return 1
      ;;
  esac

  "${exec_command[@]}" "$@"
)

get-package-manager() (
  set -euo pipefail # Exit on errors and undefined variables.

  local current_dir="$PWD"

  # Search upward through directories, looking for package lock files.
  while [[ "$current_dir" != "/" ]]; do
    if [[ -s "$current_dir/package-lock.json" ]]; then
      echo "npm"
      return
    fi

    if [[ -s "$current_dir/yarn.lock" ]]; then
      echo "yarn"
      return
    fi

    if [[ -s "$current_dir/pnpm-lock.yaml" ]]; then
      echo "pnpm"
      return
    fi

    if [[ -s "$current_dir/bun.lock" ]]; then
      echo "bun"
      return
    fi

    current_dir="$(dirname "$current_dir")"
  done

  # If no lock file was found, default to npm.
  echo "npm"
)

run-package-script() (
  set -euo pipefail # Exit on errors and undefined variables.

  if [[ -z "${1-}" ]]; then
    echo "Error: The script name is required. Usage: ${FUNCNAME[0]} <script_name>" >&2
    return 1
  fi

  local package_manager
  package_manager="$(get-package-manager)"
  "$package_manager" run "$@"
)

alias b="run-package-script build"
alias l="run-package-script lint"
alias la="run-package-script lint-all"
alias p="run-package-script publish"
alias s="run-package-script start"
alias t="run-package-script test"

# If the "package.json" file for the project has an "update" script, then run the script. Otherwise,
# invoke the "update" command of "complete-cli".
u() (
  set -euo pipefail # Exit on errors and undefined variables.

  assert-in-git-repository

  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2> /dev/null)
  if [[ -z "$repo_root" ]]; then
    echo "Error: Failed to get the root of the current git repository." >&2
    return 1
  fi

  builtin cd "$repo_root"

  if [[ -s "package.json" ]]; then
    assert-jq-installed
    if jq --exit-status '.scripts.update? | type == "string"' package.json > /dev/null; then
      run-package-script update "$@"
      return
    fi
  fi

  exec-package complete-cli@latest update "$@"
)
