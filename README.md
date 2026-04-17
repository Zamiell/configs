# configs

These are my personal Bash configs. They contain helper functions like `gp` to git pull and `grbm` to automatically rebase a feature branch on main.

Currently, the configs have [LogixHealth](https://www.logixhealth.com)-specific logic for working with the company's branch naming convention and Azure DevOps.

## Installation

First, clone this repository. Second, we want to automatically source the Bash config, but the file to edit will depend on your operating system.

### Windows (Git Bash)

On Windows, ".bash_profile" is automatically loaded, but not ".profile". So add the below code snippet to your ".bash_profile".

### macOS

First, [change the default shell from `zsh` to `bash`](https://stackoverflow.com/questions/77052638/changing-default-shell-from-zsh-to-bash-on-macos-catalina-and-beyond) using [Homebrew](https://brew.sh/). The ".bashrc" file is not automatically loaded, so add the below code snippet to your ".profile" file.

### Linux (Ubuntu)

On Linux, both ".profile" and ".bash_profile" are automatically loaded, but ".profile" is preferred. However, ".profile" is not executed in terminals started by a GUI. Thus, add the below code snippet to your ".bashrc" file.

### Code Snippet

```sh
# Load the commands from the "configs" GitHub repository.
CONFIGS_REPO_PATH="/c/Repositories/configs" # Change this to wherever you cloned it.
source "$CONFIGS_REPO_PATH/bash/bashrc.sh"
```
