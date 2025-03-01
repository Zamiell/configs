# configs

These are my personal Bash configs.

## Usage

```sh
mkdir ~/.config --parents
BASH_PROFILE_PATH=~/.config/.bash_profile_remote
rm -f "$BASH_PROFILE_PATH"
curl https://raw.githubusercontent.com/Zamiell/configs/refs/heads/main/bash/.bash_profile --silent --output "$BASH_PROFILE_PATH"
source "$BASH_PROFILE_PATH"

# Needed for the "gcs" command.
export BROWSER="chrome"
```
