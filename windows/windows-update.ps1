#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$scriptsPath = "C:\Windows\Setup\scripts"
if (-not (Test-Path $scriptsPath)) {
    New-Item -Path $scriptsPath -ItemType Directory -Force | Out-Null
}
Start-Transcript -Path "$scriptsPath\install.log" -Append

# Before invoking Windows Update and automatically restarting the system, set the next installation
# script to run on the next boot.
$scriptName = "cleanup-and-install-software.ps1"
$scriptPath = "$scriptsPath\$scriptName"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Zamiell/configs/refs/heads/main/windows/$scriptName" -OutFile $scriptPath
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" -Name "$scriptName" -Value "powershell.exe -ExecutionPolicy Bypass -File $scriptPath"

# The "wuauserv" service needs to be running for the below commands to work properly.
Start-Service -Name wuauserv

# Use the "PSWindowsUpdate" module to install Windows updates.
# https://www.powershellgallery.com/packages/PSWindowsUpdate/2.2.1.5
Install-PackageProvider -Name NuGet -Force # "-Force" is required to avoid the prompt.
Install-Module PSWindowsUpdate -Force # "-Force" is required to avoid the prompt.

# We must provide retry logic to work around the following error:
# TerminatingError(Get-WindowsUpdate): "Exception from HRESULT: 0x80248007"
# (This is a race condition from Windows Update running in the background and also running from the
# script.)
$maxRetries = 3
$retryCount = 0
$success = $false

while (-not $success -and $retryCount -lt $maxRetries) {
    try {
        Write-Output "Installing Windows updates (attempt $($retryCount + 1))..."
        Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot -ErrorAction Stop
        $success = $true
    }
    catch {
        $errorCode = $_.Exception.HResult
        Write-Warning "Windows update failed with error code: $errorCode"

        if ($retryCount -lt ($maxRetries - 1)) {
            Write-Output "Retrying in 10 seconds..."
            Start-Sleep -Seconds 10
            $retryCount++
        } else {
            Write-Error "Failed to install updates after $maxRetries attempts."
            throw $_
        }
    }
}
