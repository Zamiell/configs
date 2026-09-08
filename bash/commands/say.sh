if ! command -v say &> /dev/null; then
  say() (
    set -euo pipefail # Exit on errors and undefined variables.

    if [[ -z "$*" ]]; then
      echo "Error: Text is required. Usage: ${FUNCNAME[0]} <text>" >&2
      return 1
    fi

    # shellcheck disable=SC2016
    printf '%s' "$*" | powershell.exe -NoProfile -Command '
      $ErrorActionPreference = "Stop"
      [Console]::InputEncoding = [System.Text.Encoding]::UTF8
      Add-Type -AssemblyName System.Speech
      $s = New-Object System.Speech.Synthesis.SpeechSynthesizer
      try {
        $s.Speak([Console]::In.ReadToEnd())
      } finally {
        $s.Dispose()
      }
    '
  )
fi
