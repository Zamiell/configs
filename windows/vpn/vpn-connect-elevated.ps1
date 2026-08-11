# Runs as CORP\admin_jnesta via the "VPN Connect - Elevated" scheduled task,
# started programmatically (never on its own trigger) by vpn-connect.ps1
# using Invoke-VpnElevatedTask. Handles only the pieces of the VPN connect
# flow that require administrator rights to create the OpenConnect network
# adapter; never shows any UI.
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Discover", "Connect")]
    [string]$Action
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. (Join-Path -Path $PSScriptRoot -ChildPath "vpn-common.ps1")

function Get-OpenConnectProcess {
    Get-CimInstance Win32_Process -Filter "Name='openconnect.exe'"
}

function Test-OpenConnectAdapter {
    $null -ne (Get-NetAdapter -InterfaceDescription "OpenConnect Tunnel" -ErrorAction SilentlyContinue)
}

function Disconnect-ExistingSession {
    $processes = @(Get-OpenConnectProcess)
    if ($processes.Count -eq 0) {
        return
    }

    Write-Output "An existing VPN connection is already running; disconnecting it first."

    foreach ($process in $processes) {
        Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue
    }

    $waited = 0
    while ($waited -lt 15 -and @(Get-OpenConnectProcess).Count -gt 0) {
        Start-Sleep -Seconds 1
        $waited++
    }

    $waited = 0
    while ($waited -lt 15 -and (Test-OpenConnectAdapter)) {
        Start-Sleep -Seconds 1
        $waited++
    }
}

Initialize-VpnSecureDir

if ($Action -eq "Discover") {
    Remove-VpnTempFile -Path $VpnDiscoverResultFile

    Disconnect-ExistingSession

    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $openConnectOutput = @(
            & $VpnOpenConnect `
                --protocol=gp `
                "--cafile=$VpnCaFile" `
                --os=win `
                --usergroup=gateway `
                "https://$VpnGateway" 2>&1
        )
        $openConnectStatus = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    $openConnectOutput | ForEach-Object { $_.ToString() } | Write-Output

    $samlPattern = "^SAML REDIRECT authentication is required via (https://login\.microsoftonline\.com/.*)$"
    $url = $openConnectOutput |
        ForEach-Object { if ("$_" -match $samlPattern) { $Matches[1] } } |
        Select-Object -Last 1

    if ([string]::IsNullOrEmpty($url)) {
        Write-Error "Unable to find the Microsoft SAML URL." -ErrorAction Continue
        exit $(if ($openConnectStatus -ne 0) { $openConnectStatus } else { 1 })
    }

    Set-Content -Path $VpnDiscoverResultFile -Value $url -NoNewline
    exit 0
}
else {
    if (-not (Test-Path -Path $VpnCookieFile -PathType Leaf)) {
        Write-Error "Prelogin cookie file was not found: $VpnCookieFile" -ErrorAction Continue
        exit 1
    }

    $preloginCookie = Get-Content -Path $VpnCookieFile -Raw
    Remove-VpnTempFile -Path $VpnCookieFile

    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $preloginCookie |
            & $VpnOpenConnect `
                --protocol=gp `
                "--cafile=$VpnCaFile" `
                --os=win `
                "--user=jnesta@logixhealth.com" `
                "--usergroup=gateway:prelogin-cookie" `
                --passwd-on-stdin `
                "https://$VpnGateway"
        $openConnectStatus = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    $preloginCookie = $null
    exit $openConnectStatus
}
