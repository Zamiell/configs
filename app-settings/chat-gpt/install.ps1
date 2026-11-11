param(
    [string] $SoundPath = (Join-Path $env:USERPROFILE 'turn-blind1.mp3'),
    [string] $ConfigDirectory = $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' })
)

$ErrorActionPreference = 'Stop'
$ffplayPath = (Get-Command ffplay.exe -ErrorAction Stop).Source
$codexPath = (Get-Command codex.exe -ErrorAction Stop).Source
if (-not (Test-Path -LiteralPath $SoundPath -PathType Leaf)) {
    throw "The sound file does not exist: $SoundPath"
}
$SoundPath = (Resolve-Path -LiteralPath $SoundPath).Path
$ConfigDirectory = [IO.Path]::GetFullPath($ConfigDirectory)
[IO.Directory]::CreateDirectory($ConfigDirectory) | Out-Null
$scriptPath = Join-Path $ConfigDirectory 'notify-sound.ps1'
$hooksPath = Join-Path $ConfigDirectory 'hooks.json'
$configPath = Join-Path $ConfigDirectory 'config.toml'
$encoding = New-Object Text.UTF8Encoding($false)

function Write-ChangedFile([string] $Path, [string] $Content) {
    if (Test-Path -LiteralPath $Path) {
        if ([IO.File]::ReadAllText($Path) -ceq $Content) {
            Write-Host "Already up to date: $Path"
            return
        }
        Copy-Item -LiteralPath $Path -Destination "$Path.before-sound-install.bak" -Force
    }
    [IO.File]::WriteAllText($Path, $Content, $encoding)
    Write-Host "Updated: $Path"
}

$script = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'hooks/notify-sound.ps1'))
$script = $script.Replace('__FFPLAY_PATH__', $ffplayPath.Replace("'", "''"))
$script = $script.Replace('__MP3_PATH__', $SoundPath.Replace("'", "''"))
$handler = Get-Content -Raw (Join-Path $PSScriptRoot 'hooks/sound.json') | ConvertFrom-Json
$handler.command = $handler.command.Replace('__SCRIPT_PATH__', $scriptPath.Replace('\', '/'))
$document = if (Test-Path -LiteralPath $hooksPath) {
    Get-Content -Raw -LiteralPath $hooksPath | ConvertFrom-Json
} else {
    [pscustomobject]@{ hooks = [pscustomobject]@{} }
}
if (-not $document.hooks) {
    $document | Add-Member -NotePropertyName hooks -NotePropertyValue ([pscustomobject]@{}) -Force
}
$groups = @($document.hooks.Stop | Where-Object { $null -ne $_ })
$matches = @($groups | ForEach-Object { $_.hooks } | Where-Object { $_.command -like '*notify-sound.ps1*' })
if ($matches.Count -gt 1) { throw 'Multiple sound hooks found. Remove duplicates before installing.' }
if ($matches.Count -eq 1) {
    $matches[0].command = $handler.command
    $matches[0] | Add-Member -NotePropertyName timeout -NotePropertyValue $handler.timeout -Force
} else {
    $groups += [pscustomobject]@{ hooks = @($handler) }
}
$document.hooks | Add-Member -NotePropertyName Stop -NotePropertyValue $groups -Force
Write-ChangedFile $scriptPath $script
Write-ChangedFile $hooksPath (($document | ConvertTo-Json -Depth 100) + "`n")

$startInfo = New-Object Diagnostics.ProcessStartInfo
$startInfo.FileName = $codexPath
$startInfo.Arguments = 'app-server'
$startInfo.WorkingDirectory = $ConfigDirectory
$startInfo.UseShellExecute = $false
$startInfo.CreateNoWindow = $true
$startInfo.RedirectStandardInput = $true
$startInfo.RedirectStandardOutput = $true
$startInfo.RedirectStandardError = $true
$startInfo.EnvironmentVariables['CODEX_HOME'] = $ConfigDirectory
$server = [Diagnostics.Process]::Start($startInfo)
$stderr = $server.StandardError.ReadToEndAsync()

function Invoke-Request([int] $Id, [string] $Method, $Parameters) {
    $request = @{ id = $Id; method = $Method; params = $Parameters } | ConvertTo-Json -Depth 100 -Compress
    $server.StandardInput.WriteLine($request)
    $server.StandardInput.Flush()
    do {
        $line = $server.StandardOutput.ReadLineAsync()
        if (-not $line.Wait(15000)) { throw "Timed out calling $Method" }
        if ($null -eq $line.Result) { throw "Server exited while calling $Method" }
        $response = $line.Result | ConvertFrom-Json
    } while ($response.id -ne $Id)
    if ($response.error) { throw ($response.error | ConvertTo-Json -Compress) }
    return $response.result
}

try {
    Invoke-Request 1 'initialize' @{ clientInfo = @{ name = 'sound_installer'; version = '1.0' }; capabilities = @{ experimentalApi = $true } } | Out-Null
    $listing = Invoke-Request 2 'hooks/list' @{ cwds = @($ConfigDirectory) }
    $hook = @($listing.data.hooks | Where-Object { $_.sourcePath -eq $hooksPath -and $_.command -eq $handler.command })
    if ($hook.Count -ne 1) { throw 'The installed sound hook was not recognized by Codex.' }
    if ($hook[0].trustStatus -ne 'trusted' -or -not $hook[0].enabled) {
        if (Test-Path -LiteralPath $configPath) {
            Copy-Item -LiteralPath $configPath -Destination "$configPath.before-sound-install.bak" -Force
        }
        $state = @{}
        $state[$hook[0].key] = @{ enabled = $true; trusted_hash = $hook[0].currentHash }
        Invoke-Request 3 'config/batchWrite' @{ edits = @(@{ keyPath = 'hooks.state'; value = $state; mergeStrategy = 'upsert' }); reloadUserConfig = $true } | Out-Null
    }
    $verified = Invoke-Request 4 'hooks/list' @{ cwds = @($ConfigDirectory) }
    $active = @($verified.data.hooks | Where-Object { $_.key -eq $hook[0].key -and $_.enabled -and $_.trustStatus -eq 'trusted' })
    if ($active.Count -ne 1) { throw 'The sound hook is not enabled and trusted.' }
    Write-Host 'Sound hook installed, enabled, and trusted. Restart the ChatGPT desktop app.'
} finally {
    if (-not $server.HasExited) { $server.Kill() }
    $server.Dispose()
}
