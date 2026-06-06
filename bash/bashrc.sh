# Compatibility notes:
# - "ls" does not support long flags on macOS.
# - "mkdir" does not support "--parents" on macOS, so we use "-p" instead.
# - "sed" does not support long flags on macOS. We require that macOS users run:
#   brew install gnu-sed

# Get the directory of this script:
# https://stackoverflow.com/questions/59895/getting-the-source-directory-of-a-bash-script-from-within
DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

# shellcheck source=/dev/null
source "$DIR/helpers.sh"

# shellcheck source=/dev/null
source "$DIR/path.sh"

# shellcheck source=/dev/null
source "$DIR/other-environment-variables.sh"

# shellcheck source=/dev/null
source "$DIR/terminal-settings.sh"

# shellcheck source=/dev/null
source "$DIR/other-application-settings.sh"

# shellcheck source=/dev/null
source "$DIR/commands/git.sh"

# shellcheck source=/dev/null
source "$DIR/commands/github.sh"

# shellcheck source=/dev/null
source "$DIR/commands/kubectl.sh"

# shellcheck source=/dev/null
source "$DIR/commands/miscellaneous.sh"

# shellcheck source=/dev/null
source "$DIR/commands/npm.sh"

# shellcheck source=/dev/null
source "$DIR/commands/pulumi.sh"

# shellcheck source=/dev/null
source "$DIR/commands/terraform.sh"
