#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. (Join-Path -Path $PSScriptRoot -ChildPath "vpn-common.ps1")

$taskName = "VPN Connect"
$vpnScript = Join-Path -Path $PSScriptRoot -ChildPath "vpn-connect.ps1"
$elevatedScript = Join-Path -Path $PSScriptRoot -ChildPath "vpn-connect-elevated.ps1"

if (-not (Test-Path -Path $vpnScript -PathType Leaf)) {
    throw "VPN connection script does not exist: $vpnScript"
}
if (-not (Test-Path -Path $elevatedScript -PathType Leaf)) {
    throw "Elevated VPN connection script does not exist: $elevatedScript"
}

$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
$existingElevatedTask = Get-ScheduledTask -TaskName $VpnElevatedTaskName -ErrorAction SilentlyContinue
if ($existingTask -and $existingElevatedTask) {
    Write-Host "Scheduled tasks `"$taskName`" and `"$VpnElevatedTaskName`" already exist. Exiting."
    return
}

$commonSettings = @{
    AllowStartIfOnBatteries = $true
    DontStopIfGoingOnBatteries = $true
    ExecutionTimeLimit = [TimeSpan]::Zero
    MultipleInstances = "Parallel"
    StartWhenAvailable = $true
}

# "VPN Connect - Elevated" is never triggered on its own; it is started
# programmatically by vpn-connect.ps1 (via Invoke-VpnElevatedTask) whenever
# an administrator-only step is needed. It runs as the elevation-only admin
# account with LogonType S4U, which grants "run whether logged on or not"
# without ever storing that account's password.
if (-not $existingElevatedTask) {
    $elevatedAction = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument "-NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$elevatedScript`" -Action `$(Arg0)" `
        -WorkingDirectory $PSScriptRoot
    $elevatedSettings = New-ScheduledTaskSettingsSet @commonSettings
    $elevatedPrincipal = New-ScheduledTaskPrincipal `
        -UserId $VpnAdminAccount `
        -LogonType S4U `
        -RunLevel Highest

    Register-ScheduledTask `
        -TaskName $VpnElevatedTaskName `
        -Action $elevatedAction `
        -Settings $elevatedSettings `
        -Principal $elevatedPrincipal `
        -ErrorAction Stop

    Write-Host "Successfully installed scheduled task: $VpnElevatedTaskName"
}
else {
    Write-Host "Scheduled task `"$VpnElevatedTaskName`" already exists; skipping."
}

if (-not $existingTask) {
    $action = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument "-NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$vpnScript`"" `
        -WorkingDirectory $PSScriptRoot
    $time = "12:00AM"
    $trigger = New-ScheduledTaskTrigger -Daily -At $time
    $settings = New-ScheduledTaskSettingsSet @commonSettings -WakeToRun
    $principal = New-ScheduledTaskPrincipal `
        -UserId $VpnStandardAccount `
        -LogonType Interactive `
        -RunLevel Limited

    Register-ScheduledTask `
        -TaskName $taskName `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -Principal $principal `
        -ErrorAction Stop

    Write-Host "Successfully installed scheduled task: $taskName"
    Write-Host "It will run daily at: $time"
}
else {
    Write-Host "Scheduled task `"$taskName`" already exists; skipping."
}
