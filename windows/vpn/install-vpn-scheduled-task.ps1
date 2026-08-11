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
# an administrator-only step is needed. It is registered with LogonType S4U
# so no password needs to be scripted here, but S4U logon for a domain
# account commonly fails (LogonUserS4U / ERROR_NO_SUCH_LOGON_SESSION) unless
# the domain and this machine are set up for Kerberos protocol transition.
# Register-ScheduledTask cannot set LogonType Password without a plaintext
# password argument, so if S4U fails, convert the task manually (one time):
# Task Scheduler -> "VPN Connect - Elevated" -> Properties -> General tab ->
# select "Run whether user is logged on or not", uncheck "Do not store
# password", click OK, and enter admin_jnesta's password when prompted.
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

    # By default only administrators or the task's own principal can start a
    # task, so CORP\jnesta (a standard, non-admin account) would be denied
    # when Invoke-VpnElevatedTask calls Run() on this admin_jnesta-owned
    # task. Grant jnesta GENERIC_READ | GENERIC_EXECUTE (read + run-on-demand
    # only, no modify/delete rights) via the task's security descriptor.
    $service = New-Object -ComObject "Schedule.Service"
    $service.Connect()
    $task = $service.GetFolder("\").GetTask($VpnElevatedTaskName)
    $standardSid = (New-Object System.Security.Principal.NTAccount($VpnStandardAccount)).
        Translate([System.Security.Principal.SecurityIdentifier]).Value
    $securityDescriptor = $task.GetSecurityDescriptor(0xF) + "(A;;GRGX;;;$standardSid)"
    $task.SetSecurityDescriptor($securityDescriptor, 0)

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
