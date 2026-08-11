#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$taskName = "VPN Connect"
$vpnScript = Join-Path -Path $PSScriptRoot -ChildPath "vpn-connect.ps1"

if (-not (Test-Path -Path $vpnScript -PathType Leaf)) {
    throw "VPN connection script does not exist: $vpnScript"
}

$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existingTask) {
    Write-Host "Scheduled task `"$taskName`" already exists. Exiting."
    return
}

$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$vpnScript`"" `
    -WorkingDirectory $PSScriptRoot
$time = "12:00AM"
$trigger = New-ScheduledTaskTrigger -Daily -At $time
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -MultipleInstances IgnoreNew `
    -StartWhenAvailable `
    -WakeToRun
$principal = New-ScheduledTaskPrincipal `
    -UserId ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name) `
    -LogonType Interactive `
    -RunLevel Highest

Register-ScheduledTask `
    -TaskName $taskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal `
    -ErrorAction Stop

Write-Host "Successfully installed scheduled task: $taskName"
Write-Host "It will run daily at: $time"
