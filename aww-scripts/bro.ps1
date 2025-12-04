param(
    [Parameter(ValueFromRemainingArguments = $true, Position = 0)]
    [string[]]$Args
)

$ErrorActionPreference = "Stop"

# -----------------------------------------------------------------------------
# User configurable settings
# -----------------------------------------------------------------------------

$script:EnableLogging       = $true

$script:BrowserWindowWidth  = 1100
$script:BrowserWindowHeight = 800

$script:BrowserWindowX      = 200
$script:BrowserWindowY      = 150

# Default home page when no query or url is given
$script:DefaultHomeUrl      = "https://www.bing.com/"

# Default search engine command for unknown input
# Valid values here: "bing", "ggl", "ddg"
$script:DefaultSearchEngine = "bing"

# -----------------------------------------------------------------------------
# Logging helpers
# -----------------------------------------------------------------------------

function Write-Log {
    param(
        [string]$Message
    )
    if (-not $script:EnableLogging) { return }
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "[bro $timestamp] $Message"
}

# -----------------------------------------------------------------------------
# URL and argument helpers
# -----------------------------------------------------------------------------

function Encode-UrlComponent {
    param(
        [string]$Value
    )

    if ($null -eq $Value -or $Value -eq "") { return "" }

    try {
        Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue | Out-Null
        if ([type]::GetType("System.Web.HttpUtility", $false, $true)) {
            return [System.Web.HttpUtility]::UrlEncode($Value)
        }
    } catch {
    }

    return [System.Uri]::EscapeDataString($Value)
}

function Build-SearchUrl {
    param(
        [string]$Command,
        [string]$Query
    )

    $q = $Query
    if ($null -eq $q) { $q = "" }

    $encoded = Encode-UrlComponent -Value $q

    switch ($Command.ToLower()) {
        "ggl" {
            if ([string]::IsNullOrWhiteSpace($q)) { return "https://www.google.com/" }
            return ("https://www.google.com/search?q={0}" -f $encoded)
        }
        "ddg" {
            if ([string]::IsNullOrWhiteSpace($q)) { return "https://duckduckgo.com/" }
            return ("https://duckduckgo.com/?q={0}" -f $encoded)
        }
        "bing" {
            if ([string]::IsNullOrWhiteSpace($q)) { return "https://www.bing.com/" }
            return ("https://www.bing.com/search?q={0}" -f $encoded)
        }
        "gpt" {
            if ([string]::IsNullOrWhiteSpace($q)) { return "https://chatgpt.com/" }
            return ("https://chatgpt.com/?q={0}" -f $encoded)
        }
        default {
            if ([string]::IsNullOrWhiteSpace($q)) { return $null }
            return $q
        }
    }
}

function Get-JoinedText {
    param(
        [string[]]$Items,
        [int]$StartIndex = 0
    )

    if (-not $Items) { return "" }
    if ($StartIndex -lt 0 -or $StartIndex -ge $Items.Count) { return "" }

    $slice = $Items[$StartIndex..($Items.Count - 1)]
    return ($slice -join " ").Trim()
}

function Quote-Argument {
    param(
        [string]$Arg
    )

    if ($null -eq $Arg -or $Arg -eq "") {
        return '""'
    }

    if ($Arg -match '\s|"') {
        $escaped = $Arg -replace '"', '\"'
        return '"' + $escaped + '"'
    }

    return $Arg
}

function Looks-LikeDomain {
    param(
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }

    $v = $Value.Trim()

    # If it starts with a scheme, treat as url
    if ($v -match '^[a-zA-Z][a-zA-Z0-9+\-.]*://') {
        return $true
    }

    # No spaces allowed for domain detection
    if ($v -match '\s') { return $false }

    # First char letter, must contain at least one dot
    if ($v -notmatch '^[A-Za-z][A-Za-z0-9\.-]*\.[A-Za-z0-9\-]+$') {
        return $false
    }

    return $true
}

# -----------------------------------------------------------------------------
# Registry and browser resolution helpers
# -----------------------------------------------------------------------------

function Get-ExecutablePathFromCommand {
    param(
        [string]$Command
    )

    Write-Log "Parsing executable path from command: $Command"

    $exe = $null
    if ($Command -match '^\s*"([^"]+)"') {
        $exe = $matches[1]
    } else {
        $exe = $Command.Split(" ")[0]
    }

    Write-Log "Parsed executable path: $exe"
    return $exe
}

function Get-DefaultBrowserExecutable {
    param()

    Write-Log "Resolving default browser executable from registry."

    $protocol = "https"
    $progId   = $null

    $userChoiceKey = "HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\$protocol\UserChoice"
    if (Test-Path $userChoiceKey) {
        try {
            $progId = (Get-ItemProperty -Path $userChoiceKey -Name ProgId -ErrorAction Stop).ProgId
            Write-Log "UserChoice ProgId: $progId"
        } catch {
            Write-Log ("Failed to read UserChoice ProgId: {0}" -f $_.Exception.Message)
        }
    }

    if (-not $progId) {
        Write-Log "UserChoice ProgId not found, falling back to HKEY_CLASSES_ROOT protocol association."

        try {
            $command = (Get-Item "Registry::HKEY_CLASSES_ROOT\$protocol\shell\open\command" -ErrorAction Stop).GetValue($null)
            if (-not $command) {
                throw "Empty command for protocol $protocol."
            }
            $exe = Get-ExecutablePathFromCommand -Command $command
            return $exe
        } catch {
            throw "Could not determine default browser command from HKEY_CLASSES_ROOT: $($_.Exception.Message)"
        }
    }

    $cmdKey = "HKCU:\Software\Classes\$progId\shell\open\command"
    if (-not (Test-Path $cmdKey)) {
        $cmdKey = "Registry::HKEY_CLASSES_ROOT\$progId\shell\open\command"
    }

    try {
        $command = (Get-ItemProperty -Path $cmdKey -Name "(default)" -ErrorAction Stop)."(default)"
        Write-Log "Default browser command from ProgId: $command"
    } catch {
        throw "Could not read default browser command for ProgId '$progId': $($_.Exception.Message)"
    }

    $exePath = Get-ExecutablePathFromCommand -Command $command
    return $exePath
}

function Get-BrowserKind {
    param(
        [string]$ExecutablePath
    )

    $lower = $ExecutablePath.ToLowerInvariant()
    Write-Log "Determining browser kind for path '$ExecutablePath'"

    if ($lower -like "*msedge.exe")   { return "edge" }
    if ($lower -like "*chrome.exe")   { return "chrome" }
    if ($lower -like "*firefox.exe")  { return "firefox" }

    return "unknown"
}

function Build-BrowserArgumentList {
    param(
        [string]$BrowserKind,
        [string]$Url,
        [bool]$IsPrivate
    )

    Write-Log "Building browser arguments. Kind='$BrowserKind' Url='$Url' Private=$IsPrivate"

    $list = New-Object System.Collections.Generic.List[string]

    switch ($BrowserKind.ToLowerInvariant()) {
        "chrome" {
            $list.Add("--new-window")
            if ($IsPrivate) { $list.Add("--incognito") }

            if ($script:BrowserWindowWidth -and $script:BrowserWindowHeight) {
                $list.Add("--window-size=$($script:BrowserWindowWidth),$($script:BrowserWindowHeight)")
            }

            if ($null -ne $script:BrowserWindowX -and $null -ne $script:BrowserWindowY) {
                $list.Add("--window-position=$($script:BrowserWindowX),$($script:BrowserWindowY)")
            }

            if ($Url) {
                $list.Add($Url)
            }
        }
        "edge" {
            $list.Add("--new-window")
            if ($IsPrivate) { $list.Add("--inprivate") }

            if ($script:BrowserWindowWidth -and $script:BrowserWindowHeight) {
                $list.Add("--window-size=$($script:BrowserWindowWidth),$($script:BrowserWindowHeight)")
            }

            if ($null -ne $script:BrowserWindowX -and $null -ne $script:BrowserWindowY) {
                $list.Add("--window-position=$($script:BrowserWindowX),$($script:BrowserWindowY)")
            }

            if ($Url) {
                $list.Add($Url)
            }
        }
        "firefox" {
            if ($IsPrivate) {
                $list.Add("-private-window")
            } else {
                $list.Add("-new-window")
            }

            if ($script:BrowserWindowWidth -and $script:BrowserWindowHeight) {
                $list.Add("-width")
                $list.Add("$($script:BrowserWindowWidth)")
                $list.Add("-height")
                $list.Add("$($script:BrowserWindowHeight)")
            }

            if ($Url) {
                $list.Add($Url)
            }
        }
        default {
            Write-Log "Browser kind '$BrowserKind' not explicitly supported for window sizing."
        }
    }

    if ($list.Count -eq 0) { return $null }

    return $list.ToArray()
}

# -----------------------------------------------------------------------------
# Browser invocation
# -----------------------------------------------------------------------------

function Open-BrowserWindow {
    param(
        [string]$Url,
        [bool]$IsPrivate
    )

    Write-Log "Preparing to open browser. Url='$Url' Private=$IsPrivate"

    $browserExe = $null
    try {
        $browserExe = Get-DefaultBrowserExecutable
    } catch {
        Write-Log ("Failed to resolve default browser executable: {0}" -f $_.Exception.Message)
    }

    $targetUrl =
        if ([string]::IsNullOrWhiteSpace($Url)) {
            $script:DefaultHomeUrl
        } else {
            $Url
        }

    if (-not $browserExe -or -not (Test-Path $browserExe)) {
        Write-Log "Browser executable not found, falling back to Start-Process with URL only."
        Write-Log "Fallback URL: $targetUrl"
        Start-Process $targetUrl | Out-Null
        return
    }

    $kind = Get-BrowserKind -ExecutablePath $browserExe
    Write-Log "Browser kind detected: $kind"

    $argArray = Build-BrowserArgumentList -BrowserKind $kind -Url $targetUrl -IsPrivate:$IsPrivate
    if (-not $argArray) {
        Write-Log "No specific arguments built; starting browser executable directly."
        $displayArg = Quote-Argument $targetUrl
        Write-Log ("Executing: `"{0}`" {1}" -f $browserExe, $displayArg)
        Start-Process -FilePath $browserExe -ArgumentList @($targetUrl) | Out-Null
        return
    }

    $displayArgs = $argArray | ForEach-Object { Quote-Argument $_ }
    Write-Log ("Executing: `"{0}`" {1}" -f $browserExe, ($displayArgs -join " "))
    Start-Process -FilePath $browserExe -ArgumentList $argArray | Out-Null
}

# -----------------------------------------------------------------------------
# Help
# -----------------------------------------------------------------------------

function Write-Help {
    param()

    $help = @"
bro.ps1 - disposable browser window helper

Usage:
  bro
    Open a new browser window using the default browser and show this help.

  bro help
    Show this help text only.

  bro [text...]
    If text looks like a single domain, open it directly.
    Otherwise open the default search engine with the text as query.

Special commands:
  bro gpt  <query>
    Open ChatGPT with the query in the q parameter.

  bro ggl  <query>
    Open Google search with the query.

  bro ddg  <query>
    Open DuckDuckGo search with the query.

  bro bing <query>
    Open Bing search with the query.

  bro p
    Open a private window with no URL (blank or home).

  bro p <command...>
    Same as above commands, but using private mode when supported by the browser.

Examples:
  bro example
    Open Bing search for "example".

  bro example.com
    Open example.com directly.

  bro where are my socks
    Open Bing search for "where are my socks".
"@

    Write-Host $help
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

Write-Log ("bro.ps1 started with raw arguments: '{0}'." -f ($Args -join " "))

if (-not $Args -or $Args.Count -eq 0) {
    Write-Help
    Open-BrowserWindow -Url $null -IsPrivate:$false
    Write-Log "No arguments supplied; opened default window and printed help."
    exit 0
}

$isPrivate = $false
$index = 0

if ($Args.Count -gt 0 -and $Args[0]) {
    $first = $Args[0].ToLower()
    if ($first -eq "p" -or $first -eq "private") {
        $isPrivate = $true
        $index = 1
    }
}

if ($Args.Count -le $index) {
    Open-BrowserWindow -Url $null -IsPrivate:$isPrivate
    Write-Log "Only private flag provided; opened home private window."
    exit 0
}

$command      = $Args[$index]
$commandLower = $command.ToLower()
Write-Log "Primary command token: '$commandLower'. Private=$isPrivate"

if ($commandLower -eq "help") {
    Write-Help
    Write-Log "Help requested; exiting without opening browser."
    exit 0
}

if ($commandLower -in @("gpt", "ggl", "ddg", "bing")) {
    $query = Get-JoinedText -Items $Args -StartIndex ($index + 1)
    Write-Log "Handling known command '$commandLower' with query '$query'."
    $url = Build-SearchUrl -Command $commandLower -Query $query
    Open-BrowserWindow -Url $url -IsPrivate:$isPrivate
    Write-Log "Opened browser for command '$commandLower'."
    exit 0
}

$remaining = $Args[$index..($Args.Count - 1)]
Write-Log ("Unknown primary command; remaining tokens: '{0}'." -f ($remaining -join " "))

if ($remaining.Count -eq 1) {
    $token = $remaining[0]
    if (Looks-LikeDomain $token) {
        Write-Log "Single unknown token looks like domain; opening directly."
        Open-BrowserWindow -Url $token -IsPrivate:$isPrivate
        Write-Log "Opened browser with domain-like token."
        exit 0
    }

    Write-Log "Single unknown token; using default search engine '$script:DefaultSearchEngine'."
    $url = Build-SearchUrl -Command $script:DefaultSearchEngine -Query $token
    Open-BrowserWindow -Url $url -IsPrivate:$isPrivate
    Write-Log "Opened browser with default search for single token."
    exit 0
}

$queryText = ($remaining -join " ")
Write-Log "Multiple tokens with unknown command; using default search engine '$script:DefaultSearchEngine' with query '$queryText'."
$searchUrl = Build-SearchUrl -Command $script:DefaultSearchEngine -Query $queryText
Open-BrowserWindow -Url $searchUrl -IsPrivate:$isPrivate
Write-Log "Opened browser with default search for multi word query."
