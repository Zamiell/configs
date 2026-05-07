#Requires -RunAsAdministrator

# When switching to this computer with a KVM, force Windows to always select the main user instead
# of "Other User" by disabling "Fast User Switching":
# https://www.elevenforum.com/t/enable-or-disable-fast-user-switching-in-windows-11.4620/
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "HideFastUserSwitching" /t REG_DWORD /d 1 /f

# Banish YubiKey from the login screen.
# https://learn.microsoft.com/en-us/answers/questions/1302097/how-to-configure-windows-10-to-show-only-smart-car
# TODO: Does this work?
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "ExcludedCredentialProviders" /t REG_SZ /d "{8FD7E19C-3BF7-489B-A72C-846AB3678C96}" /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v "ExcludedCredentialProviders" /t REG_SZ /d "{8FD7E19C-3BF7-489B-A72C-846AB3678C96}" /f

# Internet Options --> Security --> Local intranet --> Sites --> Advanced -->
# azuredevops.logixhealth.com --> Add
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains\logixhealth.com\azuredevops" /v https /t REG_DWORD /d 1 /f
