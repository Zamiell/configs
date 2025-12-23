#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$scriptsPath = "C:\Windows\Setup\scripts"
if (-not (Test-Path $scriptsPath)) {
    New-Item -Path $scriptsPath -ItemType Directory -Force | Out-Null
}
Start-Transcript -Path "$scriptsPath\install.log" -Append

# -------
# Cleanup
# -------

# There are several empty directories on a fresh Windows 11 LTSC.
if (Test-Path "C:\inetpub") {
  Remove-Item "C:\inetpub" # This requires elevation.
}
if (Test-Path "C:\PerfLogs") {
  Remove-Item "C:\PerfLogs" # This requires elevation.
}
if (Test-Path "C:\Windows.old") {
  Remove-Item "C:\Windows.old"
}

# The desktop starts with a "Microsoft Edge" shortcut.
if (Test-Path "C:\Users\james\Desktop\Microsoft Edge.lnk") {
  Remove-Item "C:\Users\james\Desktop\Microsoft Edge.lnk"
}

# -------
# Install
# -------

# Install winget.
# https://github.com/asheroto/winget-install
if ((Get-Command winget -ErrorAction SilentlyContinue)) {
  Write-Host "winget is already installed."
} else {
  Install-Script winget-install -Force # "-Force" is required to avoid the prompt.
  winget-install
}

function Install-WingetProgram {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Id
    )

    winget list --accept-source-agreements --exact --id $Id | Out-Null
    if ($LASTEXITCODE -eq 0) {
      Write-Host "Package is already installed: $Id"
      return
    }

    # - The "--accept-source-agreements" flag is used because the first time that you download a
    #   module, the tool will force you to accept that you are downloading 3rd party modules.
    # - The "--silent" flag is used because some specific apps will open a new window to show
    #   progress, which is distracting.
    # - The "--exact" flag is used because by default, winget will perform a search and potentially
    #   install non-intended packages.
    Write-Host "Installing package: $Id"
    winget install --accept-source-agreements --silent --exact --id $Id
    if ($LASTEXITCODE -ne 0) {
        throw "Installation failed for package: $Id"
    }
    Write-Host "Successfully installed package: $Id"
}

# AutoHotkey is installed first because it is used to customize Chrome.
Install-WingetProgram "AutoHotkey.AutoHotkey"

# Google Chrome
# We use "Google.Chrome.EXE" instead of "Google.Chrome" because otherwise, installation can fail
# with the following error:
# Installer hash does not match; this cannot be overridden when running as admin
# https://github.com/microsoft/winget-cli/issues/715
Install-WingetProgram "Google.Chrome.EXE"
# Change the Google Chrome default download directory:
# https://stackoverflow.com/questions/53505079/how-to-change-default-download-folder-in-chrome-using-powershell
# In order to do this, we must edit the file:
# C:\Users\james\AppData\Local\Google\Chrome\User Data\Default\Preferences
# However, it will not exist until Chrome is started for the first time.
$scriptName = "open-and-close-chrome.ahk"
$scriptPath = "$scriptsPath\$scriptName"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Zamiell/configs/refs/heads/main/windows/$scriptName" -OutFile $scriptPath
Start-Process "$scriptPath" -Wait
$preferencesPath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Preferences"
$preferences = Get-Content $preferencesPath -Raw
$preferences -replace ',"extensions":',',"download":{"directory_upgrade":true,"default_directory":"C:\\Users\\james\\Desktop"},"extensions":' | Set-Content -Path $preferencesPath

# Other Browsers
Install-WingetProgram "Mozilla.Firefox.ESR"

# Programming
Install-WingetProgram "Microsoft.WindowsTerminal"
Install-WingetProgram "Git.Git"
Install-WingetProgram "GnuWin32.Tree"
Install-WingetProgram "Microsoft.VisualStudioCode"
# VSCode does not install to the right-click context menu by default, so we manually modify the
# registry. (This is cleaner than invoking winget with custom arguments.)
# https://github.com/microsoft/winget-cli/discussions/1798
$scriptName = "vscode-context-menu.reg"
$scriptPath = "$scriptsPath\$scriptName"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Zamiell/configs/refs/heads/main/windows/registry/$scriptName" -OutFile $scriptPath
reg import $scriptPath
Install-WingetProgram "Notepad++.Notepad++"
Install-WingetProgram "GitHub.cli"
Install-WingetProgram "Schniz.fnm"
# Installing Node.js LTS with this command is idempotent.
# cspell:disable-next-line
& "$HOME\AppData\Local\Microsoft\WinGet\Packages\Schniz.fnm_Microsoft.Winget.Source_8wekyb3d8bbwe\fnm.exe" install --lts

# Games
Install-WingetProgram "Discord.Discord"
Install-WingetProgram "Valve.Steam"
# Stop Steam from starting on boot.
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v Steam /f

# Miscellaneous
Install-WingetProgram "7zip.7zip"
Install-WingetProgram "qBittorrent.qBittorrent"
Install-WingetProgram "RamenSoftware.Windhawk"
# It is not possible to programmatically install mods for Windhawk:
# https://github.com/ramensoftware/windhawk/issues/154
Install-WingetProgram "VideoLAN.VLC"

# Desktop cleanup
if (Test-Path "$HOME\Desktop\Google Chrome.lnk") {
  Remove-Item "$HOME\Desktop\Google Chrome.lnk"
}
if (Test-Path "C:\Users\Public\Desktop\Firefox.lnk") {
  Remove-Item "C:\Users\Public\Desktop\Firefox.lnk"
}
if (Test-Path "$HOME\Desktop\Discord.lnk") {
  Remove-Item "$HOME\Desktop\Discord.lnk"
}
if (Test-Path "C:\Users\Public\Desktop\Steam.lnk") {
  Remove-Item "C:\Users\Public\Desktop\Steam.lnk"
}
if (Test-Path "C:\Users\Public\Desktop\Windhawk.lnk") {
  Remove-Item "C:\Users\Public\Desktop\Windhawk.lnk"
}
if (Test-Path "C:\Users\Public\Desktop\VLC media player.lnk") {
  Remove-Item "C:\Users\Public\Desktop\VLC media player.lnk"
}

Write-Output "Successfully cleaned and installed software."

# Set the next installation script to run on the next boot.
$scriptName = "set-windows-settings.ps1"
$scriptPath = "$scriptsPath\$scriptName"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Zamiell/configs/refs/heads/main/windows/$scriptName" -OutFile $scriptPath
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" -Name "$scriptName" -Value "powershell.exe -ExecutionPolicy Bypass -File $scriptPath"

# Uncomment the below once this script is successful for the first time.
# shutdown /r /t 0
