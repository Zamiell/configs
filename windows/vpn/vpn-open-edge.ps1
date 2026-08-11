param(
    [Parameter(Mandatory = $true)]
    [string]$EdgePath,

    [Parameter(Mandatory = $true)]
    [string]$ProfilePath,

    [Parameter(Mandatory = $true)]
    [string]$Url,

    [Parameter(Mandatory = $true)]
    [int]$Port,

    [Parameter(Mandatory = $true)]
    [string]$ShortcutPath
)

$ErrorActionPreference = "Stop"

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($ShortcutPath)
$shortcut.TargetPath = $EdgePath
$shortcut.Arguments = @(
    "--remote-debugging-port=$Port"
    "--remote-allow-origins=*"
    "--user-data-dir=`"$ProfilePath`""
    "--disable-background-mode"
    "--no-first-run"
    "--app=`"$Url`""
) -join " "
$shortcut.Save()

Start-Process -FilePath "$env:WINDIR\explorer.exe" -ArgumentList "`"$ShortcutPath`""
