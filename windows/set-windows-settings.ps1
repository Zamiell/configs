$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$scriptsPath = Join-Path -Path $env:TEMP -ChildPath "scripts"
if (-not (Test-Path $scriptsPath)) {
    New-Item -Path $scriptsPath -ItemType Directory -Force | Out-Null
}
Start-Transcript -Path "$scriptsPath\install.log" -Append

$restartRequired = $false

function Assert-LastExitCode {
    param([string]$Description)
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to $Description. (Exit code: $LASTEXITCODE)"
    }
}

function Get-RegistryValue {
    param([string]$Path, [string]$Name)
    try {
        return Get-ItemPropertyValue -Path $Path -Name $Name -ErrorAction Stop
    } catch {
        return $null
    }
}

function Set-RegistryValue {
    param(
        [string]$Path,
        [string]$Name,
        [ValidateSet("DWord", "String")][string]$Type,
        $Value
    )
    $currentValue = Get-RegistryValue -Path $Path -Name $Name
    if ($null -ne $currentValue -and "$currentValue" -eq "$Value") {
        return
    }
    Write-Host "Setting registry value: $Path\$Name = $Value"
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
    New-ItemProperty -Path $Path -Name $Name -PropertyType $Type -Value $Value -Force | Out-Null
    $script:restartRequired = $true
}

# -------------------
# Settings --> System
# -------------------

# Settings --> System --> Notifications --> Notifications --> Off
# https://www.tenforums.com/tutorials/4111-turn-off-notifications-apps-senders-windows-10-a-4.html
# - This prevents the popup from Nvidia when using a KVM, but notifications are unwanted more
#   generally.
# - This requires a restart of explorer to take effect.
Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications" -Name "ToastEnabled" -Type DWord -Value 0

# Settings --> System --> Power --> Power Mode --> Best Performance
# https://www.tenforums.com/performance-maintenance/186847-how-do-i-set-high-performance-power-options-default.html
# - This grays out the setting in the normal GUI, but it can be seen with:
#   Start --> Run --> control powercfg.cpl
$bestPerformancePowerSchemeGuid = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
$activePowerScheme = powercfg /getactivescheme | Out-String
Assert-LastExitCode "get the active power scheme"
if ($activePowerScheme -notmatch $bestPerformancePowerSchemeGuid) {
    Write-Host "Setting the power scheme to: $bestPerformancePowerSchemeGuid"
    powercfg /setactive $bestPerformancePowerSchemeGuid
    Assert-LastExitCode "set the power scheme to: $bestPerformancePowerSchemeGuid"
}
$displayPowerSettings = powercfg /query SCHEME_CURRENT SUB_VIDEO VIDEOIDLE | Out-String
Assert-LastExitCode "get the display power settings"
# Set "Turn off display" to Never when Plugged In
if ($displayPowerSettings -notmatch "Current AC Power Setting Index: 0x00000000") {
    Write-Host "Setting the plugged in display timeout to: Never"
    powercfg /change monitor-timeout-ac 0
    Assert-LastExitCode "set the plugged in display timeout"
}
# Set "Turn off display" to Never when on Battery
if ($displayPowerSettings -notmatch "Current DC Power Setting Index: 0x00000000") {
    Write-Host "Setting the battery display timeout to: Never"
    powercfg /change monitor-timeout-dc 0
    Assert-LastExitCode "set the battery display timeout"
}

# Settings --> System --> Multitasking --> Snap windows -->
# Uncheck "When I snap a window, suggest what I can snap next to it"
# https://www.tenforums.com/tutorials/4343-turn-off-aero-snap-windows-10-a.html
Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "SnapAssist" -Type DWord -Value 0

# Settings --> System --> Multitasking --> Snap windows -->
# Uncheck "Show snap layouts when I hover over a window's maximize button"
# https://www.elevenforum.com/t/enable-or-disable-snap-layouts-for-maximize-button-in-windows-11.61/
# - This requires a restart of explorer to take effect.
Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "EnableSnapAssistFlyout" -Type DWord -Value 0

# Settings --> System --> Multitasking --> Snap windows -->
# Uncheck "Show snap layouts when I drag a window to the top of the screen"
# https://www.elevenforum.com/t/enable-or-disable-snap-layouts-on-top-of-screen-in-windows-11.6142/
# - This requires a restart of explorer to take effect.
Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "EnableSnapBar" -Type DWord -Value 0

# Settings --> System --> Multitasking --> Show tabs from apps when snapping or pressing Alt-Tab -->
# Don't show tabs
Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "MultiTaskingAltTabFilter" -Type DWord -Value 3

# --------------------------------
# Settings --> Bluetooth & devices
# --------------------------------

# Settings --> Bluetooth & devices --> Mouse --> Enhance pointer precision --> Off
# https://www.tenforums.com/tutorials/101691-turn-off-enhance-pointer-precision-windows.html
# - This requires a restart of explorer to take effect.
Set-RegistryValue -Path "HKCU:\Control Panel\Mouse" -Name "MouseSpeed" -Type String -Value "0"
Set-RegistryValue -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold1" -Type String -Value "0"
Set-RegistryValue -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold2" -Type String -Value "0"

# Settings --> Bluetooth & devices --> Touchpad --> Gestures & interaction --> Scroll & zoom -->
# Scrolling direction --> Down motion scrolls down
# https://www.elevenforum.com/t/change-touchpad-scrolling-direction-in-windows-11.7513/
Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\PrecisionTouchPad" -Name "ScrollDirection" -Type DWord -Value 1

# ----------------------------
# Settings --> Personalization
# ----------------------------

# Settings --> Personalization --> Colors --> Choose your mode --> Dark
# https://answers.microsoft.com/en-us/windows/forum/all/not-able-to-change-default-app-mode-settings/16ea2ab9-5c2c-41d1-8ecc-2e96f82ef62a
# Choose your default Windows mode (1/2)
Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "SystemUsesLightTheme" -Type DWord -Value 0
# Choose your default app mode (2/2)
Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme" -Type DWord -Value 0

# Settings --> Personalization --> Taskbar --> Taskbar items --> Search --> Hide
# https://www.tenforums.com/tutorials/2854-hide-show-search-box-cortana-icon-taskbar-windows-10-a.html
Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Type DWord -Value 0

# Settings --> Personalization --> Taskbar --> Taskbar items --> Task view --> Off
# https://www.askvg.com/how-to-remove-search-and-task-view-icons-from-windows-10-taskbar/
Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Type DWord -Value 0

# Settings --> Personalization --> Taskbar --> Taskbar items --> Widgets --> Off
# - This requires using a temporary registry binary to bypass the UserChoice Protection Driver
#   (UCPD).
if ((Get-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa") -ne 0) {
    Write-Host "Setting registry value: HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDa = 0"
    $regTempPath = "$env:TEMP\reg_temp.exe"
    Copy-Item "C:\Windows\System32\reg.exe" $regTempPath
    & $regTempPath add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarDa /t REG_DWORD /d 0 /f
    $regTempExitCode = $LASTEXITCODE
    Remove-Item $regTempPath
    if ($regTempExitCode -ne 0) {
        throw "Failed to set the TaskbarDa registry value. (Exit code: $regTempExitCode)"
    }
    $restartRequired = $true
}

# Settings --> Personalization --> Taskbar --> Taskbar behaviors --> Taskbar alignment --> Left
# https://github.com/ixi-your-face/Useful-Windows-11-Scripts/blob/main/Scripts/Functions/Set-TaskbarAlignment.ps1
Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAl" -Type DWord -Value 0

# Settings --> Personalization --> Taskbar --> Taskbar behaviors -->
# Combine taskbar buttons and hide labels --> Never
# https://ss64.com/nt/syntax-reghacks.html
# - This requires a restart of explorer to take effect.
Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarGlomLevel" -Type DWord -Value 2

# --------------------------
# Settings --> Accessibility
# --------------------------

# Settings --> Accessibility --> Visual effects --> Transparency effects --> Off
# https://winaero.com/turn-on-or-off-transparency-effects-in-windows-10/
Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Type DWord -Value 0

# Settings --> Accessibility --> Visual effects --> Animation effects --> Off
# https://www.ninjaone.com/blog/turn-off-animation-effects-in-windows-11/
# - This requires a restart of explorer to take effect.
# - The GUI will still show as this setting as being "On", but the animations when pressing e.g.
#   "Flag + Left" will still be removed.
Set-RegistryValue -Path "HKCU:\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Type String -Value "0"

# Settings --> Accessibility --> Keyboard --> Sticky keys --> Keyboard shortcut for Sticky keys -->
# Off
# https://answers.microsoft.com/en-us/windows/forum/windows_vista-desktop/i-cant-turn-off-sticky-keys/a7c9fc02-2d0f-4db6-89fb-e36eca3e2ac7
# - This requires a restart of explorer to take effect.
Set-RegistryValue -Path "HKCU:\Control Panel\Accessibility\StickyKeys" -Name "Flags" -Type String -Value "506"

# Settings --> Accessibility --> Keyboard --> Filter keys --> Keyboard shortcut for Filter keys -->
# Off
# https://answers.microsoft.com/en-us/windows/forum/windows_vista-desktop/i-cant-turn-off-sticky-keys/a7c9fc02-2d0f-4db6-89fb-e36eca3e2ac7
# - This requires a restart of explorer to take effect.
Set-RegistryValue -Path "HKCU:\Control Panel\Accessibility\Keyboard Response" -Name "Flags" -Type String -Value "122"

# ---------------------
# File Explorer Options
# ---------------------

# Start --> Run --> control folders --> General --> Open File Explorer to: --> This PC
# https://www.itechtics.com/configure-windows-10-file-explorer-open-pc-instead-quick-access/
Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "LaunchTo" -Type DWord -Value 1

# Start --> Run --> control folders --> General --> Privacy --> Uncheck "Show files from Office.com"
Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "ShowCloudFilesInQuickAccess" -Type DWord -Value 0

# Start --> Run --> control folders --> View --> Check "Always show icons, never thumbnails"
# https://www.tenforums.com/tutorials/18834-enable-disable-thumbnail-previews-file-explorer-windows-10-a.html
# - This requires a restart of explorer to take effect.
Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "IconsOnly" -Type DWord -Value 1

# Start --> Run --> control folders --> View --> Check "Decrease space between items (compact view)"
# https://www.ninjaone.com/blog/toggle-compact-view-in-file-explorer/#:~:text=Click%20on%20the%20three%20dots,Click%20Apply%2C%20then%20OK.
Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "UseCompactMode" -Type DWord -Value 1

# Start --> Run --> control folders --> View --> Hidden files and folders -->
# Show hidden files, folders, and drives
# https://www.isumsoft.com/windows-10/how-to-show-hidden-files-and-folders-in-windows-10.html
Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Type DWord -Value 1

# Start --> Run --> control folders --> View --> Uncheck "Hide empty drives"
# https://www.sevenforums.com/tutorials/6969-drives-hide-show-empty-drives-computer-folder.html
Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideDrivesWithNoMedia" -Type DWord -Value 0

# Start --> Run --> control folders --> View --> Uncheck "Hide extensions for known file types"
# http://www.itprotoday.com/management-mobility/how-can-i-modify-registry-enable-option-show-file-extensions-windows-explorer
Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Type DWord -Value 0

# Start --> Run --> control folders --> View --> Check "Restore previous folder windows at logon"
# https://winaero.com/blog/restore-previous-folder-logon-windows-10/
Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "PersistBrowsers" -Type DWord -Value 1

# Start --> Run --> control folders --> View --> Navigation pane --> Uncheck "Show Network"
# https://www.elevenforum.com/t/add-or-remove-network-in-navigation-pane-of-file-explorer-in-windows-11.7272/
# - Modifying the registry will not actually uncheck the GUI option, but it will nonetheless remove
#   the item from the left pane.
Set-RegistryValue -Path "HKCU:\Software\Classes\CLSID\{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}" -Name "System.IsPinnedToNameSpaceTree" -Type DWord -Value 0

# Start --> Run --> control folders --> View --> Navigation pane --> Uncheck "Show This PC"
# https://www.elevenforum.com/t/add-or-remove-this-pc-in-navigation-pane-of-file-explorer-in-windows-11.7293/
Set-RegistryValue -Path "HKCU:\Software\Classes\CLSID\{20D04FE0-3AEA-1069-A2D8-08002B30309D}" -Name "System.IsPinnedToNameSpaceTree" -Type DWord -Value 0

# Pin and unpin some folders. Since there is no programmatic way to reorder pinned items, we first
# unpin everything and then repin items in an exact order.
$languageMode = $ExecutionContext.SessionState.LanguageMode
if ($languageMode -ne "FullLanguage") {
    $deviceGuard = Get-CimInstance -Namespace "root\Microsoft\Windows\DeviceGuard" -ClassName "Win32_DeviceGuard" -ErrorAction SilentlyContinue
    if ($null -ne $deviceGuard -and $deviceGuard.UsermodeCodeIntegrityPolicyEnforcementStatus -eq 2) {
        Write-Warning "Skipping pinning Quick Access folders, since Windows Defender Application Control (WDAC) is enforced, which restricts PowerShell to the language mode of: $languageMode"
    } else {
        Write-Warning "Skipping pinning Quick Access folders, since COM objects are not supported in the PowerShell language mode of: $languageMode"
    }
} else {
    $shell = New-Object -ComObject Shell.Application
    $quickAccess = $shell.Namespace("shell:::{679f85cb-0220-4080-b29b-5540cc05aab6}")
    $foldersToPin = @(
        "C:\",
        "$HOME",
        "$HOME\Desktop",
        "$HOME\Documents",
        "$HOME\Downloads"
    )
    $quickAccessPaths = @($quickAccess.Items() | ForEach-Object { $_.Path })
    $leadingQuickAccessPaths = @($quickAccessPaths | Select-Object -First $foldersToPin.Count)
    if (($leadingQuickAccessPaths -join "|") -ne ($foldersToPin -join "|")) {
        Write-Host "Pinning Quick Access folders."
        $foldersToUnpin = @("Desktop", "Documents", "Downloads", "Pictures", "Music", "Videos")
        foreach ($folderName in $foldersToUnpin) {
            $item = $quickAccess.Items() | Where-Object { $_.Name -eq $folderName }
            if ($item) {
                $item.InvokeVerb("unpinfromhome")
            }
        }
        foreach ($folderPath in $foldersToPin) {
            # Work around the bug where only some of the elements get pinned.
            Start-Sleep -Seconds 1
            $folder = $shell.Namespace($folderPath)
            $item = $folder.Self
            $item.InvokeVerb("pintohome")
        }
    }
}

# Remove "Home" from the bottom of the left pane. (There is no GUI method to do this.)
# https://www.elevenforum.com/t/add-or-remove-home-in-navigation-pane-of-file-explorer-in-windows-11.2449/
Set-RegistryValue -Path "HKCU:\Software\Classes\CLSID\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}" -Name "System.IsPinnedToNameSpaceTree" -Type DWord -Value 0

# Remove "Gallery" from the bottom of the left pane. (There is no GUI method to do this.)
# https://www.elevenforum.com/t/add-or-remove-gallery-in-file-explorer-navigation-pane-in-windows-11.14178/
Set-RegistryValue -Path "HKCU:\Software\Classes\CLSID\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}" -Name "System.IsPinnedToNameSpaceTree" -Type DWord -Value 0

# ------------------------------
# Miscellaneous Windows Settings
# ------------------------------

# Right-click desktop --> View --> Check "Auto arrange icons"
# https://winaero.com/blog/enable-auto-arrange-desktop-windows-10/
# - Explorer will rewrite the setting when it exits, so we first have to close explorer.
$desktopBagPath = "HKCU:\Software\Microsoft\Windows\Shell\Bags\1\Desktop"
$desktopFlags = 1075839525
if ((Get-RegistryValue -Path $desktopBagPath -Name "FFlags") -ne $desktopFlags) {
    taskkill /f /im explorer.exe
    Set-RegistryValue -Path $desktopBagPath -Name "FFlags" -Type DWord -Value $desktopFlags
    Start-Process explorer.exe
}

# Start --> Run --> lusrmgr.msc --> Users --> james --> General --> Check "Password never expires"
# https://old.reddit.com/r/sysadmin/comments/1ijux6b/wmic_has_been_deprecated_how_to_set_user_pw/
# shellcheck disable=SC2016
# - This requires elevation because users do not have permission to exempt themselves from system
#   policy.
if ($env:USERNAME -eq "james") {
    # We must use the 64-bit version of PowerShell to invoke the "Set-LocalUser" command.
    $powerShell64Path = "C:\Windows\sysnative\WindowsPowerShell\v1.0\powershell.exe"
    $passwordExpires = & $powerShell64Path -Command '(Get-LocalUser -Name james).PasswordExpires'
    Assert-LastExitCode "get the password expiration of the james user"
    if ($passwordExpires) {
        Write-Host "Setting the password of the james user to never expire."
        & $powerShell64Path -Command 'Set-LocalUser -Name james -PasswordNeverExpires $True'
        Assert-LastExitCode "set the password of the james user to never expire"
    }
}

# Restore the old right-click context menu.
# https://superuser.com/questions/1854126/how-can-i-get-back-old-context-menu-for-windows-11-right-click-tried-4-differen
Set-RegistryValue -Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" -Name "(default)" -Type String -Value ""

# --------------------
# Application Settings
# --------------------

# Notepad++
# The config file is not created until Notepad++ is launched for the first time.
$notepadConfigPath = "$env:APPDATA\Notepad++\config.xml"
if (-not (Test-Path $notepadConfigPath)) {
    $notepadProcess = Start-Process -FilePath "notepad++.exe" -PassThru
    $notepadStartDeadline = (Get-Date).AddSeconds(30)
    while ($notepadProcess.MainWindowHandle -eq 0) {
        if ($notepadProcess.HasExited) {
            throw "Notepad++ exited before its main window opened."
        }
        if ((Get-Date) -ge $notepadStartDeadline) {
            throw "Notepad++ did not open within 30 seconds."
        }
        Start-Sleep -Milliseconds 100
        $notepadProcess.Refresh()
    }
    $notepadProcess.CloseMainWindow() | Out-Null
    $notepadProcess.WaitForExit()

    if (-not (Test-Path $notepadConfigPath)) {
        throw "Notepad++ did not create the expected config file at: $notepadConfigPath"
    }
}
$scriptName = "set-notepad++-settings.sh"
$scriptPath = "$scriptsPath\$scriptName"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Zamiell/configs/refs/heads/main/app-settings/notepad%2B%2B/set-notepad%2B%2B-settings.sh" -OutFile $scriptPath
$wslScriptPath = wsl --exec wslpath -u $scriptPath
if ($LASTEXITCODE -ne 0) {
    throw "Failed to convert the Notepad++ settings script path for WSL."
}
wsl --exec env "USER=$env:USERNAME" bash $wslScriptPath
if ($LASTEXITCODE -ne 0) {
    throw "Failed to apply the Notepad++ settings."
}

# Windows Terminal
$terminalAppDataPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
$terminalSettingsPath = "$terminalAppDataPath\settings.json"
$terminalSettingsDownloadPath = "$scriptsPath\terminal-settings.json"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Zamiell/configs/refs/heads/main/windows/terminal/settings.json" -OutFile $terminalSettingsDownloadPath
if ((Test-Path $terminalSettingsPath) -and (Get-FileHash $terminalSettingsPath).Hash -eq (Get-FileHash $terminalSettingsDownloadPath).Hash) {
    Remove-Item $terminalSettingsDownloadPath
} else {
    Write-Host "Updating: $terminalSettingsPath"
    New-Item -ItemType Directory -Force -Path $terminalAppDataPath | Out-Null
    Move-Item -Force -Path $terminalSettingsDownloadPath -Destination $terminalSettingsPath
}

# ---
# End
# ---

# We restart the entire system instead of restarting explorer, since doing that results in the start
# menu showing an error about indexing being disabled.
if ($restartRequired) {
    $date = Get-Date
    Write-Output "Restarting at: $date"
    shutdown /r /t 0
} else {
    Write-Output "Successfully set Windows settings. (No restart is required.)"
}

# Steps that are not covered in this script:
# - Activate: irm https://get.activated.win | iex
#   https://massgrave.dev/
# - Settings --> System --> Display --> Advanced display settings --> Display 1: VG248 -->
#   Refresh rate: 164.917 Hz (the highest value)
# - Settings --> System --> Display --> Advanced display settings --> Display 2: VG248 -->
#   Refresh rate: 164.917 Hz (the highest value)
# - Settings --> System --> Sound --> Output --> Speakers (Scarlett Solo USB) --> Device properties
#   --> Rename "Speakers" to "Headphones"
# - Install Windhawk mod "Disable Taskbar Thumbnails": https://windhawk.net/mods/taskbar-thumbnails
#   (The popups are distracting when hovering over multiple taskbar elements in a row.)
# - Install Windhawk mod "Taskbar Labels for Windows 11": https://windhawk.net/mods/taskbar-labels
#   (This prevents the dynamic taskbar element width that started happening in Windows 11.)
# - It is not possible to programmatically install mods for Windhawk:
#   https://github.com/ramensoftware/windhawk/issues/154
# - Run "post-raid-array.ps1".
