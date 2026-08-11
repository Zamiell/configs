# Shared configuration and helpers for the "VPN Connect" scheduled tasks. Used by "vpn-connect.ps1"
# and "vpn-connect-elevated.ps1".

$script:VpnStandardAccount = "CORP\jnesta"
$script:VpnElevatedTaskName = "VPN Connect - Elevated"

$script:VpnGateway = "bedgw.logixhealth.com"
$script:VpnOpenConnect = "C:\Program Files\OpenConnect\openconnect.exe"
$script:VpnCaFile = "C:\tls\BEDROOTCA001.crt"

$script:VpnSecureDir = Join-Path -Path $env:ProgramData -ChildPath "VPNConnect"
$script:VpnCookieFile = Join-Path -Path $VpnSecureDir -ChildPath "prelogin-cookie.tmp"
$script:VpnDiscoverResultFile = Join-Path -Path $VpnSecureDir -ChildPath "discover-result.tmp"
$script:VpnInteractiveLog = Join-Path -Path $VpnSecureDir -ChildPath "interactive.log"
$script:VpnElevatedLog = Join-Path -Path $VpnSecureDir -ChildPath "elevated.log"

# Grants Full Control on the secure hand-off directory only to the standard account and SYSTEM, so
# other users cannot read the cookie or SAML URL.
function Initialize-VpnSecureDir {
    if (-not (Test-Path -Path $VpnSecureDir -PathType Container)) {
        New-Item -Path $VpnSecureDir -ItemType Directory -Force | Out-Null
    }

    $acl = New-Object System.Security.AccessControl.DirectorySecurity
    $acl.SetAccessRuleProtection($true, $false)

    $identities = @(
        (New-Object System.Security.Principal.NTAccount($VpnStandardAccount)),
        (New-Object System.Security.Principal.SecurityIdentifier "S-1-5-18")
    )
    foreach ($identity in $identities) {
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $identity, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
        $acl.AddAccessRule($rule)
    }

    Set-Acl -Path $VpnSecureDir -AclObject $acl
}

function Remove-VpnTempFile {
    param([Parameter(Mandatory = $true)][string]$Path)
    Remove-Item -Path $Path -Force -ErrorAction SilentlyContinue
}

# Starts the given action on the elevated task via the Task Scheduler COM API (so the action
# string's "$(Arg0)" placeholder is filled in), then blocks until that run instance finishes.
function Invoke-VpnElevatedTask {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("Discover", "Connect")]
        [string]$Action
    )

    $service = New-Object -ComObject "Schedule.Service"
    $service.Connect()
    $folder = $service.GetFolder("\")
    $task = $folder.GetTask($VpnElevatedTaskName)
    $task.Run($Action) | Out-Null

    $started = $false
    for ($i = 0; $i -lt 100; $i++) {
        if ($task.State -eq 4) {
            $started = $true
            break
        }
        Start-Sleep -Milliseconds 100
    }
    if (-not $started) {
        throw "The `"$VpnElevatedTaskName`" task did not start within 10 seconds."
    }

    while ($task.State -eq 4) {
        Start-Sleep -Milliseconds 250
    }

    return $task.LastTaskResult
}
