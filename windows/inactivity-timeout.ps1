#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$taskName = "Disable Inactivity Timeout"
$action = New-ScheduledTaskAction `
    -Execute "reg.exe" `
    -Argument 'add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v InactivityTimeoutSecs /t REG_DWORD /d 0 /f'
$trigger = New-ScheduledTaskTrigger `
    -Once `
    -At (Get-Date) `
    -RepetitionInterval (New-TimeSpan -Minutes 5)
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -StartWhenAvailable
$principal = New-ScheduledTaskPrincipal `
    -UserId "SYSTEM" `
    -LogonType ServiceAccount `
    -RunLevel Highest

Register-ScheduledTask `
    -TaskName $taskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal `
    -Force `
    -ErrorAction Stop

Write-Host "Successfully installed scheduled task: $taskName"
Write-Host "It will run every 5 minutes."
