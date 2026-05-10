#Requires -RunAsAdministrator

# When switching to this computer with a KVM, force Windows to always select the main user instead
# of "Other User" by disabling "Fast User Switching":
# https://www.elevenforum.com/t/enable-or-disable-fast-user-switching-in-windows-11.4620/
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "HideFastUserSwitching" /t REG_DWORD /d 1 /f

# Internet Options --> Security --> Local intranet --> Sites --> Advanced -->
# azuredevops.logixhealth.com --> Add
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains\logixhealth.com\azuredevops" /v https /t REG_DWORD /d 1 /f
