#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$scriptsPath = Join-Path -Path $env:TEMP -ChildPath "scripts"
if (-not (Test-Path $scriptsPath)) {
    New-Item -Path $scriptsPath -ItemType Directory -Force | Out-Null
}
Start-Transcript -Path "$scriptsPath\install.log" -Append

$restartRequired = $false

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

# ----------------------------
# Settings --> Personalization
# ----------------------------

# Settings --> Personalization --> Background --> Personalize your background --> Picture
# https://www.elevenforum.com/t/enable-or-disable-windows-spotlight-on-desktop-background-in-windows-11.18246/
# - This requires elevation because the "Policies" subkey is protected.
Set-RegistryValue -Path "HKCU:\Software\Policies\Microsoft\Windows\CloudContent" -Name "DisableSpotlightCollectionOnDesktop" -Type DWord -Value 1

# Settings --> Personalization --> Themes --> Desktop icon settings --> Uncheck "Recycle Bin"
# https://stackoverflow.com/questions/77420778/remove-recycle-bin-from-desktop-with-powershell
# - This requires elevation because the "Policies" subkey is protected.
# - This requires a restart of explorer to take effect.
Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\NonEnum" -Name "{645FF040-5081-101B-9F08-00AA002F954E}" -Type DWord -Value 1

# Settings --> Personalization --> Taskbar --> Taskbar behaviors -->
# Uncheck "Show my taskbar on all displays"
# https://www.tenforums.com/tutorials/104832-enable-disable-show-taskbar-all-displays-windows-10-a.html
# - This requires elevation because the "Policies" subkey is protected.
Set-RegistryValue -Path "HKCU:\Software\Policies\Microsoft\Windows\Explorer" -Name "TaskbarNoMultimon" -Type DWord -Value 1

# ------------------------------
# Miscellaneous Windows Settings
# ------------------------------

# Right click "Recycle Bin" --> Properties --> Don't move files to the Recycle Bin. Remove files
# immediately when deleted.
# https://superuser.com/questions/1616394/how-to-use-registry-to-disable-recycle-bin-for-all-users-on-all-drives-and-disp
# - This requires elevation because the "Policies" subkey is protected.
Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoRecycleFiles" -Type DWord -Value 1

# Right click "Recycle Bin" --> Properties --> Display delete confirmation dialog
# https://superuser.com/questions/1616394/how-to-use-registry-to-disable-recycle-bin-for-all-users-on-all-drives-and-disp
# - This requires elevation because the "Policies" subkey is protected.
# - This requires a restart of explorer to take effect.
Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "ConfirmFileDelete" -Type DWord -Value 1

# Restore Windows Photo Viewer
# - By default, Windows Photo Viewer is disabled in Windows 11 LTSC:
#   https://www.tenforums.com/tutorials/14312-restore-windows-photo-viewer-windows-10-a.html#option2
# - After setting this, the default app for the file type must be manually selected in the "Open
#   with..." menu. Doing this automatically is complicated, so we do not bother:
#   https://superuser.com/questions/1748620/on-windows-10-is-there-a-file-i-can-modify-to-configure-the-default-apps
# - This requires elevation because the registry file writes to "HKEY_CLASSES_ROOT".
$photoViewerCommandPath = "Registry::HKEY_CLASSES_ROOT\Applications\photoviewer.dll\shell\open\command"
if (-not (Test-Path $photoViewerCommandPath)) {
    Write-Host "Enabling Windows Photo Viewer."
    $scriptName = "enable-windows-photo-viewer.reg"
    $scriptPath = "$scriptsPath\$scriptName"
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Zamiell/configs/refs/heads/main/windows/registry/$scriptName" -OutFile $scriptPath
    Start-Process -FilePath "regedit.exe" -ArgumentList "/s", "`"$scriptPath`"" -Wait
    if (-not (Test-Path $photoViewerCommandPath)) {
        throw "Failed to import the registry file at: $scriptPath"
    }
}

# ---
# End
# ---

if ($restartRequired) {
    Write-Output "Successfully set Windows admin settings. (Restart explorer or the system for the changes to take effect.)"
} else {
    Write-Output "Successfully set Windows admin settings."
}
