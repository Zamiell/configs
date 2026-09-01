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
    # Silence the warning that says:
    # npm warn Unknown env config "token". This will error in a future major version of npm. See
    # `npm help npmrc` for supported config options.
    npm config set save-exact=true 2> /dev/null
  fi

  if [[ -n "${NPM_CONFIG_TOKEN:-}" ]]; then
    sed --in-place "/registry.npmjs.org/d" "$NPM_CONFIG_PATH"
    echo "//registry.npmjs.org/:_authToken=$NPM_CONFIG_TOKEN" >> "$NPM_CONFIG_PATH"
  fi
fi
