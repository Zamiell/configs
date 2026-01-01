$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$scriptsPath = "C:\Windows\Setup\scripts"
if (-not (Test-Path $scriptsPath)) {
    New-Item -Path $scriptsPath -ItemType Directory -Force | Out-Null
}
Start-Transcript -Path "$scriptsPath\install.log" -Append

# Ensure that the "D:\" drive exists.
$testPath = "D:\Text\addresses.txt"
if (-not (Test-Path $scriptsPath)) {
    Write-Error "The $testPath file does not exist so the proper D drive is not connected."
    exit 1
}

# Copy over start menu shortcuts.
Copy-Item "D:\Backup\Start Menu\Shortcuts\*" "$HOME\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\"
Copy-Item "D:\Backup\Start Menu\Startup Shortcuts\*" "$HOME\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\"

# Run the items in the "Startup Shortcuts" directory:
# https://stackoverflow.com/questions/58050529/need-windows-command-file-that-runs-all-commands-in-a-folder
Get-ChildItem "D:\Backup\Start Menu\Startup Shortcuts\*" | ForEach-Object { Start-Process $_ }

# Copy SSH keys.
Copy-Item "D:\Backup\App Settings\.ssh\*" "$HOME\.ssh\"

# Set background.
& "D:\Repositories\bing-wallpaper-manual\scripts\install-scheduled-task.ps1"
