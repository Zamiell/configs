#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
Set-PSDebug -Trace 1
$scriptsPath = "C:\Windows\Setup\scripts\"
# The transcript has already started from the previous process.

# Before invoking Windows Update and automatically restarting the system, set the next installation
# script to run on the next boot.
$scriptName = "cleanup-and-install-software.ps1"
$scriptPath = "$scriptsPath\$scriptName"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Zamiell/configs/refs/heads/main/windows/$scriptName" -OutFile $scriptPath
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" -Name "InstallWinget" -Value "powershell.exe -ExecutionPolicy Bypass -File $scriptPath"

# Use the "PSWindowsUpdate" module to install Windows updates.
# https://www.powershellgallery.com/packages/PSWindowsUpdate/2.2.1.5
Install-PackageProvider -Name NuGet -Force # "-Force" is required to avoid the prompt.
Install-Module PSWindowsUpdate -Force # "-Force" is required to avoid the prompt.
Get-WindowsUpdate
Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot
