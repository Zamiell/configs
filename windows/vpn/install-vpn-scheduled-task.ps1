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

Initialize-VpnSecureDir

$commonSettings = @{
    AllowStartIfOnBatteries = $true
    DontStopIfGoingOnBatteries = $true
    ExecutionTimeLimit = [TimeSpan]::Zero
    MultipleInstances = "Parallel"
    StartWhenAvailable = $true
}

# The helper runs as LocalSystem, which has the required local privileges and never needs domain
# connectivity or a stored password.
$elevatedAction = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$elevatedScript`" -Action `$(Arg0)" `
    -WorkingDirectory $PSScriptRoot
$elevatedSettings = New-ScheduledTaskSettingsSet @commonSettings
$elevatedPrincipal = New-ScheduledTaskPrincipal `
    -UserId "SYSTEM" `
    -LogonType ServiceAccount `
    -RunLevel Highest

Register-ScheduledTask `
    -TaskName $VpnElevatedTaskName `
    -Action $elevatedAction `
    -Settings $elevatedSettings `
    -Principal $elevatedPrincipal `
    -Force `
    -ErrorAction Stop

$service = New-Object -ComObject "Schedule.Service"
$service.Connect()
$task = $service.GetFolder("\").GetTask($VpnElevatedTaskName)
$standardSid = (New-Object System.Security.Principal.NTAccount($VpnStandardAccount)).
    Translate([System.Security.Principal.SecurityIdentifier]).Value
$securityDescriptor = $task.GetSecurityDescriptor(0xF) + "(A;;GRGX;;;$standardSid)"
$task.SetSecurityDescriptor($securityDescriptor, 0)

Write-Host "Successfully installed scheduled task: $VpnElevatedTaskName"

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
    -Force `
    -ErrorAction Stop

Write-Host "Successfully installed scheduled task: $taskName"
Write-Host "It will run daily at: $time"
