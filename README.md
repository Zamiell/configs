# configs

These are my personal Bash configs. They contain helper functions like `gp` to git pull and `grbm` to automatically rebase a feature branch on main.

Currently, the configs have [LogixHealth](https://www.logixhealth.com)-specific logic for working with the company's branch naming convention and Azure DevOps.

## Installation

For example, if you want to load the config from your ".bash_profile" file:

```sh
curl --silent --fail --show-error https://raw.githubusercontent.com/Zamiell/configs/refs/heads/main/bash/.bash_profile >> ~/.bash_profile
```
