#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$scriptsPath = "C:\Windows\Setup\scripts"
if (-not (Test-Path $scriptsPath)) {
    New-Item -Path $scriptsPath -ItemType Directory -Force | Out-Null
}
Start-Transcript -Path "$scriptsPath\install.log" -Append

$scriptName = "windows-update.ps1"
$scriptPath = "$scriptsPath\$scriptName"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Zamiell/configs/refs/heads/main/windows/$scriptName" -OutFile $scriptPath
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" -Name "$scriptName" -Value "powershell.exe -ExecutionPolicy Bypass -File $scriptPath"

# shutdown /r /t 0
