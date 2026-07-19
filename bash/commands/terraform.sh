# ------------------
# Terraform Commands
# ------------------

# "ta" is short for "terraform apply".
alias ta="terraform apply"

# "taa" is short for "terraform apply -auto-approve".
alias taa="terraform apply -auto-approve"

# "tc" is short for "terraform clean".
alias tc="rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.backup"

# "td" is short for "terraform destroy".
alias td="terraform destroy"

# "tdf" is short for "terraform docs fix". It will infer all of the Terraform modules modified in
# the current feature branch.
tdf() (
  set -euo pipefail # Exit on errors and undefined variables.

  if [[ -z "${REPOSITORIES_DIR:-}" ]]; then
    echo "Error: You can only use this command if your repositories directory is in one of the standard locations." >&2
    exit 1
  fi

  local infrastructure_path="$REPOSITORIES_DIR/infrastructure"

  if [[ ! -d "$infrastructure_path" ]]; then
    echo "Error: The \"$infrastructure\" repository does not exist." >&2
    exit 1
  fi

  builtin cd "$infrastructure_path"

  assert-feature-branch

  local main_branch_name
  main_branch_name=$(get-main-branch-name)

  # Three dots compares to the merge base (instead of the current HEAD).
  local changed_files
  changed_files=$(git diff --name-only "$main_branch_name"...HEAD)

  if [[ -z "$changed_files" ]]; then
    echo "Error: There are no changed files in this branch when compared to the \"$main_branch_name\" branch." >&2
    return 1
  fi

  # Extract unique Terraform module names from changed files.
  local module_names
  module_names=$(echo "$changed_files" | grep '^0-global-library/terraform-modules/' | sed 's|^0-global-library/terraform-modules/\([^/]*\)/.*|\1|' | sort -u)

  if [[ -z "$module_names" ]]; then
    echo "Error: No Terraform module files were changed in this feature branch." >&2
    return 1
  fi

  # Run docs generation for each module.
  while IFS= read -r module_name; do
    bun run generate-terraform-module-docs "$module_name"
  done <<< "$module_names"

  # Make a single commit for all modules.
  local modules_list
  modules_list=$(echo "$module_names" | paste -sd ', ')
  gc "docs: update docs for $modules_list"

  echo "Terraform docs fixed: $modules_list"
)

# "tpf" is short for "terraform pipeline fix". This is the analog to "tph"; it will put the
# "terraform-plan-approve-apply.yml" file back to normal.
tpf() (
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

  local yaml_file_path="0-global-library/pipeline-templates/stages/terraform-plan-approve-apply.yml"
  if [[ ! -s "$yaml_file_path" ]]; then
    echo "Error: The \"$yaml_file_path\" file was not found." >&2
    exit 1
  fi

  local main_branch_name
  main_branch_name=$(get-main-branch-name)

  local branch_name
  branch_name=$(git branch --show-current)

  sed --in-place "s#refs/heads/$branch_name#refs/heads/$main_branch_name#g" "$yaml_file_path"

  local yaml_file_name
  yaml_file_name=$(basename "$yaml_file_path")

  git add "$yaml_file_path"
  git commit -m "chore: reset $yaml_file_name"
  git push

  echo "The \"$yaml_file_name\" file was successfully reset back to normal."
)

# "tph" is short for "terraform pipeline hack". It will edit the "terraform-plan-approve-apply.yml"
# file for the current feature branch.
tph() (
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

  local yaml_file_path="0-global-library/pipeline-templates/stages/terraform-plan-approve-apply.yml"
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

# "tda" is short for "terraform destroy -auto-approve".
alias tda="terraform destroy -auto-approve"

# "tf" is short for "terraform fmt".
alias tf="terraform fmt"

# "ti" is short for "terraform init".
alias ti="terraform init"

# "tie" is short for "terraform init empty", which is useful for running "terraform validate"
# without intending to deploy anything.
alias tie="terraform init -backend=false"

# "tiv" is short for "terraform init && terraform validate".
alias tiv="terraform init && terraform validate"

# "tl" is short for "tflint".
alias tl="tflint"

# "tp" is short for "terraform plan".
alias tp="terraform plan"

# "tt" is short for "terraform test".
alias tt="terraform test"

# "tu" is short for "terraform force-unlock -force".
alias tu="terraform force-unlock -force"

# "tv" is short for "terraform validate".
alias tv="terraform validate"
