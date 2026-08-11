# Runs as CORP\jnesta (Interactive) via the "VPN Connect" scheduled task.
# Drives the interactive parts of the VPN connect flow (launching Edge for
# the SAML/SSO login and capturing the resulting prelogin cookie), and
# delegates the privileged parts (anything invoking openconnect.exe, which
# needs administrator rights to create the network adapter) to the
# "VPN Connect - Elevated" task via vpn-common.ps1's Invoke-VpnElevatedTask.
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. (Join-Path -Path $PSScriptRoot -ChildPath "vpn-common.ps1")

$edge = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
$captureScript = Join-Path -Path $PSScriptRoot -ChildPath "vpn-capture-cookie.ps1"
$edgeLaunchScript = Join-Path -Path $PSScriptRoot -ChildPath "vpn-open-edge.ps1"
$edgeProfile = Join-Path -Path $PSScriptRoot -ChildPath ".openconnect-edge-profile"
$edgeShortcut = Join-Path -Path $PSScriptRoot -ChildPath ".openconnect-edge-launch.lnk"
$debugPort = 9223

$discoverStatus = Invoke-VpnElevatedTask -Action "Discover"
if ($discoverStatus -ne 0 -or -not (Test-Path -Path $VpnDiscoverResultFile -PathType Leaf)) {
    Write-Error "The elevated VPN discovery step failed (exit code: $discoverStatus)." -ErrorAction Continue
    exit $(if ($discoverStatus -ne 0) { $discoverStatus } else { 1 })
}

$url = Get-Content -Path $VpnDiscoverResultFile -Raw
Remove-VpnTempFile -Path $VpnDiscoverResultFile

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
    -TargetHost $VpnGateway `
    -PreferredAccount "jnesta@logixhealth.com"

if ([string]::IsNullOrEmpty($preloginCookie)) {
    Write-Error "GlobalProtect returned an empty prelogin cookie." -ErrorAction Continue
    exit 1
}

Initialize-VpnSecureDir
Set-Content -Path $VpnCookieFile -Value $preloginCookie -NoNewline
$preloginCookie = $null

$connectStatus = Invoke-VpnElevatedTask -Action "Connect"
exit $connectStatus
