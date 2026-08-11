param(
    [Parameter(Mandatory = $true)]
    [int]$Port,

    [Parameter(Mandatory = $true)]
    [string]$TargetHost,

    [Parameter(Mandatory = $true)]
    [string]$PreferredAccount,

    [int]$TimeoutSeconds = 300
)

$ErrorActionPreference = "Stop"
$deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
$requestId = 1
$accountSelectionAttempted = $false
$ambiguousAccountWarningShown = $false
$preferredAccountJson = $PreferredAccount | ConvertTo-Json -Compress
$selectAccountExpression = @"
(() => {
    const normalize = value => value.replace(/\s+/g, " ").trim().toLowerCase();
    const wanted = normalize($preferredAccountJson);
    const matchingElements = [...document.querySelectorAll("body *")]
        .filter(element =>
            element.getClientRects().length > 0 &&
            normalize(element.textContent || "") === wanted
        );
    const clickTargets = [...new Set(matchingElements.map(element =>
        element.closest('button, a, [role="button"], [role="option"], [tabindex], [data-test-id]') ||
        element
    ))];

    if (clickTargets.length !== 1) {
        return clickTargets.length === 0 ? "not-found" : "ambiguous";
    }

    clickTargets[0].click();
    return "clicked";
})()
"@

function Invoke-CdpExpression {
    param(
        [Parameter(Mandatory = $true)]
        [string]$WebSocketUrl,

        [Parameter(Mandatory = $true)]
        [string]$Expression
    )

    $socket = [System.Net.WebSockets.ClientWebSocket]::new()
    $cancellation = [System.Threading.CancellationTokenSource]::new(10 * 1000)

    try {
        $socket.ConnectAsync([Uri]$WebSocketUrl, $cancellation.Token).GetAwaiter().GetResult()

        $request = @{
            id = $script:requestId
            method = "Runtime.evaluate"
            params = @{
                expression = $Expression
                returnByValue = $true
            }
        } | ConvertTo-Json -Compress -Depth 4

        $requestBytes = [Text.Encoding]::UTF8.GetBytes($request)
        $socket.SendAsync(
            [ArraySegment[byte]]::new($requestBytes),
            [System.Net.WebSockets.WebSocketMessageType]::Text,
            $true,
            $cancellation.Token
        ).GetAwaiter().GetResult()

        while ($true) {
            $stream = [IO.MemoryStream]::new()
            do {
                $buffer = [byte[]]::new(16384)
                $result = $socket.ReceiveAsync(
                    [ArraySegment[byte]]::new($buffer),
                    $cancellation.Token
                ).GetAwaiter().GetResult()
                $stream.Write($buffer, 0, $result.Count)
            } while (-not $result.EndOfMessage)

            $response = [Text.Encoding]::UTF8.GetString($stream.ToArray()) | ConvertFrom-Json
            if ($response.id -eq $script:requestId) {
                $script:requestId++
                return $response.result.result.value
            }
        }
    }
    finally {
        $socket.Dispose()
        $cancellation.Dispose()
    }
}

while ([DateTime]::UtcNow -lt $deadline) {
    try {
        $targets = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/json/list" -TimeoutSec 2
        foreach ($target in $targets) {
            if ($target.type -ne "page") {
                continue
            }

            $targetUri = [Uri]$target.url
            if (
                -not $accountSelectionAttempted -and
                $targetUri.Host -eq "login.microsoftonline.com"
            ) {
                $selectionResult = Invoke-CdpExpression `
                    -WebSocketUrl $target.webSocketDebuggerUrl `
                    -Expression $selectAccountExpression
                if ($selectionResult -eq "clicked") {
                    $accountSelectionAttempted = $true
                }
                elseif (
                    $selectionResult -eq "ambiguous" -and
                    -not $ambiguousAccountWarningShown
                ) {
                    [Console]::Error.WriteLine(
                        "Multiple matching account controls were found; select the VPN account manually."
                    )
                    $ambiguousAccountWarningShown = $true
                }
            }

            if ($targetUri.Host -ne $TargetHost) {
                continue
            }

            $html = Invoke-CdpExpression `
                -WebSocketUrl $target.webSocketDebuggerUrl `
                -Expression "document.documentElement.outerHTML"
            $cookieMatch = [regex]::Match(
                $html,
                "<prelogin-cookie>([^<]+)</prelogin-cookie>"
            )
            if ($cookieMatch.Success) {
                try {
                    Invoke-RestMethod `
                        -Uri "http://127.0.0.1:$Port/json/close/$($target.id)" `
                        -TimeoutSec 2 | Out-Null
                }
                catch {
                    # Capturing succeeded even if Edge closed the target first.
                }
                Write-Output $cookieMatch.Groups[1].Value
                exit 0
            }
        }
    }
    catch {
        # Edge may not be listening yet, or the page may be navigating.
    }

    Start-Sleep -Milliseconds 500
}

Write-Error "Timed out waiting for the GlobalProtect SAML success page."
exit 1
