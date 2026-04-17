; List of characters that need to be escaped (e.g., "{!}"):
;   !#^
; List of characters that need to be special escaped (e.g., "{`%}"):
;   %

; --------
; SETTINGS
; --------

#Warn ; Enable all warnings.
SetKeyDelay(-1) ; No delay
SetWinDelay(-1) ; No delay

; ------------
; CORE HOTKEYS
; ------------

^+!r::Reload
#SuspendExempt True
^+!s::Suspend
#SuspendExempt False

; Emulate the "Fn" key (since it does not work properly on Ducky keyboards).
RCtrl & RWin::{
  Send("+{F10}")
}

^+!n::{
  Send("Hello! Please read the following link: https://nohello.net/en/{Enter}")
}

; -------------
; CYCLE HOTKEYS
; -------------

; Cycle program windows forward.
; (This requires Snap Assist to be disabled.)
#Tab::{
  activeProcessName := WinGetProcessName("A")
  windowIDs := WinGetList("ahk_exe " activeProcessName)

  if (windowIDs.Length <= 1) {
    return
  }

  sortedWindowIDs := SortNumArray(windowIDs)
  activeWindowID := WinGetID("A")
  activeWindowIndex := 0

  for index, windowID in sortedWindowIDs
  {
    if (windowID = activeWindowID)
    {
      activeWindowIndex := index
      break
    }
  }

  if (activeWindowIndex = 0)
  {
    return
  }

  nextWindowIndex := activeWindowIndex + 1
  if (nextWindowIndex > sortedWindowIDs.Length)
  {
    nextWindowIndex := 1
  }

  nextWindowID := sortedWindowIDs[nextWindowIndex]
  WinActivate("ahk_id " nextWindowID)
}

; Cycle program windows backward.
; (This requires Snap Assist to be disabled.)
#+Tab::{
  activeProcessName := WinGetProcessName("A")
  windowIDs := WinGetList("ahk_exe " activeProcessName)

  if (windowIDs.Length <= 1) {
    return
  }

  sortedWindowIDs := SortNumArray(windowIDs)
  activeWindowID := WinGetID("A")
  activeWindowIndex := 0

  for index, windowID in sortedWindowIDs
  {
    if (windowID = activeWindowID)
    {
      activeWindowIndex := index
      break
    }
  }

  if (activeWindowIndex = 0)
  {
    return
  }

  previousWindowIndex := activeWindowIndex - 1
  if (previousWindowIndex < 1)
  {
    previousWindowIndex := sortedWindowIDs.Length
  }

  previousWindowID := sortedWindowIDs[previousWindowIndex]
  WinActivate("ahk_id " previousWindowID)
}

; From: https://www.autohotkey.com/boards/viewtopic.php?t=113911
SortNumArray(arr) {
  str := ""
  for k, v in arr {
    str .= v "`n"
  }
  str := Sort(RTrim(str, "`n"), "N")
  return StrSplit(str, "`n")
}

; --------------------
; OPEN PROGRAM HOTKEYS
; --------------------

^`::{
  if (WinExist("ahk_exe msedge.exe")) {
    edgeWindows := WinGetList("ahk_exe msedge.exe")

    for window in edgeWindows {
      title := WinGetTitle(window)
      if (!InStr(title, "Bitwarden")) {
        WinActivate(window)
        return
      }
    }

    WinActivate("ahk_exe msedge.exe")
  } else {
    Run("C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe")
  }
}

^+`::{
  if (WinExist("ahk_exe VSCodium.exe")) {
    WinActivate "ahk_exe VSCodium.exe"
  } else {
    Run("C:\Users\jnesta\AppData\Local\Programs\VSCodium\VSCodium.exe")
  }
}

^+!`::{
  if (WinExist("ahk_exe firefox.exe")) {
    WinActivate("ahk_exe firefox.exe")
  } else {
    Run("C:\Program Files\Mozilla Firefox\firefox.exe")
  }
}

^1::{
  if (WinExist("ahk_exe explorer.exe ahk_class CabinetWClass")) {
    WinActivate("ahk_exe explorer.exe ahk_class CabinetWClass")
  }
}

^2::{
  if (WinExist("ahk_exe cmd.exe")) {
    WinActivate("ahk_exe cmd.exe")
  }
}

^3::{
  if (WinExist("ahk_exe RemoteDesktopManager.exe")) {
    WinActivate("ahk_exe RemoteDesktopManager.exe")
  } else {
    ; Hitting the hotkey by accident causes lag, so disable this.
    ; Run("C:\Program Files\Devolutions\Remote Desktop Manager\RemoteDesktopManager.exe")
  }
}

^4::{
  if (WinExist("ahk_exe kitty_portable.exe")) {
    WinActivate("ahk_exe kitty_portable.exe")
  } else {
    Run("C:\Users\jnesta\OneDrive - LogixHealth Inc\Documents\KiTTY\kitty_portable.exe")
  }
}

^5::{
  ; "wt.exe" is not the real process name:
  ; https://stackoverflow.com/a/68006153/26408392
  if (WinExist("ahk_exe WindowsTerminal.exe")) {
    WinActivate("ahk_exe WindowsTerminal.exe")
  } else {
    Run(A_AppData . "\..\Local\Microsoft\WindowsApps\wt.exe")
  }
}

^+5::{
  Run(A_AppData . "\..\Local\Microsoft\WindowsApps\wt.exe")
}

^6::{
  if (WinExist("ahk_exe Code.exe")) {
    WinActivate("ahk_exe Code.exe")
  } else {
    Run(A_AppData . "\..\Local\Programs\Microsoft VS Code\Code.exe")
  }
}

^7::{
  if (WinExist("Bitwarden ahk_exe msedge.exe")) {
    WinActivate("Bitwarden ahk_exe msedge.exe")
  }
}

^8::{
  if (WinExist("ahk_exe ms-teams.exe")) {
    WinActivate "ahk_exe ms-teams.exe"
  } else {
    Run(A_AppData . "\..\Local\Microsoft\WindowsApps\MSTeams_8wekyb3d8bbwe\ms-teams.exe") ; cspell:disable-line
  }
}

^9::{
  if (WinExist("ahk_exe chrome.exe")) {
    WinActivate("ahk_exe chrome.exe")
  } else {
    Run("C:\Program Files\Google\Chrome\Application\chrome.exe")
  }
}

^0::{
  if (WinExist("ahk_exe olk.exe")) {
    WinActivate "ahk_exe olk.exe"
  } else {
    ; Does not work.
    ;Run("C:\Program Files\WindowsApps\Microsoft.OutlookForWindows_1.2024.619.100_x64__8wekyb3d8bbwe\olk.exe") ; cspell:disable-line
  }
}

^+k::Run("C:\Users\jnesta\OneDrive - LogixHealth Inc\Documents\KiTTY\kitty_portable.exe")
^+s::Run(A_AppData . "\..\Local\Programs\WinSCP\WinSCP.exe")

; -------
; TESTING
; -------

#z::{
  MsgBox("LOL")
  ; TODO
}
