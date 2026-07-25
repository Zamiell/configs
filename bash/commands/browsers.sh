if ! command -v chrome &> /dev/null && command -v google-chrome &> /dev/null; then
  alias chrome="google-chrome"
fi

if ! command -v msedge &> /dev/null && command -v microsoft-edge &> /dev/null; then
  alias msedge="microsoft-edge"
fi
