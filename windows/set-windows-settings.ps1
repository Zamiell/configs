#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$scriptsPath = "C:\Windows\Setup\scripts"
if (-not (Test-Path $scriptsPath)) {
    New-Item -Path $scriptsPath -ItemType Directory -Force | Out-Null
}
Start-Transcript -Path "$scriptsPath\install.log" -Append

# -------------------
# Settings --> System
# -------------------

# Settings --> System --> Multitasking --> Snap windows --> Uncheck "When I snap a window, suggest what I can snap next to it"
# https://www.tenforums.com/tutorials/4343-turn-off-aero-snap-windows-10-a.html
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v SnapAssist /t REG_DWORD /d 0 /f

# Settings --> System --> Multitasking --> Snap windows --> Uncheck "Show snap layouts when I hover over a window's maximize button"
# https://www.elevenforum.com/t/enable-or-disable-snap-layouts-for-maximize-button-in-windows-11.61/
# - This requires a restart of explorer to take effect.
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v EnableSnapAssistFlyout /t REG_DWORD /d 0 /f

# --------------------------------
# Settings --> Bluetooth & devices
# --------------------------------

# Settings --> Bluetooth & devices --> Mouse --> Enhance pointer precision --> Off
# https://www.tenforums.com/tutorials/101691-turn-off-enhance-pointer-precision-windows.html
# - This requires a restart of explorer to take effect.
reg add "HKCU\Control Panel\Mouse" /v MouseSpeed /t REG_SZ /d 0 /f
reg add "HKCU\Control Panel\Mouse" /v MouseThreshold1 /t REG_SZ /d 0 /f
reg add "HKCU\Control Panel\Mouse" /v MouseThreshold2 /t REG_SZ /d 0 /f

# ----------------------------
# Settings --> Personalization
# ----------------------------

# Settings --> Personalization --> Colors --> Choose your mode
# https://answers.microsoft.com/en-us/windows/forum/all/not-able-to-change-default-app-mode-settings/16ea2ab9-5c2c-41d1-8ecc-2e96f82ef62a
# Choose your default Windows mode (1/2)
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v "SystemUsesLightTheme" /t REG_DWORD /d 0 /f
# Choose your default app mode (2/2)
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v "AppsUseLightTheme" /t REG_DWORD /d 0 /f

# Settings --> Personalization --> Themes --> Desktop icon settings --> Uncheck "Recycle Bin"
# https://stackoverflow.com/questions/77420778/remove-recycle-bin-from-desktop-with-powershell
# - This requires elevation because the "Policies" subkey is protected.
# - This requires a restart of explorer to take effect.
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\NonEnum" /v "{645FF040-5081-101B-9F08-00AA002F954E}" /t REG_DWORD /d 1 /f

# Settings --> Personalization --> Taskbar --> Taskbar items --> Search --> Hide
# https://www.tenforums.com/tutorials/2854-hide-show-search-box-cortana-icon-taskbar-windows-10-a.html
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /v SearchboxTaskbarMode /t REG_DWORD /d 0 /f

# Settings --> Personalization --> Taskbar --> Taskbar items --> Task view --> Off
# https://www.askvg.com/how-to-remove-search-and-task-view-icons-from-windows-10-taskbar/
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ShowTaskViewButton /t REG_DWORD /d 0 /f

# Settings --> Personalization --> Taskbar --> Taskbar behaviors --> Taskbar alignment --> Left
# https://github.com/ixi-your-face/Useful-Windows-11-Scripts/blob/main/Scripts/Functions/Set-TaskbarAlignment.ps1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarAl /t REG_DWORD /d 0 /f

# Settings --> Personalization --> Taskbar --> Taskbar behaviors --> Uncheck "Show my taskbar on all displays"
# https://www.tenforums.com/tutorials/104832-enable-disable-show-taskbar-all-displays-windows-10-a.html
# - This requires elevation because the "Policies" subkey is protected.
reg add "HKCU\Software\Policies\Microsoft\Windows\Explorer" /v TaskbarNoMultimon /t REG_DWORD /d 1 /f

# Settings --> Personalization --> Taskbar --> Taskbar behaviors --> Combine taskbar buttons and hide labels --> Never
# https://ss64.com/nt/syntax-reghacks.html
# - This requires a restart of explorer to take effect.
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarGlomLevel /t REG_DWORD /d 2 /f

# --------------------------
# Settings --> Accessibility
# --------------------------

# Settings --> Accessibility --> Visual effects --> Transparency effects --> Off
# https://winaero.com/turn-on-or-off-transparency-effects-in-windows-10/
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v "EnableTransparency" /t REG_DWORD /d 0 /f

# Settings --> Accessibility --> Visual effects --> Animation effects --> Off
# https://www.ninjaone.com/blog/turn-off-animation-effects-in-windows-11/
# - This requires a restart of explorer to take effect.
reg add "HKCU\Control Panel\Desktop\WindowMetrics" /v MinAnimate /t REG_SZ /d 0 /f

# Settings --> Accessibility --> Keyboard --> Sticky keys --> Keyboard shortcut for Sticky keys --> Off
# https://answers.microsoft.com/en-us/windows/forum/windows_vista-desktop/i-cant-turn-off-sticky-keys/a7c9fc02-2d0f-4db6-89fb-e36eca3e2ac7
# - This requires a restart of explorer to take effect.
reg add "HKCU\Control Panel\Accessibility\StickyKeys" /v Flags /t REG_SZ /d 506 /f

# Settings --> Accessibility --> Keyboard --> Filter keys --> Keyboard shortcut for Filter keys --> Off
# https://answers.microsoft.com/en-us/windows/forum/windows_vista-desktop/i-cant-turn-off-sticky-keys/a7c9fc02-2d0f-4db6-89fb-e36eca3e2ac7
# - This requires a restart of explorer to take effect.
reg add "HKCU\Control Panel\Accessibility\Keyboard Response" /v Flags /t REG_SZ /d 122 /f

# ---------------------
# File Explorer Options
# ---------------------

# Start --> Run --> control folders --> General --> Open File Explorer to: --> This PC
# https://www.itechtics.com/configure-windows-10-file-explorer-open-pc-instead-quick-access/
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v LaunchTo /t REG_DWORD /d 1 /f

# Start --> Run --> control folders --> General --> Privacy --> Uncheck "Show files from Office.com"
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" /v ShowCloudFilesInQuickAccess /t REG_DWORD /d 0 /f

# Start --> Run --> control folders --> View --> Check "Always show icons, never thumbnails"
# https://www.tenforums.com/tutorials/18834-enable-disable-thumbnail-previews-file-explorer-windows-10-a.html
# - This requires a restart of explorer to take effect.
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v IconsOnly /t REG_DWORD /d 1 /f

# Start --> Run --> control folders --> View --> Check "Decrease space between items (compact view)"
# https://www.ninjaone.com/blog/toggle-compact-view-in-file-explorer/#:~:text=Click%20on%20the%20three%20dots,Click%20Apply%2C%20then%20OK.
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v UseCompactMode /t REG_DWORD /d 1 /f

# Start --> Run --> control folders --> View --> Hidden files and folders --> Show hidden files, folders, and drives
# https://www.isumsoft.com/windows-10/how-to-show-hidden-files-and-folders-in-windows-10.html
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Hidden /t REG_DWORD /d 1 /f

# Start --> Run --> control folders --> View --> Uncheck "Hide empty drives"
# https://www.sevenforums.com/tutorials/6969-drives-hide-show-empty-drives-computer-folder.html
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v HideDrivesWithNoMedia /t REG_DWORD /d 0 /f

# Start --> Run --> control folders --> View --> Uncheck "Hide extensions for known file types"
# http://www.itprotoday.com/management-mobility/how-can-i-modify-registry-enable-option-show-file-extensions-windows-explorer
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v HideFileExt /t REG_DWORD /d 0 /f

# Start --> Run --> control folders --> View --> Check "Restore previous folder windows at logon"
# https://winaero.com/blog/restore-previous-folder-logon-windows-10/
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v PersistBrowsers /t REG_DWORD /d 1 /f

# Start --> Run --> control folders --> View --> Navigation pane --> Uncheck "Show Network"
# https://www.elevenforum.com/t/add-or-remove-network-in-navigation-pane-of-file-explorer-in-windows-11.7272/
# - Modifying the registry will not actually uncheck the GUI option, but it will nonetheless remove
#   the item from the left pane.
reg add "HKCU\Software\Classes\CLSID\{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}" /v System.IsPinnedToNameSpaceTree /t REG_DWORD /d 0 /f

# Start --> Run --> control folders --> View --> Navigation pane --> Uncheck "Show This PC"
# https://www.elevenforum.com/t/add-or-remove-this-pc-in-navigation-pane-of-file-explorer-in-windows-11.7293/
reg add "HKCU\Software\Classes\CLSID\{20D04FE0-3AEA-1069-A2D8-08002B30309D}" /v System.IsPinnedToNameSpaceTree /t REG_DWORD /d 0 /f

# Pin and unpin some folders. Since there is no programmatic way to reorder pinned items, we first
# unpin everything and then repin items in an exact order.
$shell = New-Object -ComObject Shell.Application
$quickAccess = $shell.Namespace("shell:::{679f85cb-0220-4080-b29b-5540cc05aab6}")
$foldersToUnpin = @("Desktop", "Documents", "Downloads", "Pictures", "Music", "Videos")
foreach ($folderName in $foldersToUnpin) {
    $item = $quickAccess.Items() | Where-Object { $_.Name -eq $folderName }
    if ($item) {
        $item.InvokeVerb("unpinfromhome")
    }
}
$foldersToPin = @(
    "C:\",
    "$HOME",
    "$HOME\Desktop",
    "$HOME\Documents",
    "$HOME\Downloads"
)
foreach ($folderPath in $foldersToPin) {
    $folder = $shell.Namespace($folderPath)
    $item = $folder.Self
    $item.InvokeVerb("pintohome")
}

# Remove "Home" from the bottom of the left pane. (There is no GUI method to do this.)
# https://www.elevenforum.com/t/add-or-remove-home-in-navigation-pane-of-file-explorer-in-windows-11.2449/
reg add "HKCU\Software\Classes\CLSID\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}" /v System.IsPinnedToNameSpaceTree /t REG_DWORD /d 0 /f

# Remove "Gallery" from the bottom of the left pane. (There is no GUI method to do this.)
# https://www.elevenforum.com/t/add-or-remove-gallery-in-file-explorer-navigation-pane-in-windows-11.14178/
reg add "HKCU\Software\Classes\CLSID\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}" /v System.IsPinnedToNameSpaceTree /t REG_DWORD /d 0 /f

# ------------------------------
# Miscellaneous Windows Settings
# ------------------------------

# Right-click desktop --> View --> Check "Auto arrange icons"
# https://winaero.com/blog/enable-auto-arrange-desktop-windows-10/
# - This requires a restart of explorer to take effect.
reg add "HKCU\Software\Microsoft\Windows\Shell\Bags\1\Desktop" /v FFlags /t REG_DWORD /d 1075839525 /f

# Right click "Recycle Bin" --> Properties --> Don't move files to the Recycle Bin. Remove files
# immediately when deleted.
# https://superuser.com/questions/1616394/how-to-use-registry-to-disable-recycle-bin-for-all-users-on-all-drives-and-disp
# - This requires elevation because the "Policies" subkey is protected.
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoRecycleFiles /t REG_DWORD /d 1 /f

# Right click "Recycle Bin" --> Properties --> Display delete confirmation dialog
# https://superuser.com/questions/1616394/how-to-use-registry-to-disable-recycle-bin-for-all-users-on-all-drives-and-disp
# - This requires elevation because the "Policies" subkey is protected.
# - This requires a restart of explorer to take effect.
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v ConfirmFileDelete /t REG_DWORD /d 1 /f

# Start --> Run --> lusrmgr.msc --> Users --> james --> General --> Check "Password never expires"
# https://old.reddit.com/r/sysadmin/comments/1ijux6b/wmic_has_been_deprecated_how_to_set_user_pw/
# shellcheck disable=SC2016
# - This requires elevation because users do not have permission to exempt themselves from system
#   policy.
if ($env:USERNAME -eq "james") {
    # We must use the 64-bit version of PowerShell to invoke the "Set-LocalUser" command.
	C:\Windows\sysnative\WindowsPowerShell\v1.0\powershell.exe -Command 'Set-LocalUser -Name james -PasswordNeverExpires $True'
}

# Restore the old right-click context menu.
# https://superuser.com/questions/1854126/how-can-i-get-back-old-context-menu-for-windows-11-right-click-tried-4-differen
reg add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /ve /f

# Restore Windows Photo Viewer
# - By default, Windows Photo Viewer is disabled in Windows 11 LTSC:
#   https://www.tenforums.com/tutorials/14312-restore-windows-photo-viewer-windows-10-a.html#option2
# - After setting this, the default app for the file type must be manually selected in the "Open
#   with..." menu. Doing this automatically is complicated, so we do not bother:
#   https://superuser.com/questions/1748620/on-windows-10-is-there-a-file-i-can-modify-to-configure-the-default-apps
$scriptName = "enable-windows-photo-viewer.reg"
$scriptPath = "$scriptsPath\$scriptName"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Zamiell/configs/refs/heads/main/windows/registry/$scriptName" -OutFile $scriptPath
regedit /s $scriptPath

# --------------------
# Application Settings
# --------------------

# Notepad++
$notepadAppDataPath = "$env:APPDATA\Notepad++"
New-Item -ItemType Directory -Force -Path $notepadAppDataPath | Out-Null
# The config file is not created until Notepad++ is launched for the first time. If it does not
# exist, we copy over the vanilla config.
$notepadConfigPath = "$notepadAppDataPath\config.xml"
if (-not (Test-Path $notepadConfigPath)) {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Zamiell/configs/refs/heads/main/windows/notepad%2B%2B/config-vanilla.xml" -OutFile $notepadConfigPath
}
# View --> Show Symbol --> Show Space and Tab
(Get-Content $notepadConfigPath) -replace 'whiteSpaceShow="hide"', 'whiteSpaceShow="show"' | Set-Content $notepadConfigPath
# Settings --> Preferences --> Margins/Border/Edge --> Uncheck "Display Change History"
(Get-Content $notepadConfigPath) -replace 'isChangeHistoryEnabled="1"', 'isChangeHistoryEnabled="0"' | Set-Content $notepadConfigPath

# Windows Terminal
$terminalAppDataPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
New-Item -ItemType Directory -Force -Path $terminalAppDataPath | Out-Null
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Zamiell/configs/refs/heads/main/windows/terminal/settings.json" -OutFile "$terminalAppDataPath\settings.json"

# Bash
$bashProfilePath = "$HOME/.bash_profile"
if (-not (Test-Path -Path $bashProfilePath)) {
    New-Item -ItemType File -Path $bashProfilePath -Force | Out-Null
}
$searchString = 'Load the commands from the "configs" GitHub repository.'
$patternExists = Select-String -Path $bashProfilePath -Pattern $searchString -SimpleMatch -Quiet
if (-not $patternExists) {
    $response = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Zamiell/configs/refs/heads/main/bash/.bash_profile" -UseBasicParsing
    Add-Content -Path $bashProfilePath -Value $response.Content
}

# ---
# End
# ---

# We restart the entire system instead of restarting explorer, since doing that results in the start
# menu showing an error about indexing being disabled.
shutdown /r /t 0

# Steps that are not covered in this script:
# - Settings --> Display --> Advanced display settings --> Display 1: VG248 -->
#   Refresh rate: 164.917 Hz (the highest value)
# - Settings --> Display --> Advanced display settings --> Display 2: VG248 -->
#   Refresh rate: 164.917 Hz (the highest value)
# - Settings --> Sounds --> Output --> Speakers (Scarlett Solo USB) --> Device properties -->
#   Rename "Speakers" to "Headphones"
# - Install Windhawk mod "Disable Taskbar Thumbnails": https://windhawk.net/mods/taskbar-thumbnails
#   It is not possible to programmatically install mods for Windhawk:
#   https://github.com/ramensoftware/windhawk/issues/154
