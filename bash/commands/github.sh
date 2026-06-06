# ---------------
# GitHub Commands
# ---------------

# This will delete local branches that have been merged via pull requests on GitHub.
gh-clean() (
  set -euo pipefail # Exit on errors and undefined variables.

  assert-in-github-repository
  assert-main-branch

  if ! git remote get-url upstream &> /dev/null; then
    echo "Error: There is no upstream remote. This command is intended to be used inside a forked GitHub repository." >&2
    return 1
  fi

  local main_branch_name
  main_branch_name=$(get-main-branch-name)

  if ! command -v gh &> /dev/null; then
    echo "Error: GitHub CLI (gh) is not installed or not in PATH." >&2
    return 1
  fi

  if ! gh auth status &> /dev/null; then
    echo "Error: Not authenticated with GitHub. Run: gh auth login" >&2
    return 1
  fi

  local my_merged_object_ids
  my_merged_object_ids=$(gh pr list --author @me --state merged --json headRefOid --jq ".[].headRefOid")

  if [[ -z "$my_merged_object_ids" ]]; then
    return
  fi

  local local_branches
  local_branches=$(git branch --format="%(refname:lstrip=2)" | sort)

  while IFS= read -r branch; do
    if [[ "$branch" == "$main_branch_name" ]]; then
      continue
    fi

    local branch_object_id
    branch_object_id=$(git rev-parse "$branch")

    if echo "$my_merged_object_ids" | grep --line-regexp --quiet "$branch_object_id"; then
      echo "GitHub pull request branch has been merged on the upstream: $branch"

      git branch --delete --force "$branch"
      echo "Deleted local branch: $branch"
      git push origin ":$branch"
      echo "Deleted remote branch: $branch"
    fi

  done <<< "$local_branches"
)

# This is a custom version of "gh pr checkout". This is necessary because "gh pr checkout" will fail
# if the forked repository branch name overlaps with a branch name on the upstream repository (and
# the remote has already been added by "set-gh-remote"). To work around this, we can checkout the
# forked repository branch with a custom arbitrary name matching the pull request number.
gh-pr() (
  set -euo pipefail # Exit on errors and undefined variables.

  if [[ -z "${1:-}" ]]; then
    echo "Error: The pull request number is required. Usage: ${FUNCNAME[0]} <pull_request_number>" >&2
    return 1
  fi
  local pull_request_number="$1"

  assert-in-github-repository
  gh pr checkout "$pull_request_number" --branch "pr-$pull_request_number"
  set-gh-remote
)

# This will sync a forked repository's main branch with the upstream. (This is a common operation
# when working on GitHub.)
gh-sync() (
  set -euo pipefail # Exit on errors and undefined variables.

  assert-in-github-repository
  assert-main-branch

  if ! git remote get-url upstream &> /dev/null; then
    echo "Error: There is no upstream remote. This command is intended to be used inside a forked GitHub repository." >&2
    return 1
  fi

  local main_branch_name
  main_branch_name=$(get-main-branch-name)

  git fetch origin --prune --quiet
  git fetch upstream --prune --quiet

  local local_head
  local_head=$(git rev-parse HEAD)
  local remote_head
  remote_head=$(git rev-parse "upstream/$main_branch_name")

  if [[ "$local_head" != "$remote_head" ]]; then
    git rebase "upstream/$main_branch_name"
    git push origin "$main_branch_name" --force-with-lease
  fi
)
