$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
Set-PSDebug -Trace 1
Start-Transcript -Path "C:\Windows\Setup\scripts\install.log" -Append

# Copy over start menu shortcuts.
Copy-Item "D:\Backup\Start Menu\Shortcuts\*" "$HOME\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\"
Copy-Item "D:\Backup\Start Menu\Startup Shortcuts\*" "$HOME\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\"

# Run the items in the "Startup Shortcuts" directory:
# https://stackoverflow.com/questions/58050529/need-windows-command-file-that-runs-all-commands-in-a-folder
Get-ChildItem "D:\Backup\Start Menu\Startup Shortcuts\*" | ForEach-Object { Start-Process $_ }

# Pin Google Chrome:
# http://www.technosys.net/products/utils/pintotaskbar
D:\Apps\Misc\syspin.exe "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe" c:"Pin to taskbar"

# Set Google Chrome to be the default browser:
# https://kolbi.cz/blog/2017/11/10/setdefaultbrowser-set-the-default-browser-per-user-on-windows-10-and-server-2016-build-1607/
D:\Apps\Misc\SetDefaultBrowser\SetDefaultBrowser.exe chrome

# Copy SSH keys.
Copy-Item "D:\Backup\App Settings\.ssh\*" "~\.ssh\"
