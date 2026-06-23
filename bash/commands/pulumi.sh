# ---------------
# Pulumi Commands
# ---------------

# "pc" is short for "pulumi cancel". (This is the analog to "terraform force-unlock".)
alias pc="pulumi cancel"

# "pd" is short for "pulumi destroy".
alias pd="pulumi destroy"

# "pl" is short for "pulumi login".
alias pl="pulumi login azblob://pulumi-state?storage_account=lhdevopstfstate"

# "pp" is short for "pulumi preview".
alias pp="pulumi preview"

# "ppf" is short for "terraform pipeline fix". This is the analog to "tph"; it will put the
# "pulumi-preview-approve-up.yml" file back to normal.
ppf() (
  set -euo pipefail # Exit on errors and undefined variables.

  if [[ -z "${REPOSITORIES_DIR:-}" ]]; then
    echo "Error: You can only use this command if your repositories directory is in one of the standard locations." >&2
    exit 1
  fi

  local infrastructure_path="$REPOSITORIES_DIR/infrastructure"
  if [[ ! -d "$infrastructure_path" ]]; then
    echo "Error: The \"infrastructure\" repository does not exist." >&2
    exit 1
  fi

  builtin cd "$infrastructure_path"

  local yaml_path="0_Global_Library/pipeline-templates/stages/pulumi-preview-approve-up.yml"
  if [[ ! -s "$yaml_path" ]]; then
    echo "Error: The \"$yaml_path\" file was not found." >&2
    exit 1
  fi

  local main_branch_name
  main_branch_name=$(get-main-branch-name)

  git checkout "$main_branch_name" -- "$yaml_path"

  local yaml_file_name
  yaml_file_name=$(basename "$yaml_path")

  gc "chore: revert $yaml_file_name"
  echo "The \"$yaml_file_name\" file was successfully reset back to normal."
)

# "pph" is short for "pulumi pipeline hack". It will edit the "pulumi-preview-approve-up.yml" file
# for the current feature branch.
pph() (
  set -euo pipefail # Exit on errors and undefined variables.

  if [[ -z "${REPOSITORIES_DIR:-}" ]]; then
    echo "Error: You can only use this command if your repositories directory is in one of the standard locations." >&2
    exit 1
  fi

  local infrastructure_path="$REPOSITORIES_DIR/infrastructure"
  if [[ ! -d "$infrastructure_path" ]]; then
    echo "Error: The \"infrastructure\" repository does not exist." >&2
    exit 1
  fi

  builtin cd "$infrastructure_path"

  local yaml_file_path="0_Global_Library/pipeline-templates/stages/pulumi-preview-approve-up.yml"
  if [[ ! -s "$yaml_file_path" ]]; then
    echo "Error: The \"$yaml_file_path\" file was not found." >&2
    exit 1
  fi

  local main_branch_name
  main_branch_name=$(get-main-branch-name)

  local branch_name
  branch_name=$(git branch --show-current)

  sed --in-place "s#refs/heads/$main_branch_name#refs/heads/$branch_name#g" "$yaml_file_path"

  local yaml_file_name
  yaml_file_name=$(basename "$yaml_file_path")

  git add "$yaml_file_path"
  git commit -m "chore: hack $yaml_file_name"
  git push

  echo "The \"$yaml_file_name\" was successfully hacked to use \"$branch_name\" instead of \"$main_branch_name\"."
)

# "pr" is short for "pulumi refresh". Note that this will overwrite the existing "pr" command:
# https://man7.org/linux/man-pages/man1/pr.1.html
alias pr="pulumi refresh"

# "pu" is short for "pulumi up --suppress-outputs".
alias pu="pulumi up --suppress-outputs"

# "puy" is short for "pulumi up --yes".
alias puy="pulumi up --yes"
