# ---------------------------
# Other Environment Variables
# ---------------------------

# Load operating system information.
if [[ -s "/etc/os-release" ]]; then
  source /etc/os-release
fi

# Load secret environment variables that cannot be committed to Git.
if [[ -s "$HOME/.env" ]]; then
  # shellcheck source=/dev/null
  source "$HOME/.env"
fi

# Fix self-signed certs for LogixHealth.
if [[ -s "/usr/local/share/ca-certificates/BEDROOTCA001.crt" ]]; then
  export COMPANY_CERT_PATH="/usr/local/share/ca-certificates/BEDROOTCA001.crt"
elif [[ -s "/c/tls/BEDROOTCA001.crt" ]]; then
  export COMPANY_CERT_PATH="/c/tls/BEDROOTCA001.crt"
elif [[ -s "/c/_IT/tls/BEDROOTCA001.crt" ]]; then
  export COMPANY_CERT_PATH="/c/_IT/tls/BEDROOTCA001.crt"
fi
if [[ -n "${COMPANY_CERT_PATH-}" ]]; then
  export NODE_EXTRA_CA_CERTS="$COMPANY_CERT_PATH"
  export CURL_CA_BUNDLE="$COMPANY_CERT_PATH"
fi
if [[ -s "/c/Program Files/Microsoft SDKs/Azure/CLI2/lib/site-packages/certifi/cacert.pem" ]]; then
  export REQUESTS_CA_BUNDLE="/c/Program Files/Microsoft SDKs/Azure/CLI2/lib/site-packages/certifi/cacert.pem"
elif [[ -s "/c/Program Files (x86)/Microsoft SDKs/Azure/CLI2/lib/site-packages/certifi/cacert.pem" ]]; then
  export REQUESTS_CA_BUNDLE="/c/Program Files (x86)/Microsoft SDKs/Azure/CLI2/lib/site-packages/certifi/cacert.pem"
elif [[ -x "/opt/az/bin/python3" ]]; then
  AZURE_CLI_CA_BUNDLE=$("/opt/az/bin/python3" -c "import certifi; print(certifi.where())")
  if [[ ! -s "$AZURE_CLI_CA_BUNDLE" ]]; then
    echo "Error: Failed to find the Azure CLI CA bundle at: $AZURE_CLI_CA_BUNDLE" >&2
    return 1
  fi
  export REQUESTS_CA_BUNDLE="$AZURE_CLI_CA_BUNDLE"
  unset AZURE_CLI_CA_BUNDLE
fi
add-logix-cert-to-requests-ca-bundle

if is-git-bash; then
  # Change the symbolic link mode from "deepcopy" to "nativestrict" so that symbolic links work
  # properly on Windows.
  # https://www.msys2.org/docs/symlinks/
  export MSYS=winsymlinks:nativestrict
fi

# Attempt to find the user's "repositories" directory.
if [[ -d "$HOME/Repositories" ]]; then # Windows / macOS
  REPOSITORIES_DIR="$HOME/Repositories"
elif [[ -d "$HOME/repositories" ]]; then # Linux
  REPOSITORIES_DIR="$HOME/repositories"
elif [[ -d "/d/Repositories" ]]; then # Windows D drive (should have priority over C drive)
  REPOSITORIES_DIR="/d/Repositories"
elif [[ -d "/c/Repositories" ]]; then # Windows C drive
  REPOSITORIES_DIR="/c/Repositories"
fi
if [[ -n "$REPOSITORIES_DIR" ]]; then
  # Now that it has been located, other commands will attempt to use the global environment
  # variable.
  export REPOSITORIES_DIR

  # By default, it is useful for shells to open in the repositories directory instead of the home
  # directory. (But only do this if the shell is interactive and we are starting in the home
  # directory.)
  if [[ $- == *i* ]] && [[ "$PWD" == "$HOME" ]]; then
    # shellcheck disable=SC2164
    builtin cd "$REPOSITORIES_DIR"
  fi
fi
