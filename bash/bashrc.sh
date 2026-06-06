# Compatibility notes:
# - "ls" does not support long flags on macOS.
# - "mkdir" does not support "--parents" on macOS, so we use "-p" instead.
# - "sed" does not support long flags on macOS. We require that macOS users run:
#   brew install gnu-sed

# Get the directory of this script:
# https://stackoverflow.com/questions/59895/getting-the-source-directory-of-a-bash-script-from-within
DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

source "$DIR/helpers.sh"
source "$DIR/path.sh"
source "$DIR/other-environment-variables.sh"
source "$DIR/terminal-settings.sh"
source "$DIR/other-application-settings.sh"
source "$DIR/commands/git.sh"
source "$DIR/commands/github.sh"
source "$DIR/commands/kubectl.sh"
source "$DIR/commands/miscellaneous.sh"
source "$DIR/commands/npm.sh"
source "$DIR/commands/pulumi.sh"
source "$DIR/commands/terraform.sh"
