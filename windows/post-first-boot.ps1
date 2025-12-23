#Requires -RunAsAdministrator

$scriptsPath = "C:\Windows\Setup\scripts"
$scriptName = "windows-update.ps1"
$scriptPath = "$scriptsPath\$scriptName"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Zamiell/configs/refs/heads/main/windows/$scriptName" -OutFile $scriptPath
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" -Name "windows-update" -Value "powershell.exe -ExecutionPolicy Bypass -File $scriptPath"
