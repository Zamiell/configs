; Opening and closing Chrome is useful to create a default profile.
localAppData := EnvGet("LOCALAPPDATA")
Run(localAppData . "\Google\Chrome\Application\chrome.exe")
WinWait("ahk_class Chrome_WidgetWin_1 ahk_exe chrome.exe")
WinClose("ahk_class Chrome_WidgetWin_1 ahk_exe chrome.exe")
WinWaitClose("ahk_class Chrome_WidgetWin_1 ahk_exe chrome.exe")
