# configs

These are my personal Bash configs. They contain helper functions like `gp` to git pull and `grbm` to automatically rebase a feature branch on main.

Currently, the configs have [LogixHealth](https://www.logixhealth.com)-specific logic for working with the company's branch naming convention and Azure DevOps.

## Installation

### Windows (Git Bash)

On Windows, ".bash_profile" is automatically loaded, but not ".profile".

```sh
echo >> ~/.bash_profile && curl --silent --fail --show-error https://raw.githubusercontent.com/Zamiell/configs/refs/heads/main/bash/.bash_profile >> ~/.bash_profile
```

### macOS

First, [change the default shell from `zsh` to `bash`](https://stackoverflow.com/questions/77052638/changing-default-shell-from-zsh-to-bash-on-macos-catalina-and-beyond). Then:

```sh
echo >> ~/.zprofile && curl --silent --fail --show-error https://raw.githubusercontent.com/Zamiell/configs/refs/heads/main/bash/.bash_profile >> ~/.zprofile
```

### Linux (Ubuntu)

On Linux, both ".profile" and ".bash_profile" are automatically loaded, but ".profile" is preferred. However, ".profile" is not executed in terminals started by a GUI. Thus, the configs should be loaded from the ".bashrc" file.

```sh
echo >> ~/.bashrc && curl --silent --fail --show-error https://raw.githubusercontent.com/Zamiell/configs/refs/heads/main/bash/.bash_profile >> ~/.bashrc
```
