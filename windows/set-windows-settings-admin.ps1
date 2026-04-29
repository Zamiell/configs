#Requires -RunAsAdministrator

# ----------------------------
# Settings --> Personalization
# ----------------------------

# Settings --> Personalization --> Themes --> Desktop icon settings --> Uncheck "Recycle Bin"
# https://stackoverflow.com/questions/77420778/remove-recycle-bin-from-desktop-with-powershell
# - This requires elevation because the "Policies" subkey is protected.
# - This requires a restart of explorer to take effect.
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\NonEnum" /v "{645FF040-5081-101B-9F08-00AA002F954E}" /t REG_DWORD /d 1 /f

# Settings --> Personalization --> Taskbar --> Taskbar behaviors -->
# Uncheck "Show my taskbar on all displays"
# https://www.tenforums.com/tutorials/104832-enable-disable-show-taskbar-all-displays-windows-10-a.html
# - This requires elevation because the "Policies" subkey is protected.
reg add "HKCU\Software\Policies\Microsoft\Windows\Explorer" /v TaskbarNoMultimon /t REG_DWORD /d 1 /f

# ------------------------------
# Miscellaneous Windows Settings
# ------------------------------

# Right click "Recycle Bin" --> Properties --> Don't move files to the Recycle Bin. Remove files
# immediately when deleted.
# https://superuser.com/questions/1616394/how-to-use-registry-to-disable-recycle-bin-for-all-users-on-all-drives-and-disp
# - This requires elevation because the "Policies" subkey is protected.
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoRecycleFiles /t REG_DWORD /d 1 /f

# Right click "Recycle Bin" --> Properties --> Display delete confirmation dialog
# https://superuser.com/questions/1616394/how-to-use-registry-to-disable-recycle-bin-for-all-users-on-all-drives-and-disp
# - This requires elevation because the "Policies" subkey is protected.
# - This requires a restart of explorer to take effect.
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v ConfirmFileDelete /t REG_DWORD /d 1 /f
