#!/bin/bash

set -euo pipefail # Exit on errors and undefined variables.

# Try to find and focus an existing terminal window
if wmctrl -x -a "gnome-terminal.Gnome-terminal" 2> /dev/null \
  || wmctrl -x -a "xfce4-terminal.Xfce4-terminal" 2> /dev/null \
  || wmctrl -x -a "mate-terminal.Mate-terminal" 2> /dev/null; then
  exit 0
else
  # No terminal found, launch a new one
  gnome-terminal || xfce4-terminal || mate-terminal || x-terminal-emulator
fi
