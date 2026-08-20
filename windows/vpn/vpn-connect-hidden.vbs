Option Explicit

Dim command
Dim fileSystem
Dim hiddenWindow
Dim powerShell
Dim scriptDirectory
Dim shell
Dim vpnScript

Set fileSystem = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")

scriptDirectory = fileSystem.GetParentFolderName(WScript.ScriptFullName)
powerShell = shell.ExpandEnvironmentStrings("%SystemRoot%") & _
    "\System32\WindowsPowerShell\v1.0\powershell.exe"
vpnScript = fileSystem.BuildPath(scriptDirectory, "vpn-connect.ps1")
hiddenWindow = 0

command = Quote(powerShell) & _
    " -NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File " & _
    Quote(vpnScript)

WScript.Quit shell.Run(command, hiddenWindow, True)

Function Quote(value)
    Quote = Chr(34) & value & Chr(34)
End Function
