#!/bin/bash

# This script sets up a new Windows system with my personal settings.

set -euo pipefail # Exit on errors and undefined variables.
set -x            # Echo commands for easier troubleshooting.

# This is necessary in order to use Windows-style flags with forward slashes.
export MSYS_NO_PATHCONV=1

# ----------
# Validation
# ----------

if ! net session &> /dev/null; then
  echo "Error: You must run this script with administrative privileges." >&2
  exit 1
fi

# ----------------------------
# Settings --> Personalization
# ----------------------------

# Settings --> Personalization --> Colors --> Choose your mode
# https://answers.microsoft.com/en-us/windows/forum/all/not-able-to-change-default-app-mode-settings/16ea2ab9-5c2c-41d1-8ecc-2e96f82ef62a
# Choose your default Windows mode (1/2)
cmd /c reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v "SystemUsesLightTheme" /t REG_DWORD /d 0 /f
# Choose your default app mode (2/2)
cmd /c reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v "AppsUseLightTheme" /t REG_DWORD /d 0 /f

# Settings --> Personalization --> Themes --> Desktop icon settings --> Uncheck "Recycle Bin"
# https://stackoverflow.com/questions/77420778/remove-recycle-bin-from-desktop-with-powershell
# - This requires elevation because the "Policies" subkey is protected.
# - This requires a restart of explorer to take effect.
cmd /c reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\NonEnum" /v "{645FF040-5081-101B-9F08-00AA002F954E}" /t REG_DWORD /d 1 /f

# --------------------------
# Settings --> Accessibility
# --------------------------

# Settings --> Accessibility --> Visual effects --> Transparency effects --> Off
# https://winaero.com/turn-on-or-off-transparency-effects-in-windows-10/
cmd /c reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v "EnableTransparency" /t REG_DWORD /d 0 /f

# ------------------------------
# Miscellaneous Windows Settings
# ------------------------------

# Right click "Recycle Bin" --> Properties --> Don't move files to the Recycle Bin. Remove files
# immediately when deleted.
# https://superuser.com/questions/1616394/how-to-use-registry-to-disable-recycle-bin-for-all-users-on-all-drives-and-disp
# - This requires elevation because the "Policies" subkey is protected.
cmd /c reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoRecycleFiles /t REG_DWORD /d 1 /f

# Right click "Recycle Bin" --> Properties --> Display delete confirmation dialog
# https://superuser.com/questions/1616394/how-to-use-registry-to-disable-recycle-bin-for-all-users-on-all-drives-and-disp
# - This requires elevation because the "Policies" subkey is protected.
# - This requires a restart of explorer to take effect.
cmd /c reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v ConfirmFileDelete /t REG_DWORD /d 1 /f

# --------------------
# Application Settings
# --------------------

# Notepad++
# whiteSpaceShow="hide" --> show
# TODO: test to see if "C:\Users\james\AppData\Roaming\Notepad++\config.xml" is created before Notepad++ is run for the first time

# --------
# Unsorted
# --------

# Disable Bing Search in the Start Menu
# https://github.com/chocolatey/boxstarter/blob/master/Boxstarter.WinConfig/Disable-BingSearch.ps1
# cmd /c reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /v BingSearchEnabled /t REG_DWORD /d 0 /f

# Use small taskbar buttons
# Right-click taskbar - Taskbar settings
# https://www.tenforums.com/tutorials/25233-use-large-small-taskbar-buttons-windows-10-a.html
# cmd /c reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarSmallIcons /t REG_DWORD /d 1 /f

# Combine taskbar buttons - Never
# Right-click taskbar - Taskbar settings
# https://ss64.com/nt/syntax-reghacks.html
# cmd /c reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarGlomLevel /t REG_DWORD /d 2 /f

# Remove Search from the Taskbar
# Right-click taskbar - Cortana/Search - Hidden
# (depending on whether Cortana is enabled or not)
# https://www.tenforums.com/tutorials/2854-hide-show-search-box-cortana-icon-taskbar-windows-10-a.html
# cmd /c reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /v SearchboxTaskbarMode /t REG_DWORD /d 0 /f

# Remove Task View from the Taskbar
# Right-click taskbar - Show Task View button
# https://www.askvg.com/how-to-remove-search-and-task-view-icons-from-windows-10-taskbar/
# cmd /c reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ShowTaskViewButton /t REG_DWORD /d 0 /f

# Disable Aero Peek
# We can't actually disable it, but we can set the timeout to be 1 hour.
# https://www.howtogeek.com/howto/20052/increase-the-speed-of-the-aero-taskbar-thumbnails-in-windows-7/
# cmd /c reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ExtendedUIHoverTime /t REG_DWORD /d 3600000 /f

# Disable "Show taskbar on all displays"
# Right-click taskbar - Taskbar settings
# https://www.tenforums.com/tutorials/104832-enable-disable-show-taskbar-all-displays-windows-10-a.html
# cmd /c reg add "HKCU\Software\Policies\Microsoft\Windows\Explorer" /v TaskbarNoMultimon /t REG_DWORD /d 1 /f
# cmd /c reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v TaskbarNoMultimon /t REG_DWORD /d 1 /f

# Remove the "People" icon from the System tray
# Right-click taskbar - Show People on the taskbar
# https://winaero.com/blog/remove-people-icon-windows-10/
# cmd /c reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People" /v PeopleBand /t REG_DWORD /d 0 /f

# Always show all icons in the notification area (system tray)
# Right-click taskbar - Taskbar settings - Select which icons appear on the taskbar
# https://winaero.com/blog/always-show-tray-icons-windows-10/
# cmd /c reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" /v EnableAutoTray /t REG_DWORD /d 0 /f

# Disable Action Center
# Via registry change only (since we always show all icons in the system tray)
# http://www.thewindowsclub.com/how-to-disable-notification-and-action-center-in-windows-10
# cmd /c reg add "HKCU\Software\Policies\Microsoft\Windows\Explorer" /v DisableNotificationCenter /t REG_DWORD /d 1 /f

# Disable Windows Security system tray icon
# https://www.tenforums.com/tutorials/11974-hide-show-windows-defender-notification-area-icon-windows-10-a.html
# cmd /c reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Systray" /v HideSystray /t REG_DWORD /d 1 /f

# Remove Bluetooth icon from System Tray
# https://winaero.com/bluetooth-taskbar-icon-windows-10/
# cmd /c reg add "HKCU\Control Panel\Bluetooth" /v "Notification Area Icon" /t REG_DWORD /d 0 /f

# Always show icons, never thumbnails (enable)
# https://www.tenforums.com/tutorials/18834-enable-disable-thumbnail-previews-file-explorer-windows-10-a.html
# cmd /c reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v IconsOnly /t REG_DWORD /d 1 /f

# Always show menus (enable)
# http://unlockforus.blogspot.com/2012/07/display-and-always-show-menus-like-file.html
# cmd /c reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v AlwaysShowMenus /t REG_DWORD /d 1 /f

# Display the full path in the title bar (enable)
# https://www.top-password.com/blog/display-full-path-in-title-bar-of-windows-10-file-explorer/
# cmd /c reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState" /v FullPath /t REG_DWORD /d 1 /f

# Show hidden files, folders, and drives (enable)
# https://www.isumsoft.com/windows-10/how-to-show-hidden-files-and-folders-in-windows-10.html
# cmd /c reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Hidden /t REG_DWORD /d 1 /f

# Hide empty drives (disable)
# https://www.sevenforums.com/tutorials/6969-drives-hide-show-empty-drives-computer-folder.html
# cmd /c reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v HideDrivesWithNoMedia /t REG_DWORD /d 0 /f

# Hide extensions for known file types (disable)
# http://www.itprotoday.com/management-mobility/how-can-i-modify-registry-enable-option-show-file-extensions-windows-explorer
# cmd /c reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v HideFileExt /t REG_DWORD /d 0 /f

# Restore previous folder windows at logon (enable)
# https://winaero.com/blog/restore-previous-folder-logon-windows-10/
# cmd /c reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v PersistBrowsers /t REG_DWORD /d 1 /f

# Remove "Documents" in This PC
# http://www.thewindowsclub.com/remove-the-folders-from-this-pc-windows-10
# cmd /c reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{f42ee2d3-909f-4907-8871-4c22fc0bf756}\PropertyBag" /v ThisPCPolicy /t REG_SZ /d Hide /f

# Remove "Pictures" in This PC
# http://www.thewindowsclub.com/remove-the-folders-from-this-pc-windows-10
# cmd /c reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{0ddd015d-b06c-45d5-8c4c-f59713854639}\PropertyBag" /v ThisPCPolicy /t REG_SZ /d Hide /f

# Remove "Videos" in This PC
# http://www.thewindowsclub.com/remove-the-folders-from-this-pc-windows-10
# cmd /c reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{35286a68-3c57-41a1-bbb1-0eae73d76c95}\PropertyBag" /v ThisPCPolicy /t REG_SZ /d Hide /f

# Remove "Downloads" in This PC
# http://www.thewindowsclub.com/remove-the-folders-from-this-pc-windows-10
# cmd /c reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{7d83ee9b-2244-4e70-b1f5-5393042af1e4}\PropertyBag" /v ThisPCPolicy /t REG_SZ /d Hide /f

# Remove "Music" in This PC
# http://www.thewindowsclub.com/remove-the-folders-from-this-pc-windows-10
# cmd /c reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{a0c69a99-21c8-4671-8703-7934162fcf1d}\PropertyBag" /v ThisPCPolicy /t REG_SZ /d Hide /f

# Remove "Desktop" in This PC
# http://www.thewindowsclub.com/remove-the-folders-from-this-pc-windows-10
# cmd /c reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}\PropertyBag" /v ThisPCPolicy /t REG_SZ /d Hide /f

# Remove "3D Objects" in This PC
# http://www.thewindowsclub.com/remove-3d-objects-folder-winows-10
# cmd /c reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}" /f

# Launch "This PC" instead of "Quick Access"
# https://www.itechtics.com/configure-windows-10-file-explorer-open-pc-instead-quick-access/
# cmd /c reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v LaunchTo /t REG_DWORD /d 1 /f

# Uncheck "Turn on Sticky Keys"
# https://answers.microsoft.com/en-us/windows/forum/windows_vista-desktop/i-cant-turn-off-sticky-keys/a7c9fc02-2d0f-4db6-89fb-e36eca3e2ac7
# cmd /c reg add "HKCU\Control Panel\Accessibility\StickyKeys" /v Flags /t REG_SZ /d 506 /f

# Uncheck "Turn on Toggle Keys"
# https://answers.microsoft.com/en-us/windows/forum/windows_vista-desktop/i-cant-turn-off-sticky-keys/a7c9fc02-2d0f-4db6-89fb-e36eca3e2ac7
# cmd /c reg add "HKCU\Control Panel\Accessibility\Keyboard Response" /v Flags /t REG_SZ /d 122 /f

# Uncheck "Turn on Filter Keys"
# https://answers.microsoft.com/en-us/windows/forum/windows_vista-desktop/i-cant-turn-off-sticky-keys/a7c9fc02-2d0f-4db6-89fb-e36eca3e2ac7
# cmd /c reg add "HKCU\Control Panel\Accessibility\ToggleKeys" /v Flags /t REG_SZ /d 58 /f

# Start - Change mouse settings - Pointer Options - Enhance pointer precision
# https://www.tenforums.com/tutorials/101691-turn-off-enhance-pointer-precision-windows.html
# Uncheck "Enhance pointer precision"
# cmd /c reg add "HKCU\Control Panel\Mouse" /v MouseSpeed /t REG_SZ /d 0 /f
# cmd /c reg add "HKCU\Control Panel\Mouse" /v MouseThreshold1 /t REG_SZ /d 0 /f
# cmd /c reg add "HKCU\Control Panel\Mouse" /v MouseThreshold2 /t REG_SZ /d 0 /f

# Disable AutoPlay
# TODO: BLOG
# cmd /c reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers" /v DisableAutoplay /t REG_DWORD /d 1 /f

# Password never expires
# TODO: BLOG
# cmd /c wmic useraccount where "name='james'" set PasswordExpires=FALSE

# When Windows detects communications activity: Do nothing
# Start - Sound - Communications
# https://community.spiceworks.com/topic/479903-set-the-option-sound-communications-do-nothing-via-group-policy
# cmd /c reg add "HKCU\Software\Microsoft\Multimedia\Audio" /v UserDuckingPreference /t REG_DWORD /d 3 /f

# Disable Snap-assist
# https://www.tenforums.com/tutorials/4343-turn-off-aero-snap-windows-10-a.html
# cmd /c reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v SnapAssist /t REG_DWORD /d 0 /f

# Restore Windows Photo Viewer
# By default, Windows Photo Viewer is disabled in Windows 10 LTSC.
# Since it is more complicated than adding a single registry change, we execute a reg file.
# The /s flag is to make it silent.
# https://www.tenforums.com/tutorials/14312-restore-windows-photo-viewer-windows-10-a.html#option2
# Additionally, setting Windows Photo Viewer as the default app is complicated, so we do not bother:
# https://superuser.com/questions/1748620/on-windows-10-is-there-a-file-i-can-modify-to-configure-the-default-apps
# cmd /c regedit /s "C:\Windows\Setup\Scripts\Restore_Windows_Photo_Viewer_ALL_USERS.reg"

# VSCode - Add to right-click context menu
# https://thisdavej.com/right-click-on-windows-folder-and-open-with-visual-studio-code/
# cmd /c regedit /S "C:\Windows\Setup\Scripts\vscode-context-menu.reg"

# Auto arrange icons (on the desktop)
# Right-click desktop - View - Auto arrange icons
# From: https://winaero.com/blog/enable-auto-arrange-desktop-windows-10/
# Note that this requires a restart of explorer in order to take effect, which we do at the end.
# reg add "HKCU\Software\Microsoft\Windows\Shell\Bags\1\Desktop" /v FFlags /t REG_DWORD /d 1075839525 /f

# Un-pin all items on the taskbar.
# This just nukes the associated registry folder, forcing Windows to recreate it.
# From: https://www.tenforums.com/tutorials/3151-reset-clear-taskbar-pinned-apps-windows-10-a.html
# Note that this requires a restart of explorer in order to take effect, which we do at the end.
# reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband" /f

# -----
# Other
# -----

# Set up the Bash configs.
# TODO: idempotent
# curl --silent --fail --show-error https://raw.githubusercontent.com/Zamiell/configs/refs/heads/main/bash/.bash_profile >> "C:\Users\james\.bash_profile"

# ---
# End
# ---

# We restart the entire system instead of killing explorer and restarting it, since doing that
# results in the start menu showing an error about indexing being disabled.
shutdown /r /t 0

# Steps that are not covered in this script:
# - Settings --> Display --> Advanced display settings --> Display 1: VG248 -->
#   Refresh rate: 164.917 Hz (the highest value)
# - Settings --> Display --> Advanced display settings --> Display 2: VG248 -->
#   Refresh rate: 164.917 Hz (the highest value)
# - Settings --> Sounds --> Output --> Speakers (Scarlett Solo USB) --> Device properties -->
#   Rename "Speakers" to "Headphones"
