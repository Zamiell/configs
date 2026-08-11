$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$openConnect = "C:\Program Files\OpenConnect\openconnect.exe"
$edge = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
$caFile = "C:\tls\BEDROOTCA001.crt"
$captureScript = Join-Path -Path $PSScriptRoot -ChildPath "vpn-capture-cookie.ps1"
$edgeLaunchScript = Join-Path -Path $PSScriptRoot -ChildPath "vpn-open-edge.ps1"
$edgeProfile = Join-Path -Path $PSScriptRoot -ChildPath ".openconnect-edge-profile"
$edgeShortcut = Join-Path -Path $PSScriptRoot -ChildPath ".openconnect-edge-launch.lnk"
$debugPort = 9223
$gateway = "bedgw.logixhealth.com"

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

Disconnect-ExistingSession

$previousErrorActionPreference = $ErrorActionPreference
try {
    $ErrorActionPreference = "Continue"
    $openConnectOutput = @(
        & $openConnect `
            --protocol=gp `
            "--cafile=$caFile" `
            --os=win `
            --usergroup=gateway `
            "https://$gateway" 2>&1
    )
    $openConnectStatus = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
$openConnectOutput | Write-Output

$samlPattern = "^SAML REDIRECT authentication is required via (https://login\.microsoftonline\.com/.*)$"
$url = $openConnectOutput |
    ForEach-Object { if ("$_" -match $samlPattern) { $Matches[1] } } |
    Select-Object -Last 1

if ([string]::IsNullOrEmpty($url)) {
    Write-Error "Unable to find the Microsoft SAML URL." -ErrorAction Continue
    exit $openConnectStatus
}

& $edgeLaunchScript `
    -EdgePath $edge `
    -ProfilePath $edgeProfile `
    -Url $url `
    -Port $debugPort `
    -ShortcutPath $edgeShortcut

$debugReady = $false
for ($attempt = 0; $attempt -lt 50; $attempt++) {
    try {
        Invoke-WebRequest -Uri "http://127.0.0.1:$debugPort/json/version" -UseBasicParsing | Out-Null
        $debugReady = $true
        break
    }
    catch {
        Start-Sleep -Milliseconds 100
    }
}
Remove-Item -Path $edgeShortcut -Force -ErrorAction SilentlyContinue

if (-not $debugReady) {
    Write-Error "Microsoft Edge did not expose its local automation endpoint." -ErrorAction Continue
    Write-Error "Close the VPN Edge window and run the script again." -ErrorAction Continue
    exit 1
}

$preloginCookie = & $captureScript `
    -Port $debugPort `
    -TargetHost $gateway `
    -PreferredAccount "jnesta@logixhealth.com"

if ([string]::IsNullOrEmpty($preloginCookie)) {
    Write-Error "GlobalProtect returned an empty prelogin cookie." -ErrorAction Continue
    exit 1
}

$previousErrorActionPreference = $ErrorActionPreference
try {
    $ErrorActionPreference = "Continue"
    $preloginCookie |
        & $openConnect `
            --protocol=gp `
            "--cafile=$caFile" `
            --os=win `
            "--user=jnesta@logixhealth.com" `
            "--usergroup=gateway:prelogin-cookie" `
            --passwd-on-stdin `
            "https://$gateway"
    $openConnectStatus = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}

$preloginCookie = $null
exit $openConnectStatus
