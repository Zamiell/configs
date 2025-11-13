# Load the commands from the "configs" GitHub repository.
mkdir -p ~/.config
BASH_PROFILE_REMOTE_PATH=~/.config/.bash_profile_remote
rm -f "$BASH_PROFILE_REMOTE_PATH"
curl --silent --fail --show-error --output "$BASH_PROFILE_REMOTE_PATH" https://raw.githubusercontent.com/Zamiell/configs/refs/heads/main/bash/.bash_profile_remote
# shellcheck source=/dev/null
source "$BASH_PROFILE_REMOTE_PATH"
