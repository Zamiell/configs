#Requires -RunAsAdministrator

# When switching to this computer with a KVM, force Windows to always select the main user instead
# of "Other User" by disabling "Fast User Switching":
# https://www.elevenforum.com/t/enable-or-disable-fast-user-switching-in-windows-11.4620/
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "HideFastUserSwitching" /t REG_DWORD /d 1 /f

# Pin the default credential provider to be Windows Hello (to stop it from trying to use a YubiKey).
# The magic string is the GUID for the Windows Hello PIN.
# https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-admx-credentialproviders#defaultcredentialprovider
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v "DefaultCredentialProvider" /t REG_SZ /d "{D6886603-9D2F-4EB2-B667-1971041FA96B}" /f
