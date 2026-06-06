# ----------------
# Helper functions
# ----------------

add-logix-cert-to-requests-ca-bundle() (
  set -euo pipefail # Exit on errors and undefined variables.

  if [[ -z "${REQUESTS_CA_BUNDLE:-}" ]]; then
    return
  fi

  if [[ ! -s "$REQUESTS_CA_BUNDLE" ]]; then
    echo "Error: The \"REQUESTS_CA_BUNDLE\" environment variable is set to \"$REQUESTS_CA_BUNDLE\", but this file does not exist or is 0 bytes." >&2
    return 1
  fi

  local certificate_name="BEDROOTCA001"
  if ! grep --quiet "$certificate_name" "$REQUESTS_CA_BUNDLE"; then
    echo "Error: The \"REQUESTS_CA_BUNDLE\" environment variable is set to \"$REQUESTS_CA_BUNDLE\", but this file does not have the \"$certificate_name\" certificate in it." >&2
    local file_path="$REQUESTS_CA_BUNDLE"
    if command -v cygpath &> /dev/null; then
      file_path=$(cygpath --windows "$file_path")
    fi

    echo >&2
    echo "Run this command to fix it:" >&2
    echo >&2
    echo "{ echo; echo \"# $certificate_name\"; curl --silent --fail --show-error --location \"https://raw.githubusercontent.com/Zamiell/configs/refs/heads/main/certs/$certificate_name.crt\"; } | sudo tee -a \"$REQUESTS_CA_BUNDLE\" > /dev/null" >&2
    return 1
  fi
)

# We do not use a subshell because the changes to PATH would be lost.
append-path() {
  if [[ -z "${1:-}" ]]; then
    echo "Error: The directory path is required. Usage: ${FUNCNAME[0]} <path>" >&2
    return 1
  fi
  local directory_path="$1"

  # Check if the directory exists and is not already in the PATH.
  if [[ -d "$directory_path" ]] && [[ ":$PATH:" != *":$directory_path:"* ]]; then
    export PATH="$directory_path:$PATH"
  fi
}

assert-azure-devops-host() (
  set -euo pipefail # Exit on errors and undefined variables.

  if [[ -z "${1:-}" ]]; then
    echo "Error: The host is required. Usage: ${FUNCNAME[0]} <host>" >&2
    return 1
  fi
  local host="$1"

  if [[ "$host" != "azure-devops-server" ]] && [[ "$host" != "azure-devops-services" ]]; then
    local caller="${FUNCNAME[1]:-${FUNCNAME[0]}}"
    echo "Error: The $caller command cannot be used with host: $host" >&2
    return 1
  fi
)

assert-feature-branch() (
  set -euo pipefail # Exit on errors and undefined variables.

  local branch_name
  branch_name=$(git branch --show-current)

  local main_branch_name
  main_branch_name=$(get-main-branch-name)

  if [[ "$branch_name" == "$main_branch_name" ]]; then
    echo "Error: This command is intended to be run on a feature branch and you are currently on the \"$main_branch_name\" branch." >&2
    return 1
  fi
)

assert-in-git-repository() (
  set -euo pipefail # Exit on errors and undefined variables.

  local directory_path="${1-}"
  if [[ -z "$directory_path" ]]; then
    directory_path="$PWD"
  fi

  if [[ ! -d "$directory_path" ]]; then
    echo "Error: The provided directory path does not exist: $directory_path" >&2
    return 1
  fi

  if ! git -C "$directory_path" rev-parse --is-inside-work-tree &> /dev/null; then
    echo "Error: The \"$directory_path\" directory path is not inside a Git repository." >&2
    return 1
  fi
)

assert-in-github-repository() (
  set -euo pipefail # Exit on errors and undefined variables.

  local directory_path="${1-}"
  if [[ -z "$directory_path" ]]; then
    directory_path="$PWD"
  fi

  assert-in-git-repository "$directory_path"

  if ! is-github-repository; then
    echo "Error: The \"$directory_path\" directory path is not inside a GitHub repository." >&2
    return 1
  fi
)

assert-jq-installed() (
  set -euo pipefail # Exit on errors and undefined variables.

  if ! command -v jq &> /dev/null; then
    echo "Error: jq is required to use this command. If you are on Windows, you can install it with: winget install --exact --id jqlang.jq" >&2
    return 1
  fi
)

assert-main-branch() (
  set -euo pipefail # Exit on errors and undefined variables.

  local branch_name
  branch_name=$(git branch --show-current)

  local main_branch_name
  main_branch_name=$(get-main-branch-name)

  if [[ "$branch_name" != "$main_branch_name" ]]; then
    echo "Error: This command is intended to be run on the \"$main_branch_name\" branch and you are currently on the \"$branch_name\" branch." >&2
    return 1
  fi
)

get-azure-devops-active-pull-request-id-for-current-branch() (
  set -euo pipefail # Exit on errors and undefined variables.

  assert-in-git-repository
  assert-feature-branch
  assert-jq-installed

  local branch_name
  branch_name=$(git branch --show-current)

  local api_response_check
  api_response_check=$(get-azure-devops-active-pull-request-response-for-current-branch)

  local pull_request_count
  pull_request_count=$(echo "$api_response_check" | jq -r '.count')
  if [[ "$pull_request_count" == "0" ]]; then
    echo "Error: No active pull request exists for branch: $branch_name" >&2
    return 1
  fi

  if [[ "$pull_request_count" != "1" ]]; then
    echo "Error: Found $pull_request_count active pull requests for branch: $branch_name" >&2
    return 1
  fi

  jq -r '.value[0].pullRequestId' <<< "$api_response_check"
)

get-azure-devops-active-pull-request-response-for-current-branch() (
  set -euo pipefail # Exit on errors and undefined variables.

  assert-in-git-repository
  assert-feature-branch
  assert-jq-installed

  local branch_name
  branch_name=$(git branch --show-current)

  read -r host organization project repository <<< "$(get-git-remote-details)"
  assert-azure-devops-host "$host"

  local personal_access_token
  personal_access_token=$(get-azure-devops-personal-access-token "$host")

  local azdo_api_url
  azdo_api_url=$(get-azure-devops-pull-requests-api-url "$host" "$organization" "$project" "$repository")
  local azdo_api_url_check="$azdo_api_url&searchCriteria.sourceRefName=refs/heads/$branch_name&searchCriteria.status=active"

  curl \
    --silent \
    --fail \
    --show-error \
    --location \
    --user ":$personal_access_token" \
    "$azdo_api_url_check" || {
    local err="$?"
    echo "curl failed on URL: $azdo_api_url_check" >&2
    return "$err"
  }
)

get-azure-devops-domain() (
  set -euo pipefail # Exit on errors and undefined variables.

  if [[ -z "${1:-}" ]]; then
    echo "Error: The host is required. Usage: ${FUNCNAME[0]} <host>" >&2
    return 1
  fi
  local host="$1"

  if [[ "$host" == "azure-devops-server" ]]; then
    echo "azuredevops.logixhealth.com"
  elif [[ "$host" == "azure-devops-services" ]]; then
    echo "dev.azure.com"
  else
    echo "Error: The Azure DevOps host is invalid: $host" >&2
    return 1
  fi
)

get-azure-devops-personal-access-token() (
  set -euo pipefail # Exit on errors and undefined variables.

  if [[ -z "${1:-}" ]]; then
    echo "Error: The host is required. Usage: ${FUNCNAME[0]} <host>" >&2
    return 1
  fi
  local host="$1"

  if [[ "$host" == "azure-devops-server" ]]; then
    if [[ -z "${AZDO_PERSONAL_ACCESS_TOKEN_SERVER:-}" ]]; then
      echo "Error: The \"AZDO_PERSONAL_ACCESS_TOKEN_SERVER\" environment variable is not set." >&2
      return 1
    fi

    echo "$AZDO_PERSONAL_ACCESS_TOKEN_SERVER"
  elif [[ "$host" == "azure-devops-services" ]]; then
    if [[ -z "${AZDO_PERSONAL_ACCESS_TOKEN_SERVICES:-}" ]]; then
      echo "Error: The \"AZDO_PERSONAL_ACCESS_TOKEN_SERVICES\" environment variable is not set." >&2
      return 1
    fi

    echo "$AZDO_PERSONAL_ACCESS_TOKEN_SERVICES"
  else
    echo "Error: The Azure DevOps host is invalid: $host" >&2
    return 1
  fi
)

get-azure-devops-project-url() (
  set -euo pipefail # Exit on errors and undefined variables.

  if [[ -z "${1:-}" ]]; then
    echo "Error: The host is required. Usage: ${FUNCNAME[0]} <host> <organization> <project>" >&2
    return 1
  fi
  local host="$1"

  if [[ -z "${2:-}" ]]; then
    echo "Error: The organization is required. Usage: ${FUNCNAME[0]} <host> <organization> <project>" >&2
    return 1
  fi
  local organization="$2"

  if [[ -z "${3:-}" ]]; then
    echo "Error: The project is required. Usage: ${FUNCNAME[0]} <host> <organization> <project>" >&2
    return 1
  fi
  local project="$3"

  local domain
  domain=$(get-azure-devops-domain "$host")

  echo "https://$domain/$organization/$project"
)

get-azure-devops-pull-requests-api-url() (
  set -euo pipefail # Exit on errors and undefined variables.

  if [[ -z "${1:-}" ]]; then
    echo "Error: The host is required. Usage: ${FUNCNAME[0]} <host> <organization> <project> <repository>" >&2
    return 1
  fi
  local host="$1"

  if [[ -z "${2:-}" ]]; then
    echo "Error: The organization is required. Usage: ${FUNCNAME[0]} <host> <organization> <project> <repository>" >&2
    return 1
  fi
  local organization="$2"

  if [[ -z "${3:-}" ]]; then
    echo "Error: The project is required. Usage: ${FUNCNAME[0]} <host> <organization> <project> <repository>" >&2
    return 1
  fi
  local project="$3"

  if [[ -z "${4:-}" ]]; then
    echo "Error: The repository is required. Usage: ${FUNCNAME[0]} <host> <organization> <project> <repository>" >&2
    return 1
  fi
  local repository="$4"

  local api_version="7.0"
  local azdo_project_url
  azdo_project_url=$(get-azure-devops-project-url "$host" "$organization" "$project")

  echo "$azdo_project_url/_apis/git/repositories/$repository/pullrequests?api-version=$api_version"
)

get-azure-devops-repository-url() (
  set -euo pipefail # Exit on errors and undefined variables.

  if [[ -z "${1:-}" ]]; then
    echo "Error: The host is required. Usage: ${FUNCNAME[0]} <host> <organization> <project> <repository>" >&2
    return 1
  fi
  local host="$1"

  if [[ -z "${2:-}" ]]; then
    echo "Error: The organization is required. Usage: ${FUNCNAME[0]} <host> <organization> <project> <repository>" >&2
    return 1
  fi
  local organization="$2"

  if [[ -z "${3:-}" ]]; then
    echo "Error: The project is required. Usage: ${FUNCNAME[0]} <host> <organization> <project> <repository>" >&2
    return 1
  fi
  local project="$3"

  if [[ -z "${4:-}" ]]; then
    echo "Error: The repository is required. Usage: ${FUNCNAME[0]} <host> <organization> <project> <repository>" >&2
    return 1
  fi
  local repository="$4"

  local azdo_project_url
  azdo_project_url=$(get-azure-devops-project-url "$host" "$organization" "$project")

  echo "$azdo_project_url/_git/$repository"
)

# This will echo back the same input if the input is not a number.
get-branch-name-from-number() (
  set -euo pipefail # Exit on errors and undefined variables.

  if [[ -z "${1:-}" ]]; then
    echo "Error: The branch name or number is required. Usage: ${FUNCNAME[0]} <branch_name_or_number>" >&2
    return 1
  fi
  local branch_name_or_number="$1"

  local branch_name
  if [[ "$branch_name_or_number" =~ ^[0-9]+$ ]]; then
    local branch_number="$branch_name_or_number"

    local local_branches
    local_branches=$(git branch --format="%(refname:lstrip=2)" | sort)

    branch_name=$(echo "$local_branches" | sed --quiet "${branch_number}p")
    if [[ -z "$branch_name" ]]; then
      echo "Error: Branch number $branch_number does not exist." >&2
      return 1
    fi
  else
    branch_name="$branch_name_or_number"
  fi

  echo "$branch_name"
)

get-first-branch-commit-description() (
  set -euo pipefail # Exit on errors and undefined variables.

  assert-in-git-repository
  assert-feature-branch

  local branch_name
  branch_name=$(git branch --show-current)

  local main_branch_name
  main_branch_name=$(get-main-branch-name)

  local merge_base
  merge_base=$(get-merge-base)

  local first_commit_hash
  first_commit_hash=$(git rev-list --reverse "$merge_base..$branch_name" | head -n 1)
  if [[ -z "$first_commit_hash" ]]; then
    echo "Error: There are no commits on this branch when compared to the \"$main_branch_name\" branch." >&2
    return 1
  fi

  printf "%s" "$(git show --no-patch --format="%B" "$first_commit_hash")"
)

get-git-remote-details() (
  set -euo pipefail

  local directory_path="${1-}"
  if [[ -z "$directory_path" ]]; then
    directory_path="$PWD"
  fi

  if [[ ! -d "$directory_path" ]]; then
    echo "Error: The provided directory path does not exist: $directory_path" >&2
    return 1
  fi

  assert-in-git-repository "$directory_path"

  local remote_url
  remote_url=$(git -C "$directory_path" remote get-url origin)

  local clean_url="${remote_url%.git}" # Remove the trailing ".git".
  local repository="${clean_url##*/}"  # Everything after the final slash.

  if [[ -z "$repository" ]]; then
    echo "Error: Unable to parse the repository from the git remote: $remote_url" >&2
    return 1
  fi

  if echo "$remote_url" | grep --quiet "github.com"; then
    local host="github"

    local author
    if [[ "$remote_url" == git@* ]]; then
      # SSH URL format: git@github.com:alice/my-repo.git
      author=$(echo "$clean_url" | sed --regexp-extended 's/^git@github\.com:([^/]+)\/.*/\1/')
    else
      # HTTPS URL format: https://github.com/alice/my-repo.git
      author=$(echo "$clean_url" | sed --regexp-extended 's|https://github\.com/([^/]+)/.*|\1|')
    fi

    # Check if we are on a branch created with "gh pr checkout".
    set-gh-remote
    local branch_name
    branch_name=$(git branch --show-current)
    local remote_config
    # This should be equal to "origin" or the GitHub username.
    remote_config=$(git -C "$directory_path" config "branch.$branch_name.remote")
    if [[ "$remote_config" != "origin" ]]; then
      author="$remote_config"
    fi

    echo "$host $author $repository"
    return
  fi

  if echo "$remote_url" | grep --quiet "dev.azure.com"; then
    local host="azure-devops-services"

    local organization
    local project
    if [[ "$remote_url" == git@ssh* ]]; then
      # git@ssh.dev.azure.com:v3/organization/project/repository
      organization=$(echo "$remote_url" | sed --regexp-extended 's|^git@ssh\.dev\.azure\.com:v3/([^/]+)/.*|\1|')
      project=$(echo "$remote_url" | sed --regexp-extended 's|^git@ssh\.dev\.azure\.com:v3/[^/]+/([^/]+)/.*|\1|')
    else
      # https://dev.azure.com/organization/project/_git/repository
      organization=$(echo "$remote_url" | awk -F'/' '{print $(NF-3)}')
      project=$(echo "$remote_url" | awk -F'/' '{print $(NF-2)}')
    fi

    echo "$host $organization $project $repository"
    return
  fi

  if echo "$remote_url" | grep --quiet "azuredevops.logixhealth.com"; then
    local host="azure-devops-server"
    local organization
    organization=$(echo "$remote_url" | awk -F'/' '{print $(NF-3)}')
    local project
    project=$(echo "$remote_url" | awk -F'/' '{print $(NF-2)}')

    echo "$host $organization $project $repository"
    return
  fi

  echo "Error: Unable to parse the host from the git remote: $remote_url" >&2
  return 1
)

# This will return a descriptive commit message based on the currently staged files.
get-llm-commit-message() (
  set -euo pipefail # Exit on errors and undefined variables.

  assert-in-git-repository

  if [[ -z "${GEMINI_API_KEY:-}" ]]; then
    echo "Error: The \"GEMINI_API_KEY\" environment variable is not set." >&2
    return 1
  fi

  local git_diff
  git_diff=$(git diff --cached)

  if [[ -z "$git_diff" ]]; then
    echo "Error: There are no staged changes in the current Git repository." >&2
    return 1
  fi

  get-llm-output-git-diff "$git_diff" "commit message"
)

get-llm-output() (
  set -euo pipefail # Exit on errors and undefined variables.

  if [[ -z "${1:-}" ]]; then
    echo "Error: The system prompt is required. Usage: ${FUNCNAME[0]} <system_prompt> <prompt>" >&2
    return 1
  fi
  local system_prompt="$1"

  if [[ -z "${2:-}" ]]; then
    echo "Error: The prompt is required. Usage: ${FUNCNAME[0]} <system_prompt> <prompt>" >&2
    return 1
  fi
  local prompt="$2"

  # Because there can be a huge amount of data in the git diff, we need to create the API response
  # all in one command. Otherwise, we get errors like "Argument list too long".
  # 1. printf pipes the prompt into jq.
  # 2. jq pipes the JSON payload into curl.
  # 3. curl reads from stdin using "--data @-".
  # Additionally, we have to use the "--ssl-no-revoke" flag with Google URLs when using curl inside
  # Git Bash for Windows, since the LogixHealth Palo Alto blocks the revocation check for some
  # reason.
  local api_url="https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=${GEMINI_API_KEY}"
  local api_response
  api_response=$(
    printf "%s" "$prompt" | jq \
      --raw-input \
      --slurp \
      --arg system_prompt_str "$system_prompt" \
      '{
      "systemInstruction": {
        "parts": [{ "text": $system_prompt_str }]
      },
      "contents": [
        { "parts": [{ "text": . }] }
      ]
     }' | curl \
      --silent \
      --fail \
      --show-error \
      --location \
      --request POST \
      --header "content-type: application/json" \
      --data @- \
      --ssl-no-revoke \
      "$api_url" || {
      local err="$?"
      echo "curl failed on URL: $api_url" >&2
      return "$err"
    }
  )

  if ! echo "$api_response" | jq --exit-status '.candidates' > /dev/null; then
    echo "Error: The LLM API returned an error:" >&2
    echo "$api_response" >&2
    return 1
  fi

  local llm_output
  llm_output=$(echo "$api_response" | jq --raw-output '.candidates[0].content.parts[0].text | select(. != null)')

  if [[ -z "$llm_output" ]]; then
    echo "Error: LLM generation failed." >&2
    return 1
  fi

  echo "$llm_output"
)

get-llm-output-git-diff() (
  set -euo pipefail # Exit on errors and undefined variables.

  if [[ -z "${1:-}" ]]; then
    echo "Error: The git diff is required. Usage: ${FUNCNAME[0]} <git_diff> <noun>" >&2
    return 1
  fi
  local git_diff="$1"

  if [[ -z "${2:-}" ]]; then
    echo "Error: The noun is required. Usage: ${FUNCNAME[0]} <git_diff> <noun>" >&2
    return 1
  fi
  local noun="$2"

  assert-jq-installed

  local system_prompt="You are an expert git commit message generator. You will be given a git diff. Your response must be only the commit message; do not include any preamble, explanation, or markdown. Be concise and descriptive. The commit message is allowed to be more than one line, but only if the changes are complicated. Follow the 50/72 rule. Follow conventional commit standards (e.g. \"feat: add new feature\", \"fix: correct bug\", \"chore: update build\"). Pay particular attention to removed lines, since if a block of code is moved from one place to another, the commit message should not say \"add\", it should say \"move\". If the file being modified is in the \"3_Applications/kubernetes\" directory, then add a commit message scope like \"feat(kubernetes): add variable\". Additionally, the subdirectories of \"3_Applications/containers\" should be scoped to their directory name in the same way. For example, modifying a file in the \"3_Applications/containers/logix-ci-cd-tasks\" directory should result in a commit message like \"feat(logix-ci-cd-tasks): add variable\"."

  local llm_output
  llm_output=$(get-llm-output "$system_prompt" "$git_diff")

  echo -e "$llm_output\n\n(This $noun was automatically generated by an LLM.)"
)

# This will return a pull request description based on differences between the current branch and
# the main branch. (Similar to a commit message, the title will be on the first line and the
# description will be on the second line, if any.)
get-llm-pull-request-text() (
  set -euo pipefail # Exit on errors and undefined variables.

  assert-in-git-repository
  assert-feature-branch

  local main_branch_name
  main_branch_name=$(get-main-branch-name)

  if [[ -z "${GEMINI_API_KEY:-}" ]]; then
    echo "Error: The \"GEMINI_API_KEY\" environment variable is not set." >&2
    return 1
  fi

  local git_diff
  git_diff=$(git diff "$main_branch_name"...HEAD)

  if [[ -z "$git_diff" ]]; then
    echo "Error: There are no changes between this branch and the \"$main_branch_name\" branch." >&2
    return 1
  fi

  get-llm-output-git-diff "$git_diff" "pull request description"
)

get-main-branch-name() (
  set -euo pipefail # Exit on errors and undefined variables.

  if git show-ref --verify --quiet refs/heads/main; then
    echo "main"
  elif git show-ref --verify --quiet refs/heads/master; then
    echo "master"
  else
    echo "Error: There was not a \"main\" branch or \"master\" branch in this repository." >&2
    return 1
  fi
)

get-merge-base() (
  set -euo pipefail # Exit on errors and undefined variables.

  local branch_name
  branch_name=$(git branch --show-current)

  local main_branch_name
  main_branch_name=$(get-main-branch-name)

  local merge_base
  merge_base=$(git merge-base "$main_branch_name" "$branch_name")
  if [[ -z "$merge_base" ]]; then
    echo "Error: Could not find a common ancestor with the \"$main_branch_name\" branch." >&2
    return 1
  fi

  echo "$merge_base"
)

get-new-worktree-directory() (
  set -euo pipefail # Exit on errors and undefined variables.

  assert-in-git-repository

  local repo_root
  repo_root=$(git rev-parse --show-toplevel)

  local repositories_directory
  repositories_directory=$(dirname "$repo_root")

  local repository_name
  repository_name=$(basename "$repo_root")

  # Strip trailing digits so that running from e.g. "foo2" produces "foo3", not "foo23".
  local repository_base_name
  repository_base_name=$(printf '%s' "$repository_name" | sed 's/[0-9]*$//')

  local main_branch_name
  main_branch_name=$(get-main-branch-name)

  local suffix=2
  local new_worktree_directory
  local new_branch_name
  while true; do
    new_worktree_directory="$repositories_directory/$repository_base_name$suffix"
    if is-github-repository; then
      new_branch_name="$suffix"
    else
      local username
      username=$(get-username)
      new_branch_name="feature/$username/$suffix"
    fi

    if [[ ! -e "$new_worktree_directory" ]] \
      && ! git show-ref --verify --quiet "refs/heads/$new_branch_name" \
      && ! git show-ref --verify --quiet "refs/remotes/origin/$new_branch_name"; then
      break
    fi

    ((suffix++))
  done

  # There is no long form for "-b".
  git worktree add -b "$new_branch_name" "$new_worktree_directory" "$main_branch_name" > /dev/null

  echo "$new_worktree_directory"
)

get-num-commits-on-branch() (
  set -euo pipefail # Exit on errors and undefined variables.

  assert-in-git-repository
  assert-feature-branch

  local branch_name
  branch_name=$(git branch --show-current)

  local merge_base
  merge_base=$(get-merge-base)

  git rev-list --count "$merge_base..$branch_name"
)

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

# This will echo back the same input if the input is not a number.
get-worktree-path-from-number() (
  set -euo pipefail # Exit on errors and undefined variables.

  if [[ -z "${1:-}" ]]; then
    echo "Error: The worktree path or number is required. Usage: ${FUNCNAME[0]} <worktree_path_or_number>" >&2
    return 1
  fi
  local worktree_path_or_number="$1"

  local worktree_path
  if [[ "$worktree_path_or_number" =~ ^[0-9]+$ ]]; then
    local worktree_number="$worktree_path_or_number"
    worktree_path=$(git worktree list | sed --quiet "${worktree_number}p" | awk '{print $1}')
    if [[ -z "$worktree_path" ]]; then
      echo "Error: Worktree number $worktree_number does not exist." >&2
      return 1
    fi
  else
    worktree_path="$worktree_path_or_number"
  fi

  echo "$worktree_path"
)

is-git-bash() (
  set -euo pipefail # Exit on errors and undefined variables.

  local kernel_name
  kernel_name=$(uname -s) # The "--kernel-name" flag is not supported on macOS.
  [[ "$kernel_name" =~ ^MINGW || "$kernel_name" =~ ^MSYS_NT ]]
)

is-github-repository() (
  set -euo pipefail # Exit on errors and undefined variables.

  if ! git rev-parse --is-inside-work-tree &> /dev/null; then
    return 1 # False
  fi

  # e.g. "git@github.com:alice/my-repo.git" or "https://github.com/alice/my-repo.git"
  local remote_url
  remote_url=$(git remote get-url origin)

  if echo "$remote_url" | grep --quiet "github.com"; then
    return # True
  fi

  return 1 # False
)

is-mac-os() {
  [[ "$(uname)" == "Darwin" ]]
}

is-ubuntu() {
  [[ "${ID:-}" == "ubuntu" ]]
}

is-wsl() {
  [[ -r "/proc/version" ]] && grep --ignore-case --quiet WSL /proc/version
}

# When we "cd" to a Git repository, we want to show the branches. Otherwise, can we show the list of
# files in the directory.
print-files-and-branches() (
  set -euo pipefail # Exit on errors and undefined variables.

  # We use the same flags as the "ll" alias. (We cannot use the alias directly as the subshell does
  # not have access to it.
  ls -a -h -l -F --color=auto

  # On Git Gash, the "git rev-parse" command will show a directory in the format of:
  # D:/Repositories/configs
  # Thus, we have to made some modifications
  local current_dir="$PWD"
  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2> /dev/null)

  if command -v cygpath &> /dev/null; then
    # "/c/Repositories/foo" --> "C:\Repositories\configs"
    current_dir=$(cygpath --windows "$current_dir")
    current_dir=$(to-lowercase "$current_dir")

    # "C:/Repositories/foo" --> "C:\Repositories\foo"
    repo_root=$(cygpath --windows "$repo_root")
    repo_root=$(to-lowercase "$repo_root")
  fi

  if [[ "$current_dir" == "$repo_root" ]]; then
    echo
    gbl
  fi
)

remove-leading-and-trailing-whitespace() (
  sed --expression '/[^[:space:]]/,$!d' --expression 's/^[[:space:]]*//' --expression 's/[[:space:]]*$//'
)

# We do not use a subshell because the alias would not persist.
set-cd-alias() {
  if [[ -z "${1:-}" ]]; then
    echo "Error: The repository name is required. Usage: ${FUNCNAME[0]} <repository_name>" >&2
    return 1
  fi
  local repository_name="$1"

  if [[ -z "${REPOSITORIES_DIR:-}" ]] || [[ ! -d "$REPOSITORIES_DIR/$repository_name" ]]; then
    return
  fi

  local first_letter
  first_letter=$(to-lowercase "${repository_name:0:1}")

  local alias_name="cd$first_letter"
  if alias "$alias_name" &> /dev/null; then
    echo "Error: The \"$alias_name\" alias already exists, so it cannot be used for the \"$repository_name\" repository." >&2
    return 1
  fi

  # shellcheck disable=SC2139
  alias "$alias_name"="builtin cd $REPOSITORIES_DIR/$repository_name"
  local directory_number
  for directory_number in {2..9}; do
    # shellcheck disable=SC2139
    alias "$alias_name$directory_number"="builtin cd $REPOSITORIES_DIR/$repository_name$directory_number"
  done
}

# - When using "gh pr checkout", the git remote will not be set up properly and "git pull" will have
#   the following error:
#   Your configuration specifies to merge with the ref 'refs/heads/main'
#   from the remote, but no such ref was fetched.
# - This can be seen by typing "git remote", which will only show "origin", even though we are on a
#   branch pointing to a separate repository. Additionally, "git config branch.alice/main.remote"
#   will return "git@github.com:alice/foo.git" instead of "alice".
# - After running this function, "git remote" will return "alice" and "origin", and
#   "git config branch.alice/main.remote" will return "alice".
# - This function will be a no-op if we are not in a GitHub repository or if the remote is already
#   set up properly.
set-gh-remote() (
  set -euo pipefail # Exit on errors and undefined variables.

  local directory_path="${1-}"
  if [[ -z "$directory_path" ]]; then
    directory_path="$PWD"
  fi

  assert-in-git-repository "$directory_path"

  local branch_name
  branch_name=$(git -C "$directory_path" branch --show-current)

  # Check to see if this is a branch freshly created from "gh pr checkout".
  local remote_config
  # This will be "origin" on normal branches and "alice" on branches already touched by this
  # function and e.g. "git@github.com:alice/foo.git" or "https://github.com/alice/foo" on branches
  # freshly created from "gh pr checkout".
  remote_config=$(git -C "$directory_path" config "branch.$branch_name.remote")

  if [[ -z "$remote_config" ]]; then
    echo "Error: Failed to parse the Git branch remote config of: $remote_config" >&2
    return 1
  fi

  if [[ "$remote_config" == "origin" ]]; then
    return
  fi

  local github_username
  if [[ "$remote_config" =~ github\.com[:/]([^/]+)/ ]]; then
    # Add a remote for the forked repository.
    github_username="${BASH_REMATCH[1]}"

    local existing_url
    existing_url=$(git -C "$directory_path" remote get-url "$github_username" 2> /dev/null || true)

    if [[ -n "$existing_url" ]]; then
      # The remote has already been set up on this repository. Verify that it matches.
      if [[ "$existing_url" != "$remote_config" ]]; then
        echo "Error: The remote \"$github_username\" already exists, but it points to \"$existing_url\" instead of \"$remote_config\"." >&2
        return 1
      fi
    else
      # The remote for this username does not already exist.
      git -C "$directory_path" remote add "$github_username" "$remote_config"

      # Now that the repository has more than one remote, the GitHub CLI will become confused and
      # complain that "no default remote repository has been set" when running commands. Manually
      # set the default to the non-forked remote.
      local origin_url
      origin_url=$(git -C "$directory_path" remote get-url origin)
      # The GitHub CLI does not support the "-C" flag, so we use a subshell.
      (builtin cd "$directory_path" && gh repo set-default "$origin_url")
    fi

    git -C "$directory_path" fetch "$github_username"
  else
    # The remote is already set (e.g. "alice").
    github_username="$remote_config"
  fi

  # Set the upstream for the current branch. By default, branches created with "gh pr checkout" will
  # not have an upstream, which can be seen with "git branch -vv". If the upstream is already set,
  # this will be a no-op.
  local merge_ref
  # This will be something like: refs/heads/main
  merge_ref=$(git -C "$directory_path" config branch."$branch_name".merge)

  if [[ -z "$merge_ref" ]]; then
    echo "Error: Failed to parse the Git branch merge config." >&2
    return 1
  fi

  local branch_short_name
  # This will be something like: main
  branch_short_name=${merge_ref#refs/heads/}
  local target_ref
  # This will be something like: refs/remotes/alice/main
  target_ref="refs/remotes/$github_username/$branch_short_name"
  git -C "$directory_path" branch --set-upstream-to="$target_ref"

  # Set "push.default" to "upstream". This ensures that "git push" works even when the local branch
  # name (e.g. "pr-123") differs from the remote branch name.
  git -C "$directory_path" config push.default upstream
)

to-lowercase() (
  set -euo pipefail # Exit on errors and undefined variables.

  if [[ $# -eq 0 ]]; then
    echo "Error: At least one string argument is required. Usage: ${FUNCNAME[0]} <string> ..." >&2
    return 1
  fi

  # https://stackoverflow.com/questions/41166026/what-does-2-commas-after-variable-name-mean-in-bash
  echo "${@,,}"
)
