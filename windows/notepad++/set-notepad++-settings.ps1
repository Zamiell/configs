param(
    [Parameter(Mandatory)]
    [string]$NotepadConfigPath
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# View --> Show Symbol --> Show Space and Tab
(Get-Content $NotepadConfigPath) -creplace 'whiteSpaceShow="hide"', 'whiteSpaceShow="show"' | Set-Content $NotepadConfigPath
# View --> Word Wrap
(Get-Content $NotepadConfigPath) -creplace ' Wrap="no"', ' Wrap="yes"' | Set-Content $NotepadConfigPath
# Settings --> Preferences --> Margins/Border/Edge --> Uncheck "Display Change History"
(Get-Content $NotepadConfigPath) -creplace 'isChangeHistoryEnabled="1"', 'isChangeHistoryEnabled="0"' | Set-Content $NotepadConfigPath
# Settings --> Preferences --> New Document --> Format (Line ending) --> Unix (LF)
(Get-Content $NotepadConfigPath) -creplace '(<GUIConfig name="NewDocDefaultSettings" format=")\d(")', '${1}2$2' | Set-Content $NotepadConfigPath
