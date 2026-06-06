# --------------------------
# Other Application Settings
# --------------------------

# ssh
mkdir -p "$HOME/.ssh" # The directory has to exist for the "ssh-keygen" command to work.
if ! ssh-keygen -F github.com &> /dev/null; then
  # Install the public key for "github.com".
  ssh-keyscan github.com >> "$HOME/.ssh/known_hosts" 2> /dev/null
fi

# npm
if command -v npm &> /dev/null; then
  NPM_CONFIG_PATH="$HOME/.npmrc"
  if [[ ! -s "$NPM_CONFIG_PATH" ]]; then
    touch "$NPM_CONFIG_PATH"
  fi

  if ! grep --quiet "save-exact=true" "$NPM_CONFIG_PATH"; then
    npm config set save-exact=true
  fi

  if [[ -n "${NPM_TOKEN:-}" ]] && ! grep --quiet "registry.npmjs.org" "$NPM_CONFIG_PATH"; then
    sed --in-place "/registry.npmjs.org/d" "$HOME/.npmrc"
    echo "//registry.npmjs.org/:_authToken=\$NPM_TOKEN" >> "$HOME/.npmrc"
  fi
fi
