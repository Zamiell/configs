$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$notepadConfigPath = "$env:APPDATA\Notepad++\config.xml"

# View --> Show Symbol --> Show Space and Tab
(Get-Content $notepadConfigPath) -creplace 'whiteSpaceShow="hide"', 'whiteSpaceShow="show"' | Set-Content $notepadConfigPath
# View --> Word Wrap
(Get-Content $notepadConfigPath) -creplace ' Wrap="no"', ' Wrap="yes"' | Set-Content $notepadConfigPath
# Settings --> Preferences --> Margins/Border/Edge --> Uncheck "Display Change History"
(Get-Content $notepadConfigPath) -creplace 'isChangeHistoryEnabled="1"', 'isChangeHistoryEnabled="0"' | Set-Content $notepadConfigPath
# Settings --> Preferences --> New Document --> Format (Line ending) --> Unix (LF)
(Get-Content $notepadConfigPath) -creplace '(<GUIConfig name="NewDocDefaultSettings" format=")\d(")', '${1}2$2' | Set-Content $notepadConfigPath
