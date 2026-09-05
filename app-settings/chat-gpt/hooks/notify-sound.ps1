try {
    $notification = [Console]::In.ReadToEnd() | ConvertFrom-Json -ErrorAction Stop
} catch {
    [Console]::Error.WriteLine('Sound hook received invalid JSON.')
    exit 1
}

if ($notification.hook_event_name -ne 'Stop') {
    Write-Output '{}'
    exit 0
}

$ffplayPath = '__FFPLAY_PATH__'
$soundPath = '__MP3_PATH__'

& $ffplayPath -nodisp -autoexit -loglevel error $soundPath
if ($LASTEXITCODE -ne 0) {
    [Console]::Error.WriteLine("Notification playback failed: $LASTEXITCODE")
    exit 1
}

Write-Output '{}'
exit 0
