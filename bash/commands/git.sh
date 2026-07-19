# ------------
# Git Commands
# ------------

# "ga" is short for "git add".
alias ga="git add"

# "gaa" is short for "git add --all".
alias gaa="git add --all"

# - "gb" is short for creating a new git branch, which is a common coding task.
# - If the remote repository is not GitHub, this will make the branch according to the LogixHealth
#   branch naming convention.
# - Doing a push is important after creating a new branch because it prevents subsequent "git pull"
#   calls from failing.
# - You can use the "-n" or "--no-convention" flag to omit the LogixHealth naming convention.
gb() (
  set -euo pipefail # Exit on errors and undefined variables.

  local use_logixhealth_convention="true"
  local positional_args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -n | --no-convention)
        use_logixhealth_convention="false"
        shift
        ;;
      *)
        positional_args+=("$1")
        shift
        ;;
    esac
  done
  set -- "${positional_args[@]}" # Restore positional parameters.

  assert-in-git-repository

  local new_branch_name="misc"
  if [[ -n "${1:-}" ]]; then
    new_branch_name="$1"
  fi
  if ! git check-ref-format "refs/heads/$new_branch_name"; then
    echo "Error: The branch name of \"$new_branch_name\" contains illegal characters." >&2
    return 1
  fi

  if [[ "$use_logixhealth_convention" == "true" ]] && ! is-github-repository; then
    local username
    username=$(get-username)
    new_branch_name="feature/$username/$new_branch_name"
  fi

  if [[ -n "$(git status --porcelain)" ]]; then
    echo "The repository is not clean. Stashing all of your existing changes."
    git stash push --message "Auto-stash before creating a new git branch"
  fi

  local main_branch_name
  main_branch_name=$(get-main-branch-name)

  if [[ "$(git branch --show-current)" != "$main_branch_name" ]]; then
    git switch "$main_branch_name"
  fi

  add-upstream-remote-if-github-fork

  if git remote get-url upstream &> /dev/null; then
    gh-sync
  else
    git fetch --prune origin
    git rebase "origin/$main_branch_name"
  fi

  if git show-ref --verify --quiet "refs/remotes/origin/$new_branch_name"; then
    echo "Error: The branch name of \"$new_branch_name\" already exists on the remote." >&2
    return 1
  fi

  git switch --create "$new_branch_name"
  git push

  if [[ $(git stash list | wc -l) -gt 0 ]]; then
    echo "A previous git stash exists. Applying it to this new branch."
    git stash pop
  fi

  echo
  gbl
)

# "gb_" is an alias for "gb --no-convention".
alias gb_="gb --no-convention"

# "gbcl" is short for "git branch clean", which will remove all local branches that do not exist on
# the remote repository.
# https://stackoverflow.com/questions/7726949/remove-tracking-branches-no-longer-on-remote
gbcl() (
  set -euo pipefail # Exit on errors and undefined variables.

  local skip_fetch=false
  for arg in "$@"; do
    if [[ "$arg" == "--skip-fetch" ]]; then
      skip_fetch=true
    fi
  done

  assert-in-git-repository

  local main_branch_name
  main_branch_name=$(get-main-branch-name)

  if [[ "$(git branch --show-current)" != "$main_branch_name" ]]; then
    git switch "$main_branch_name"
  fi

  if [[ "$skip_fetch" == false ]]; then
    git fetch --prune --quiet
  fi

  git branch -vv | awk "/: gone]/{print \$1}" | xargs --no-run-if-empty git branch --delete --force

  # Additionally, we want to delete branches from merged pull requests.
  if git remote get-url upstream &> /dev/null; then
    gh-clean
  fi

  echo
  gbl
)

# "gbcp" is short for "git branch copy", which will put the branch name into the clipboard.
gbcp() (
  if ! command -v clip.exe &> /dev/null; then
    echo "Error: \"clip.exe\" was not found. This command is intended to be run inside of Git Bash or WSL." >&2
    return 1
  fi

  local branch_name
  branch_name=$(git branch --show-current)
  printf "%s" "$branch_name" | clip.exe
)

# "gbd" is short for "git branch delete", which will delete the branch both locally and remotely.
gbd() (
  set -euo pipefail # Exit on errors and undefined variables.

  assert-in-git-repository

  local branch_name_or_number=""
  local only_local="false"

  for arg in "$@"; do
    if [[ "$arg" == "--only-local" ]]; then
      only_local="true"
    else
      branch_name_or_number="$arg"
    fi
  done

  if [[ -z "$branch_name_or_number" ]]; then
    echo "Error: Branch name or number is required. Usage: ${FUNCNAME[0]} <branch-name-or-number> [--only-local]" >&2
    return 1
  fi

  local branch_name
  branch_name=$(get-branch-name-from-number "$branch_name_or_number")

  if [[ "$branch_name" == "main" ]] || [[ "$branch_name" == "master" ]]; then
    echo "Error: You cannot use this command to delete the \"$branch_name\" branch. Are you sure you want to delete that?" >&2
    return 1
  fi

  local current_branch_name
  current_branch_name=$(git branch --show-current)
  if [[ "$branch_name" == "$current_branch_name" ]]; then
    echo "Error: You are deleting branch \"$branch_name\", but that is the branch that you are currently on. Switch to another branch first." >&2
    return 1
  fi

  # Delete the branch locally.
  if git show-ref --verify --quiet "refs/heads/$branch_name"; then
    git branch --delete --force "$branch_name"
    echo "Deleted branch \"$branch_name\" locally."
  else
    echo "Warning: Branch \"$branch_name\" does not exist locally."
  fi

  # Delete the branch remotely.
  if [[ "$only_local" == "false" ]]; then
    if git ls-remote --heads origin "$branch_name" | grep --quiet .; then
      git push origin ":$branch_name"
      echo "Deleted branch \"$branch_name\" remotely."
    else
      echo "Warning: Branch \"$branch_name\" does not exist on remote origin."
    fi
  fi

  echo
  gbl
)

# "gbdl" is short for "git branch delete local", which will delete the branch locally (and not
# remotely).
gbdl() (
  gbd "$1" --only-local
)

# "gbl" is short for "git branch list". ("gb" is already taken by another command.)
gbl() (
  set -euo pipefail # Exit on errors and undefined variables.

  assert-in-git-repository

  local local_branches
  # We need to use "lstrip" instead of "short" since the latter does not work properly with branches
  # from "gh pr checkout".
  local_branches=$(git branch --format="%(refname:lstrip=2)" | sort)
  local current_branch
  current_branch=$(git branch --show-current)

  local GREEN_CODE='\033[32m'
  local RESET_CODE='\033[0m'

  local total_lines
  total_lines=$(echo "$local_branches" | wc -l | tr -d '[:space:]')
  local width=${#total_lines}

  echo "Current git branches:"

  local count=1
  while IFS= read -r branch; do
    if [[ "$branch" == "$current_branch" ]]; then
      printf "${GREEN_CODE}* %*d - %s${RESET_CODE}\n" "$width" "$count" "$branch"
    else
      printf "  %*d - %s\n" "$width" "$count" "$branch"
    fi

    ((count++))
  done <<< "$local_branches"
)

# "gblr" is short for "git branch list remote".
gblr() (
  set -euo pipefail # Exit on errors and undefined variables.

  assert-in-git-repository

  git fetch --prune --quiet

  local remote_branches
  remote_branches=$(git branch --format="%(refname:lstrip=2)" --remotes | grep --invert-match --line-regexp "origin" | grep --invert-match "^origin/" | sort)

  echo "Remote git branches:"

  local count=1
  while IFS= read -r branch; do
    echo "  ${count} - ${branch}"
    ((count++))
  done <<< "$remote_branches"
)

# "gbo" is short for "git branch open", which will open all of the changed files in this branch
# inside Visual Studio Code. This command will throw an error if there are 10 or more files
# changed as part of the branch.
gbo() (
  set -euo pipefail # Exit on errors and undefined variables.

  assert-in-git-repository
  assert-feature-branch

  local repo_root
  repo_root=$(git rev-parse --show-toplevel)

  local main_branch_name
  main_branch_name=$(get-main-branch-name)

  # Three dots compares to the merge base (instead of the current HEAD).
  local changed_files
  changed_files=$(git -C "$repo_root" diff --name-only "$main_branch_name"...HEAD)

  if [[ -z "$changed_files" ]]; then
    echo "Error: There are no changed files in this branch when compared to the \"$main_branch_name\" branch." >&2
    return 1
  fi

  local num_changed_files
  num_changed_files=$(echo "$changed_files" | wc -l | tr -d " ")

  if [[ "$num_changed_files" -ge 10 ]]; then
    echo "Error: There are $num_changed_files changed files in this branch. This command only supports branches with fewer than 10 changed files." >&2
    return 1
  fi

  echo "$changed_files"
  local changed_file_paths=()
  local changed_file
  while IFS= read -r changed_file; do
    changed_file_paths+=("$repo_root/$changed_file")
  done <<< "$changed_files"

  code "${changed_file_paths[@]}"
)

# "gbr" is short for "git branch rename".
# - You can use the "-n" or "--no-convention" flag to omit the LogixHealth naming convention.
gbr() (
  set -euo pipefail # Exit on errors and undefined variables.

  local use_logixhealth_convention="true"
  local positional_args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -n | --no-convention)
        use_logixhealth_convention="false"
        shift
        ;;
      *)
        positional_args+=("$1")
        shift
        ;;
    esac
  done
  set -- "${positional_args[@]}" # Restore positional parameters.

  assert-in-git-repository

  local old_branch_name
  old_branch_name=$(git branch --show-current) # e.g. "feature/alice/fix-bug-1"

  local new_branch_name
  if [[ "$use_logixhealth_convention" == "true" ]]; then
    IFS='/' read -ra branch_parts <<< "$old_branch_name"
    if [[ ${#branch_parts[@]} -ne 3 ]]; then
      echo "Error: Branch name must have exactly 3 parts separated by a forward slash. The current branch name is: $old_branch_name" >&2
      return 1
    fi

    local branch_type="${branch_parts[0]}"     # e.g. "feature"
    local branch_username="${branch_parts[1]}" # e.g. "alice"
    local old_description="${branch_parts[2]}" # e.g. "fix-bug-1"
    local new_description="$old_description"
    if [[ -n "${1:-}" ]]; then
      new_description="$1"
    fi

    new_branch_name="$branch_type/$branch_username/$new_description"
  else
    if [[ -z "${1:-}" ]]; then
      echo "Error: Branch name is required. Usage: ${FUNCNAME[0]} <branch-name>" >&2
      return 1
    fi
    new_branch_name="$1"
  fi

  echo "Old branch name: $old_branch_name"
  echo "New branch name: $new_branch_name"

  git switch --create "$new_branch_name"
  git push
  git push origin ":$old_branch_name"            # Delete the old branch on the remote.
  git branch --delete --force "$old_branch_name" # Delete the old branch locally.
)

# "gbr_" is an alias for "gbr --no-convention".
alias gbr_="gbr --no-convention"

# "gbs" is short for "git branch squash", which squash all commits on the branch.
gbs() (
  set -euo pipefail # Exit on errors and undefined variables.

  assert-in-git-repository
  assert-feature-branch

  local branch_name
  branch_name=$(git branch --show-current)

  local merge_base
  merge_base=$(get-merge-base)

  local num_branch_commits
  num_branch_commits=$(git rev-list --count "$merge_base..$branch_name")

  if [[ "$num_branch_commits" -eq 1 ]]; then
    echo "There is only 1 commit on this branch, so no squashing is needed."
    return
  fi

  git reset --soft "HEAD~$num_branch_commits"
  git commit --message "chore: squashed $num_branch_commits commits"
  git push --force-with-lease
)

# "gc" is short for "git commit", which will perform all the steps involved in making a new commit
# with all unstaged changes. The arguments that are provided will be the commit message. If no
# arguments are provided, then the script will attempt to find a suitable commit message.
gc() (
  set -euo pipefail # Exit on errors and undefined variables.

  local amend="false"
  local edit_commit_message="false"
  local browser="true"
  local commit_message_args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --amend)
        amend="true"
        shift
        ;;
      --edit-commit-message)
        edit_commit_message="true"
        shift
        ;;
      --no-browser)
        browser="false"
        shift
        ;;
      *)
        commit_message_args+=("$1")
        shift
        ;;
    esac
  done

  local commit_message="${commit_message_args[*]}"

  assert-in-git-repository

  if [[ -z "$(git config user.name)" ]]; then
    echo "Error: Git user name not set. Run: git config --global user.name \"Your Name\"" >&2
    return 1
  fi

  if [[ -z "$(git config user.email)" ]]; then
    echo "Error: Git user email not set. Run: git config --global user.email you@example.com" >&2
    return 1
  fi

  local user_email
  user_email=$(git config user.email)
  if is-github-repository; then
    if [[ "$user_email" == *logixhealth.com ]]; then
      echo "Error: You are trying to commit to a GitHub repository with an email of \"$user_email\", which might be a mistake." >&2
      return 1
    fi
  else
    if [[ "$user_email" == *github.com || "$user_email" == *gmail.com ]]; then
      echo "Work repository detected; setting the git config for this repository to your full name and work email."

      local full_name
      full_name=$(get-full-name)
      git config user.name "$full_name"

      local username
      username=$(get-username)
      git config user.email "$username@logixhealth.com"
    fi
  fi

  local branch_name
  branch_name=$(git branch --show-current)

  local repository_has_commits="false"
  if git rev-parse --verify HEAD &> /dev/null; then
    repository_has_commits="true"
  fi

  local has_upstream_config="false"
  if [[ -n "$(git config branch."$branch_name".merge)" ]]; then
    has_upstream_config="true"
  fi

  # Only check for the remote branch existing if:
  # 1) There are one or more commits. (For brand-new repositories, the remote branch will not yet
  #    exist.)
  # 2) This is not a repository from: gh pr checkout
  if [[ "$repository_has_commits" == "true" ]] && [[ "$has_upstream_config" == "false" ]]; then
    local remote_branch_info
    remote_branch_info=$(git ls-remote --heads origin "$branch_name")

    if [[ -z "$remote_branch_info" ]]; then
      echo "Error: The remote branch of \"$branch_name\" does not yet exist." >&2
      return 1
    fi
  fi

  if [[ "$amend" == "true" ]]; then
    # Validate that we are at the remote tip so that we do not accidentally blow away commits.
    git fetch origin "$branch_name" --prune --quiet
    local latest_commit_local
    latest_commit_local=$(git rev-parse HEAD)
    local latest_commit_remote
    latest_commit_remote=$(git rev-parse "origin/$branch_name")

    if [[ "$latest_commit_local" != "$latest_commit_remote" ]] && ! git merge-base --is-ancestor "$latest_commit_remote" HEAD; then
      echo "Error: Remote branch has commits are not present locally. Do a \"git pull\" first or use a different approach." >&2
      return 1
    fi
  fi

  git add --all

  # Validate that we have one or more new changes to commit. (But allow 0 change commits if we are
  # only editing the commit message.)
  if [[ "$edit_commit_message" == "false" ]] && git diff --cached --quiet; then
    echo "Error: There are no changes to commit."
    return 1
  fi

  if [[ "$amend" == "true" ]]; then
    if [[ "$edit_commit_message" == "true" ]]; then
      # "--amend" amends the previous commit instead of making a new commit.
      # "--allow-empty" allows amending the commit message without changing any files.
      if [[ -z "$commit_message" ]]; then
        git commit --amend --allow-empty
      else
        git commit --amend --allow-empty --message "$commit_message"
      fi
    else
      # "--amend" amends the previous commit instead of making a new commit.
      # "--no-edit" avoids prompting for a commit message and uses the default commit message.
      if [[ -z "$commit_message" ]]; then
        git commit --amend --no-edit
      else
        git commit --amend --message "$commit_message"
      fi
    fi

    # We do not need to "git pull" because we already verified above that we are on the remote tip.
    git push --force-with-lease
  else
    if [[ -z "$commit_message" ]]; then
      # A commit message was not provided at the command-line.
      if [[ -z "${GITHUB_TOKEN_WORK:-${GITHUB_TOKEN:-}}" ]]; then
        commit_message="chore: update something"
      else
        echo "Getting the commit message from an LLM..."
        commit_message=$(get-llm-commit-message)
      fi
    fi

    git commit --message "$commit_message"

    if [[ "$repository_has_commits" == "true" ]]; then
      set-gh-remote
      git pull --rebase --prune
    fi

    git push
  fi

  if [[ "$browser" == "true" ]]; then
    gcs
  fi
)

# "gca" is short for "git commit amend". This is similar to "gc", but it will amend the previous
# commit and add all unstaged files. Use this sparingly, since it will force push. By default, it
# will use the previous commit message, but you can use "gca edit" (or "gcam") to edit the commit
# message before pushing.
gca() (
  gc --amend
)

# "gcam" is short for "git commit amend message". This is similar to "gca", but it will also allow
# you to change the commit message. If arguments are provided, they are used as the commit message.
gcam() (
  gc --amend --edit-commit-message "$@"
)

# "gcl" is short for "git clone".
alias gcl="git clone"

# "gcp" is short for "git cherry-pick".
gcp() (
  set -euo pipefail # Exit on errors and undefined variables.

  assert-in-git-repository

  git cherry-pick "$@"
  git push
)

# "gcpa" is short for "git cherry-pick --abort".
alias gcpa="git cherry-pick --abort"

# "gcpc" is short for "git cherry-pick --continue".
alias gcpc="git cherry-pick --continue"

# "gcpr" will both commit and open a pull request.
gcpr() (
  set -euo pipefail # Exit on errors and undefined variables.

  assert-in-git-repository

  local branch_name
  branch_name=$(git branch --show-current)
  if [[ "$branch_name" == "main" ]] || [[ "$branch_name" == "master" ]]; then
    gb
  fi

  gc --no-browser "$@"
  gpr "$@"
)

# "gcs" is short for "git commit show", which will open a browser to view the last commit. You can
# optionally supply a SHA1 to show a custom commit.
gcs() (
  set -euo pipefail # Exit on errors and undefined variables.

  assert-in-git-repository

  local commit_sha1
  if [[ -z "${1:-}" ]]; then
    # e.g. "efe970b4d2d9c7a7023919ea677efce70222c201"
    commit_sha1=$(git rev-parse HEAD)
  else
    commit_sha1="$1"
  fi

  read -r host _2 _3 _4 <<< "$(get-git-remote-details)"

  local commit_url
  if [[ "$host" == "github" ]]; then
    read -r host author repository <<< "$(get-git-remote-details)"
    commit_url="https://github.com/$author/$repository/commit/$commit_sha1"
  elif [[ "$host" == "azure-devops-server" ]] || [[ "$host" == "azure-devops-services" ]]; then
    read -r host organization project repository <<< "$(get-git-remote-details)"
    local azdo_repository_url
    azdo_repository_url=$(get-azure-devops-repository-url "$host" "$organization" "$project" "$repository")
    commit_url="$azdo_repository_url/commit/$commit_sha1"
  else
    echo "Unknown git remote host: $host" >&2
    return 1
  fi

  o "$commit_url"
)

# "gcu" is short for "git commit undo", which will undo the last commit locally (but not on the
# remote). You can also provide a number argument to undo the last N commits.
gcu() (
  set -euo pipefail # Exit on errors and undefined variables.

  assert-in-git-repository

  local num_commits=1
  if [[ -n "${1:-}" ]]; then
    if [[ "$1" =~ ^[0-9]+$ ]]; then
      num_commits="$1"
    else
      echo "Error: The argument of \"$1\" is not a number." >&2
      return 1
    fi
  fi

  git reset "HEAD~$num_commits" --soft
)

# "gd" is short for "git diff".
alias gd="git diff"

# "gl" is short for "git log".
alias gl="git log"

# "glg" is short for "git log --graph" with specific formatting.
alias glg="git log --graph --pretty=format:'%C(yellow)%h%Creset %C(cyan)%d%Creset %C(white)%s%Creset %C(green)(%an)%Creset%n%w(0,8,8)%b%Creset' --all --decorate"

# "gmc" is short for "git merge conflicts", which will show the files that need to be resolved
# before the merge/rebase/whatever can proceed.
alias gmc="git diff --name-only --diff-filter=U"

# "gmco" is short for "git merge conflicts open", which is similar to "gmc", but will open all of
# the files that need to be resolved in Visual Studio Code.
gmco() (
  set -euo pipefail # Exit on errors and undefined variables.

  assert-in-git-repository

  local repo_root
  repo_root=$(git rev-parse --show-toplevel)

  local conflicted_files=()
  local conflicted_file
  while IFS= read -r -d "" conflicted_file; do
    conflicted_files+=("$repo_root/$conflicted_file")
  done < <(git -C "$repo_root" diff --name-only --diff-filter=U -z)

  if [[ "${#conflicted_files[@]}" -eq 0 ]]; then
    echo "Error: There are no merge conflicts in this repository." >&2
    return 1
  fi

  code "${conflicted_files[@]}"
)

# "gp" is short for "git pull". (We always include the "--rebase" and "--prune" flags, since they
# are best practice.)
alias gp="git pull --rebase --prune"

# "gpm" is short for "git pull mine", which will fetch all remote branches that start with
# "feature/misc/[username]/" and create local tracking branches for them if they do not already
# exist.
gpm() (
  set -euo pipefail # Exit on errors and undefined variables.

  assert-in-git-repository

  git fetch origin --prune --quiet

  local username
  username=$(get-username)
  local prefix="feature/$username/"

  # We use "--list" to filter the branches directly via Git.
  local remote_branches
  remote_branches=$(git branch --remotes --format="%(refname:lstrip=2)" --list "origin/$prefix*")

  if [[ -z "$remote_branches" ]]; then
    return
  fi

  echo "$remote_branches" | while IFS= read -r remote_branch; do
    local local_branch="${remote_branch#origin/}"

    if git show-ref --verify --quiet "refs/heads/$local_branch"; then
      # Mimic the output of "git branch --track".
      echo "branch '$local_branch' also exists locally."
    else
      git branch --track "$local_branch" "$remote_branch"
    fi
  done

  gbl
)

# "gpr" is short for "git pull request", to start a new pull request based on the current branch.
# The arguments that are provided will be the pull request title. If no arguments are provided, then
# the script will attempt to find a suitable pull request title.
# You can use the "--check" flag to only check whether a pull request already exists.
gpr() (
  set -euo pipefail # Exit on errors and undefined variables.

  local check_only="false"
  local positional_args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --check)
        check_only="true"
        shift
        ;;
      *)
        positional_args+=("$1")
        shift
        ;;
    esac
  done
  set -- "${positional_args[@]}" # Restore positional parameters.

  assert-in-git-repository
  assert-feature-branch

  local branch_name
  branch_name=$(git branch --show-current)

  local main_branch_name
  main_branch_name=$(get-main-branch-name)

  local git_diff
  git_diff=$(git diff "$main_branch_name"...HEAD)

  if [[ -z "$git_diff" ]]; then
    echo "Error: There are no changes between this branch and the \"$main_branch_name\" branch." >&2
    return 1
  fi

  if is-github-repository; then
    # If no default repository is set, set it. This is necessary to prevent the error:
    # No default remote repository has been set. To learn more about the default repository, run:
    # gh repo set-default --help
    if [[ -z "$(gh repo set-default --view 2> /dev/null)" ]]; then
      local origin_url
      origin_url=$(git remote get-url origin)
      local origin_repo
      origin_repo=$(echo "$origin_url" | sed -E 's|.*github\.com[:/]||; s|\.git$||')
      local parent_repo
      parent_repo=$(gh repo view "$origin_repo" --json isFork,parent --jq 'if .isFork then (.parent.owner.login + "/" + .parent.name) else "" end' 2> /dev/null)
      if [[ -n "$parent_repo" ]]; then
        gh repo set-default "$parent_repo"
      fi
    fi

    if [[ "$check_only" == "true" ]]; then
      local existing_pull_request_url
      if existing_pull_request_url=$(gh pr view --json url --jq .url 2> /dev/null); then
        o "$existing_pull_request_url"
        echo "Pull request already exists: $existing_pull_request_url"
      else
        echo "No active pull request exists for branch: $branch_name"
      fi
      return
    fi

    gh pr create --fill-first --web
    return
  fi

  assert-jq-installed

  read -r host organization project repository <<< "$(get-git-remote-details)"
  assert-azure-devops-host "$host"

  # Validate that the remote branch exists.
  if ! git ls-remote --heads origin "$branch_name" | grep --quiet .; then
    echo "Error: The \"$branch_name\" branch does not exist on the remote host: $host" >&2
    return 1
  fi

  # First, check for an existing pull request.
  local azdo_api_url
  azdo_api_url=$(get-azure-devops-pull-requests-api-url "$host" "$organization" "$project" "$repository")

  local personal_access_token
  personal_access_token=$(get-azure-devops-personal-access-token "$host")

  local api_response_check
  api_response_check=$(get-azure-devops-active-pull-request-response-for-current-branch)

  local pull_request_count
  pull_request_count=$(echo "$api_response_check" | jq -r '.count')

  local azdo_repository_url
  azdo_repository_url=$(get-azure-devops-repository-url "$host" "$organization" "$project" "$repository")
  local azdo_pull_request_url_prefix="$azdo_repository_url/pullrequest"

  if [[ "$pull_request_count" != "0" ]]; then
    local existing_pull_request_id
    existing_pull_request_id=$(echo "$api_response_check" | jq -r '.value[0].pullRequestId')

    local existing_pull_request_url="$azdo_pull_request_url_prefix/$existing_pull_request_id"
    o "$existing_pull_request_url"

    echo "Pull request already exists: $existing_pull_request_url"
    return
  fi

  if [[ "$check_only" == "true" ]]; then
    echo "No active pull request exists for branch: $branch_name"
    return
  fi

  # Second, use the Azure DevOps API to open a new pull request.
  local pull_request_text
  if [[ $# -eq 0 ]]; then
    if [[ -z "${GITHUB_TOKEN_WORK:-${GITHUB_TOKEN:-}}" ]]; then
      # If the user does not have an API key, use a generic pull request title and description.
      echo "Using the first commit description as the pull request title & description."
      pull_request_text=$(get-first-branch-commit-description)
    else
      if [[ $(get-num-commits-on-branch) == "1" ]]; then
        echo "Using the only commit description as the pull request title & description."
        pull_request_text=$(get-first-branch-commit-description)
      else
        echo "Getting the pull request title & description from an LLM..."
        pull_request_text=$(get-llm-pull-request-text)
      fi
    fi
  else
    pull_request_text="$*"
  fi

  local pull_request_title
  pull_request_title=$(echo "$pull_request_text" | head -n 1)

  local pull_request_description
  pull_request_description=$(echo "$pull_request_text" | tail -n +2 | remove-leading-and-trailing-whitespace)
  if [[ -z "$pull_request_description" ]]; then
    pull_request_description="n/a"
  fi

  local json_payload
  json_payload=$(jq --null-input \
    --arg source "refs/heads/$branch_name" \
    --arg target "refs/heads/$main_branch_name" \
    --arg title "$pull_request_title" \
    --arg desc "$pull_request_description" \
    '{sourceRefName: $source, targetRefName: $target, title: $title, description: $desc}')

  local response_body
  response_body=$(mktemp)
  trap 'rm -f "$response_body"' EXIT

  curl \
    --silent \
    --fail \
    --show-error \
    --location \
    --output "$response_body" \
    --user ":$personal_access_token" \
    --header "Content-Type: application/json" \
    --data "$json_payload" \
    "$azdo_api_url" || {
    local err="$?"
    echo "curl failed on URL: $azdo_api_url" >&2
    echo "data was:"
    echo "$json_payload"
    return "$err"
  }

  # Finally, open the new pull request in a browser so that the user can confirm that everything
  # looks okay.
  local pull_request_id
  pull_request_id=$(jq -r '.pullRequestId' "$response_body")

  if [[ "$repository" == "LogixApplications" ]]; then
    local work_item_id="248890"
    local project_id
    project_id=$(jq -er '.repository.project.id' "$response_body")
    local repository_id
    repository_id=$(jq -er '.repository.id' "$response_body")
    local pull_request_artifact_url="vstfs:///Git/PullRequestId/${project_id}%2F${repository_id}%2F${pull_request_id}"

    local work_item_payload
    work_item_payload=$(jq --null-input \
      --arg artifact_url "$pull_request_artifact_url" \
      '[{
        op: "add",
        path: "/relations/-",
        value: {
          rel: "ArtifactLink",
          url: $artifact_url,
          attributes: {name: "Pull Request"}
        }
      }]')

    local azdo_project_url
    azdo_project_url=$(get-azure-devops-project-url "$host" "$organization" "$project")
    local work_item_api_url="$azdo_project_url/_apis/wit/workitems/$work_item_id?api-version=7.0"

    curl \
      --silent \
      --fail \
      --show-error \
      --location \
      --request PATCH \
      --output /dev/null \
      --user ":$personal_access_token" \
      --header "Content-Type: application/json-patch+json" \
      --data "$work_item_payload" \
      "$work_item_api_url" || {
      local err="$?"
      echo "Failed to attach work item #$work_item_id to pull request $pull_request_id." >&2
      echo "curl failed on URL: $work_item_api_url" >&2
      return "$err"
    }
  fi

  local pull_request_url="$azdo_pull_request_url_prefix/$pull_request_id"
  echo "Created pull request: $pull_request_url"
  o "$pull_request_url"
)

# "gpr-dry" is similar to "gpr", but will just open the URL that will begin the process of creating
# the pull request instead of actually fully opening the pull request. This is useful to see the
# files changed on the branch.
gpr-dry() (
  set -euo pipefail # Exit on errors and undefined variables.

  assert-in-git-repository
  assert-feature-branch

  read -r host organization project repository <<< "$(get-git-remote-details)"
  if [[ "$host" != "azure-devops-server" ]]; then
    echo "Error: The ${FUNCNAME[0]} command cannot be used with host: $host" >&2
    return 1
  fi

  local branch_name
  branch_name=$(git branch --show-current)

  local azdo_repository_url
  azdo_repository_url=$(get-azure-devops-repository-url "$host" "$organization" "$project" "$repository")
  local pr_url="$azdo_repository_url/pullrequestcreate?sourceRef=$branch_name"
  o "$pr_url"
)

# "gprf" is short for "git pull request fix".
gprf() (
  set -euo pipefail # Exit on errors and undefined variables.

  assert-in-git-repository

  if [[ -z "${REPOSITORIES_DIR:-}" ]]; then
    echo "Error: You can only use this command if your repositories directory is in one of the standard locations." >&2
    exit 1
  fi

  local scripts_path="$REPOSITORIES_DIR/infrastructure/0-global-library/typescript-scripts"
  if [[ ! -d "$scripts_path" ]]; then
    echo "Error: The directory does not exist at: $scripts_path" >&2
    exit 1
  fi

  read -r _host _organization _project repository <<< "$(get-git-remote-details)"
  builtin cd "$scripts_path"
  bun run set-auto-reviewers-required "$repository"
)

# "gprh" is short for "git pull request hack".
gprh() (
  set -euo pipefail # Exit on errors and undefined variables.

  assert-in-git-repository
  assert-feature-branch

  if [[ -z "${REPOSITORIES_DIR:-}" ]]; then
    echo "Error: You can only use this command if your repositories directory is in one of the standard locations." >&2
    exit 1
  fi

  local scripts_path="$REPOSITORIES_DIR/infrastructure/0-global-library/typescript-scripts"
  if [[ ! -d "$scripts_path" ]]; then
    echo "Error: The directory does not exist at: $scripts_path" >&2
    exit 1
  fi

  read -r _host _organization _project repository <<< "$(get-git-remote-details)"

  local pull_request_id
  pull_request_id=$(get-azure-devops-active-pull-request-id-for-current-branch)

  builtin cd "$scripts_path"
  bun run remove-all-reviewers-from-pull-request "$repository" "$pull_request_id"
)

# "grb" is short for "git rebase".
alias grb="git rebase"

# "grba" is short for "git rebase --abort".
alias grba="git rebase --abort"

# "grbc" is short for "git rebase --continue". (It will automatically add all files for you.)
grbc() (
  set -euo pipefail # Exit on errors and undefined variables.

  assert-in-git-repository

  git add --all
  # "--no-edit" does not exist for "git rebase", so we have to use the "GIT_EDITOR" environment
  # variable to prevent vim from opening.
  GIT_EDITOR=true git rebase --continue
  git push --force-with-lease
)

# "grbm" is short for "git rebase main".
grbm() (
  set -euo pipefail # Exit on errors and undefined variables.

  assert-in-git-repository
  assert-feature-branch

  local main_branch_name
  main_branch_name=$(get-main-branch-name)

  git fetch origin "$main_branch_name" --prune --quiet
  git branch -f "$main_branch_name" "origin/$main_branch_name" # Update the local branch.
  git rebase "origin/$main_branch_name"
  git push --force-with-lease
)

# "grm" is short for "git remote -v".
alias grm="git remote -v"

# "grms" is short for "git remote ssh", which changes the current Git remote from HTTPS to SSH.
grms() (
  set -euo pipefail # Exit on errors and undefined variables.

  assert-in-git-repository

  local remote_url
  remote_url=$(git remote get-url origin)

  if [[ "$remote_url" == git@* ]] || [[ "$remote_url" == ssh://* ]]; then
    echo "The remote is already set to SSH: $remote_url"
    return
  fi

  local new_url
  if [[ "$remote_url" =~ ^https://github\.com/([^/]+)/([^/]+)(\.git)?$ ]]; then
    local user="${BASH_REMATCH[1]}"
    local repo="${BASH_REMATCH[2]}"
    repo="${repo%.git}"
    new_url="git@github.com:$user/$repo.git"
  elif [[ "$remote_url" =~ ^https://dev\.azure\.com/([^/]+)/([^/]+)/_git/([^/]+)$ ]]; then
    local organization="${BASH_REMATCH[1]}"
    local project="${BASH_REMATCH[2]}"
    local repository="${BASH_REMATCH[3]}"
    new_url="git@ssh.dev.azure.com:v3/$organization/$project/$repository"
  else
    echo "Error: Unsupported remote URL format for automatic conversion: $remote_url" >&2
    return 1
  fi

  git remote set-url origin "$new_url"
  echo "Changed remote origin to SSH: $new_url"
)

# "grs" is short for "git reset".
alias grs="git reset"

# "grsh" is short for "git reset --hard".
alias grsh="git reset --hard"

# "grshm" is short for "git reset --hard origin/main".
grshm() (
  set -euo pipefail # Exit on errors and undefined variables.

  assert-in-git-repository
  assert-feature-branch

  local main_branch_name
  main_branch_name=$(get-main-branch-name)

  git reset --hard "origin/$main_branch_name"
  git push --force-with-lease
)

# "grt" is short for "git restore".
grt() (
  set -euo pipefail # Exit on errors and undefined variables.

  assert-in-git-repository

  if [[ -z "${1-}" ]]; then
    echo "Error: One or more file paths are required." >&2
    return 1
  fi

  local branch_name
  branch_name=$(git branch --show-current)

  local main_branch_name
  main_branch_name=$(get-main-branch-name)

  # On the main branch, restore the file(s) from the last commit. On a feature branch, restore the
  # file(s) from the main branch.
  local source_ref
  if [[ "$branch_name" == "$main_branch_name" ]]; then
    source_ref="HEAD"
  else
    source_ref="$main_branch_name"
  fi

  # We use "git checkout" instead of "git restore" since it works in more situations.
  git checkout "$source_ref" -- "$@"
)

# "grv" is short for "git revert".
grv() (
  set -euo pipefail # Exit on errors and undefined variables.

  assert-in-git-repository

  if [[ -z "${1:-}" ]]; then
    echo "Error: Commit SHA1 is required. Usage: ${FUNCNAME[0]} <commit_sha1>" >&2
    return 1
  fi
  local commit_sha1="$1"

  # The "--no-edit" flag uses the default commit message.
  git revert --no-edit "$commit_sha1"
  git push
)

# "grva" is short for "git revert --abort".
alias grva="git revert --abort"

# "grvc" is short for "git revert --continue". (It will automatically add all files for you.)
grvc() (
  set -euo pipefail # Exit on errors and undefined variables.

  assert-in-git-repository

  git add --all
  git revert --continue
)

# "grvl" is short for "git revert last".
grvl() (
  set -euo pipefail # Exit on errors and undefined variables.

  assert-in-git-repository

  # "--no-edit" avoids prompting for a commit message and uses the default commit message.
  git revert HEAD --no-edit
  git push
  gcs
)

# "gs" is short for "git status --porcelain". (The "--porcelain" flag is preferred since the output
# is more terse.)
alias gs="git status --porcelain"

# "gsh" is short for "git show".
alias gsh="git show"

# "gsq" stands for "git squash", to squash N commits together.
gsq() (
  set -euo pipefail # Exit on errors and undefined variables.

  assert-in-git-repository

  if [[ -z "${1:-}" ]]; then
    echo "Error: You must provide the number of commits to squash." >&2
    return 1
  fi
  local number_of_commits="$1"

  local commit_message
  if [[ -z "${2:-}" ]]; then
    commit_message="chore: squash $number_of_commits commits"
  else
    commit_message="$2"
  fi

  git reset --soft "HEAD~$number_of_commits"
  git commit --message "$commit_message"
  git push --force-with-lease
)

# "gsp" is short for "git split", which moves changes for a file path or commit to a new branch and
# then removes those changes from the current branch.
gsp() (
  set -euo pipefail # Exit on errors and undefined variables.

  assert-in-git-repository
  assert-feature-branch

  if [[ -z "${1:-}" ]]; then
    echo "Error: A file path or commit SHA1 is required. Usage: ${FUNCNAME[0]} <file-path-or-commit-sha1> <branch-name>" >&2
    return 1
  fi
  local source="$1"

  if [[ -z "${2:-}" ]]; then
    echo "Error: The branch name is required. Usage: ${FUNCNAME[0]} <file-path-or-commit-sha1> <branch-name>" >&2
    return 1
  fi
  local new_branch_name="$2"

  if ! is-github-repository; then
    local username
    username=$(get-username)
    new_branch_name="feature/$username/$new_branch_name"
  fi

  if ! git check-ref-format "refs/heads/$new_branch_name"; then
    echo "Error: The branch name of \"$new_branch_name\" contains illegal characters." >&2
    return 1
  fi

  if [[ -n "$(git status --porcelain)" ]]; then
    echo "Error: The repository is not clean. Commit or stash your changes before splitting a file to a new branch." >&2
    return 1
  fi

  local current_branch_name
  current_branch_name=$(git branch --show-current)
  if [[ "$new_branch_name" == "$current_branch_name" ]]; then
    echo "Error: The branch name of \"$new_branch_name\" is the current branch." >&2
    return 1
  fi

  local merge_base
  merge_base=$(get-merge-base)

  local patch_file
  patch_file=$(mktemp)
  trap 'rm -f "$patch_file"' EXIT

  local split_description
  if [[ "$source" =~ ^[0-9a-fA-F]{4,40}$ ]] && git rev-parse --verify --quiet "$source^{commit}" &> /dev/null; then
    local commit_sha1
    commit_sha1=$(git rev-parse "$source^{commit}")
    if [[ "$commit_sha1" == "$merge_base" ]] \
      || ! git merge-base --is-ancestor "$merge_base" "$commit_sha1" \
      || ! git merge-base --is-ancestor "$commit_sha1" "$current_branch_name"; then
      echo "Error: Commit \"$source\" is not part of the current branch changes." >&2
      return 1
    fi

    local file_paths=()
    local file_paths_file
    file_paths_file=$(mktemp)
    trap 'rm -f "$patch_file" "$file_paths_file"' EXIT
    git diff-tree --no-commit-id --name-only --no-renames --root -r -z "$commit_sha1" > "$file_paths_file"
    while IFS= read -r -d "" file_path; do
      file_paths+=("$file_path")
    done < "$file_paths_file"

    if [[ ${#file_paths[@]} -eq 0 ]]; then
      echo "Error: Commit \"$source\" does not change any files." >&2
      return 1
    fi

    if git diff --quiet "$merge_base" "$current_branch_name" -- "${file_paths[@]}"; then
      echo "Error: There are no branch changes for files from commit \"$source\" to split." >&2
      return 1
    fi

    git diff --binary "$merge_base" "$current_branch_name" -- "${file_paths[@]}" > "$patch_file"
    split_description="files from commit $commit_sha1"
  else
    if git diff --quiet "$merge_base" "$current_branch_name" -- "$source"; then
      echo "Error: There are no branch changes for \"$source\" to split." >&2
      return 1
    fi

    git diff --binary "$merge_base" "$current_branch_name" -- "$source" > "$patch_file"
    split_description="file $source"
  fi

  if git show-ref --verify --quiet "refs/heads/$new_branch_name"; then
    git switch "$new_branch_name"
  elif git show-ref --verify --quiet "refs/remotes/origin/$new_branch_name"; then
    git switch --create "$new_branch_name" --track "origin/$new_branch_name"
  else
    git switch --create "$new_branch_name" "$merge_base"
  fi
  git apply --index "$patch_file"
  git commit --message "chore: split changes from $split_description"
  git push

  git switch "$current_branch_name"
  git apply --reverse --index "$patch_file"
  git commit --message "chore: remove changes from $split_description"
  git push
)

# "gst" is short for "git stash".
alias gst="git stash"

# "gstd" is short for "git stash drop".
alias gstd="git stash drop"

# "gstl" is short for "git stash list".
alias gstl="git stash list"

# "gstp" is short for "git stash pop"
alias gstp="git stash pop"

# "gsw" is short for "git switch". It requires an argument of the number corresponding to the
# alphabetical local branch. ("gs" is already taken by another command.)
gsw() (
  set -euo pipefail # Exit on errors and undefined variables.

  assert-in-git-repository

  local main_branch_name
  main_branch_name=$(get-main-branch-name)

  if [[ -z "${1:-}" ]]; then
    echo "Error: Branch name or number is required. Usage: ${FUNCNAME[0]} <branch-name-or-number>" >&2
    return 1
  fi
  local branch_name_or_number="$1"

  local branch_name
  branch_name=$(get-branch-name-from-number "$branch_name_or_number")

  git switch "$branch_name"
)

# "gswc" is short for "git switch -c". (However, the "gb" command should be used in most contexts.)
alias gswc="git switch -c"

# "gswm" is short for "git switch main".
gswm() (
  set -euo pipefail # Exit on errors and undefined variables.

  assert-in-git-repository

  local main_branch_name
  main_branch_name=$(get-main-branch-name)

  if [[ -n "$(git status --porcelain)" ]]; then
    echo "The repository is not clean. Stashing all of your existing changes."
    git stash push --message "Auto-stash before switching to $main_branch_name"
  fi

  if [[ "$(git branch --show-current)" != "$main_branch_name" ]]; then
    git switch "$main_branch_name"
  fi

  add-upstream-remote-if-github-fork

  if git remote get-url upstream &> /dev/null; then
    gh-sync
  else
    git fetch origin --prune --quiet
    git rebase "origin/$main_branch_name"
  fi

  gbcl --skip-fetch # git branch clean
  git stash list
)

# "gtc" is short for "git tags clean", which will remote all local tags that do not exist on the
# remote repository.
# https://stackoverflow.com/questions/1841341/remove-local-git-tags-that-are-no-longer-on-the-remote-repository
gtc() (
  set -euo pipefail # Exit on errors and undefined variables.

  assert-in-git-repository

  git tag -l | xargs git tag -d
  git fetch --tags

  echo
  echo "Current git tags:"
  git tag
)

# "gu" is short for "git push".
alias gu="git push"

# "guf" is short for "git push --force-with-lease".
alias guf="git push --force-with-lease"

# "guo" is short for "git unclean open", which will open all of the unstaged modified and untracked
# files in this repository inside Visual Studio Code. This command will throw an error if there are 10
# or more changed files.
guo() (
  set -euo pipefail # Exit on errors and undefined variables.

  assert-in-git-repository

  local -a changed_files
  mapfile -d "" -t changed_files < <(
    git diff --name-only --diff-filter=ACMRT -z
    git ls-files --others --exclude-standard -z
  )

  if [[ "${#changed_files[@]}" -eq 0 ]]; then
    echo "Error: There are no unstaged modified or untracked files in this repository." >&2
    return 1
  fi

  local num_changed_files
  num_changed_files="${#changed_files[@]}"

  if [[ "$num_changed_files" -ge 10 ]]; then
    echo "Error: There are $num_changed_files unstaged modified or untracked files in this repository. This command only supports repositories with fewer than 10 changed files." >&2
    return 1
  fi

  printf "%s\n" "${changed_files[@]}"
  code "${changed_files[@]}"
)

# "gwa" is short for "git worktree add". (We do not use a subshell because we need to change the
# current working directory.)
gwa() {
  local new_worktree_directory
  new_worktree_directory=$(get-new-worktree-directory)
  builtin cd "$new_worktree_directory"
  git push

  if [[ -f "$new_worktree_directory/package-lock.json" ]]; then
    npm ci
  fi

  if [[ -f "$new_worktree_directory/bun.lock" ]]; then
    bun ci
  fi

  if [[ -f "$new_worktree_directory/uv.lock" ]]; then
    uv sync --frozen
  fi
}

# "gwd" is short for "git worktree delete". (Even though the real command is "git worktree remove",
# we use "gwd" to maintain parity with "gbd".) Note that this will only delete the worktree, not the
# branch.
gwd() (
  set -euo pipefail # Exit on errors and undefined variables.

  assert-in-git-repository

  if [[ -z "${1:-}" ]]; then
    echo "Error: Worktree path or number is required. Usage: ${FUNCNAME[0]} <worktree-path-or-number>" >&2
    return 1
  fi
  local worktree_path_or_number="$1"

  local worktree_path
  worktree_path=$(get-worktree-path-from-number "$worktree_path_or_number")

  local listed_worktree_path
  listed_worktree_path=$(git worktree list | awk '{print $1}' | grep --line-regexp --fixed-strings "$worktree_path" || true)
  if [[ -z "$listed_worktree_path" ]]; then
    echo "Error: Worktree \"$worktree_path\" does not exist." >&2
    return 1
  fi

  local current_worktree_path
  current_worktree_path=$(git rev-parse --show-toplevel)
  if [[ "$worktree_path" == "$current_worktree_path" ]]; then
    echo "Error: You are removing worktree \"$worktree_path\", but that is your current worktree. Switch to another worktree first." >&2
    return 1
  fi

  git worktree remove "$worktree_path"
  echo "Deleted worktree: $worktree_path"

  echo
  gwl
)

# "gwl" is short for "git worktree list".
gwl() (
  set -euo pipefail # Exit on errors and undefined variables.

  assert-in-git-repository

  local worktrees
  worktrees=$(git worktree list)

  local total_lines
  total_lines=$(echo "$worktrees" | wc -l | tr -d '[:space:]')
  local width=${#total_lines}

  echo "Current git worktrees:"

  local count=1
  while IFS= read -r worktree; do
    printf "  %*d - %s\n" "$width" "$count" "$worktree"
    ((count++))
  done <<< "$worktrees"
)
