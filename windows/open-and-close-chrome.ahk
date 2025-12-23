; Opening and closing Chrome is useful to create a default profile.
localAppData := EnvGet("LOCALAPPDATA")
Run(localAppData . "\Google\Chrome\Application\chrome.exe")
WinWait("ahk_exe chrome.exe")
WinClose("ahk_exe chrome.exe")
WinWaitClose("ahk_exe chrome.exe")
