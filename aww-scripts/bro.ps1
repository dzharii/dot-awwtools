param(
    [Parameter(ValueFromRemainingArguments = $true, Position = 0)]
    [string[]]$Args
)

$ErrorActionPreference = "Stop"

# -----------------------------------------------------------------------------
# User configurable settings
# -----------------------------------------------------------------------------

# Enable or disable console logging for debugging.
$script:EnableLogging = $true

# Preferred window size in pixels.
$script:BrowserWindowWidth  = 1100
$script:BrowserWindowHeight = 800

# Preferred window position in pixels (top left corner).
# Set to $null to let the browser decide.
$script:BrowserWindowX = 200
$script:BrowserWindowY = 150

# Use "app" mode for Chromium based browsers (Chrome, Edge) when opening URLs.
# This gives a minimal window without standard browser UI.
$script:UseAppMode = $true

# -----------------------------------------------------------------------------
# Logging helpers
# -----------------------------------------------------------------------------

function Write-Log {
    param(
        [string]$Message
    )

    # Write a simple timestamped log line when logging is enabled.
    if (-not $script:EnableLogging) {
        return
    }

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

    # Encode a string for safe use as a URL query parameter.
    if ($null -eq $Value -or $Value -eq "") {
        return ""
    }

    try {
        Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue | Out-Null
        if ([type]::GetType("System.Web.HttpUtility", $false, $true)) {
            return [System.Web.HttpUtility]::UrlEncode($Value)
        }
    } catch {
        # Ignore and fall back to EscapeDataString.
    }

    return [System.Uri]::EscapeDataString($Value)
}

function Build-SearchUrl {
    param(
        [string]$Command,
        [string]$Query
    )

    # Build a search URL based on a known command and query text.
    $q = $Query
    if ($null -eq $q) {
        $q = ""
    }

    $encoded = Encode-UrlComponent -Value $q

    switch ($Command.ToLower()) {
        "ggl" {
            if ([string]::IsNullOrWhiteSpace($q)) {
                return "https://www.google.com/"
            }
            return ("https://www.google.com/search?q={0}" -f $encoded)
        }
        "ddg" {
            if ([string]::IsNullOrWhiteSpace($q)) {
                return "https://duckduckgo.com/"
            }
            return ("https://duckduckgo.com/?q={0}" -f $encoded)
        }
        "bing" {
            if ([string]::IsNullOrWhiteSpace($q)) {
                return "https://www.bing.com/"
            }
            return ("https://www.bing.com/search?q={0}" -f $encoded)
        }
        "gpt" {
            if ([string]::IsNullOrWhiteSpace($q)) {
                return "https://chatgpt.com/"
            }
            return ("https://chatgpt.com/?q={0}" -f $encoded)
        }
        default {
            if ([string]::IsNullOrWhiteSpace($q)) {
                return $null
            }
            return $q
        }
    }
}

function Get-JoinedText {
    param(
        [string[]]$Items,
        [int]$StartIndex = 0
    )

    # Join items from StartIndex into a single space separated string.
    if (-not $Items) {
        return ""
    }

    if ($StartIndex -lt 0 -or $StartIndex -ge $Items.Count) {
        return ""
    }

    $slice = $Items[$StartIndex..($Items.Count - 1)]
    return ($slice -join " ").Trim()
}

# -----------------------------------------------------------------------------
# Registry and browser resolution helpers
# -----------------------------------------------------------------------------

function Get-ExecutablePathFromCommand {
    param(
        [string]$Command
    )

    # Extract executable path from a shell command string.
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

    # Resolve the default browser executable using Windows registry.
    Write-Log "Resolving default browser executable from registry."

    $protocol = "https"
    $progId = $null

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
        Write-Log "UserChoice ProgId not found, falling back to HKCR association."

        try {
            $command = (Get-Item "HKCR:\$protocol\shell\open\command" -ErrorAction Stop).GetValue($null)
            if (-not $command) {
                throw "Empty command for protocol $protocol."
            }
            $exe = Get-ExecutablePathFromCommand -Command $command
            return $exe
        } catch {
            throw "Could not determine default browser command from HKCR: $($_.Exception.Message)"
        }
    }

    $cmdKey = "HKCU:\Software\Classes\$progId\shell\open\command"
    if (-not (Test-Path $cmdKey)) {
        $cmdKey = "HKCR:\$progId\shell\open\command"
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

    # Determine browser family based on executable filename.
    $lower = $ExecutablePath.ToLowerInvariant()
    Write-Log "Determining browser kind for path '$ExecutablePath'"

    if ($lower -like "*msedge.exe") {
        return "edge"
    }
    if ($lower -like "*chrome.exe") {
        return "chrome"
    }
    if ($lower -like "*firefox.exe") {
        return "firefox"
    }

    return "unknown"
}

function Build-BrowserArguments {
    param(
        [string]$BrowserKind,
        [string]$Url,
        [bool]$IsPrivate
    )

    # Build command line arguments for known browser families.
    Write-Log "Building browser arguments. Kind='$BrowserKind' Url='$Url' Private=$IsPrivate"

    $args = New-Object System.Collections.Generic.List[string]

    switch ($BrowserKind.ToLowerInvariant()) {
        "chrome" {
            $args.Add("--new-window")
            if ($IsPrivate) {
                $args.Add("--incognito")
            }

            if ($script:BrowserWindowWidth -and $script:BrowserWindowHeight) {
                $args.Add("--window-size=$($script:BrowserWindowWidth),$($script:BrowserWindowHeight)")
            }

            if ($null -ne $script:BrowserWindowX -and $null -ne $script:BrowserWindowY) {
                $args.Add("--window-position=$($script:BrowserWindowX),$($script:BrowserWindowY)")
            }

            if ($Url) {
                if ($script:UseAppMode) {
                    $args.Add("--app=""$Url""")
                } else {
                    $args.Add($Url)
                }
            }
        }
        "edge" {
            $args.Add("--new-window")
            if ($IsPrivate) {
                $args.Add("--inprivate")
            }

            if ($script:BrowserWindowWidth -and $script:BrowserWindowHeight) {
                $args.Add("--window-size=$($script:BrowserWindowWidth),$($script:BrowserWindowHeight)")
            }

            if ($null -ne $script:BrowserWindowX -and $null -ne $script:BrowserWindowY) {
                $args.Add("--window-position=$($script:BrowserWindowX),$($script:BrowserWindowY)")
            }

            if ($Url) {
                if ($script:UseAppMode) {
                    $args.Add("--app=""$Url""")
                } else {
                    $args.Add($Url)
                }
            }
        }
        "firefox" {
            if ($IsPrivate) {
                $args.Add("-private-window")
            } else {
                $args.Add("-new-window")
            }

            if ($script:BrowserWindowWidth -and $script:BrowserWindowHeight) {
                $args.Add("-width")
                $args.Add("$($script:BrowserWindowWidth)")
                $args.Add("-height")
                $args.Add("$($script:BrowserWindowHeight)")
            }

            if ($Url) {
                $args.Add($Url)
            }
        }
        default {
            Write-Log "Browser kind '$BrowserKind' not explicitly supported for window sizing."
        }
    }

    if ($args.Count -eq 0) {
        return $null
    }

    return $args.ToArray()
}

# -----------------------------------------------------------------------------
# Browser invocation
# -----------------------------------------------------------------------------

function Open-BrowserWindow {
    param(
        [string]$Url,
        [bool]$IsPrivate
    )

    # Open a new browser window with optional URL and private mode.
    Write-Log "Preparing to open browser. Url='$Url' Private=$IsPrivate"

    $browserExe = $null
    try {
        $browserExe = Get-DefaultBrowserExecutable
    } catch {
        Write-Log ("Failed to resolve default browser executable: {0}" -f $_.Exception.Message)
    }

    if (-not $browserExe -or -not (Test-Path $browserExe)) {
        Write-Log "Browser executable not found, falling back to Start-Process with URL only."
        if ($Url) {
            Start-Process $Url | Out-Null
        } else {
            Start-Process "about:blank" | Out-Null
        }
        return
    }

    $kind = Get-BrowserKind -ExecutablePath $browserExe
    Write-Log "Browser kind detected: $kind"

    $args = Build-BrowserArguments -BrowserKind $kind -Url $Url -IsPrivate:$IsPrivate
    if (-not $args) {
        Write-Log "No specific arguments built; starting browser with URL only."
        if ($Url) {
            Write-Log ("Executing: `"{0}`" {1}" -f $browserExe, $Url)
            Start-Process -FilePath $browserExe -ArgumentList $Url | Out-Null
        } else {
            Write-Log ("Executing: `"{0}`"" -f $browserExe)
            Start-Process -FilePath $browserExe | Out-Null
        }
        return
    }

    Write-Log ("Executing: `"{0}`" {1}" -f $browserExe, ($args -join " "))
    Start-Process -FilePath $browserExe -ArgumentList $args | Out-Null
}

# -----------------------------------------------------------------------------
# Help
# -----------------------------------------------------------------------------

function Write-Help {
    param()

    # Print usage information for bro.ps1.
    $help = @"
bro.ps1 - disposable browser window helper

Usage:
  bro
    Open a new browser window using the default browser and show this help.

  bro help
    Show this help text only.

  bro [text...]
    Open a new window and pass the joined text to the browser. The browser will
    interpret it as a URL or a search string.

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
  bro example.com
  bro where are my socks
  bro ggl PowerShell Start-Process
  bro gpt this is my question
  bro p ggl disposable browser window
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
    Write-Log "Only private flag provided; opened blank private window."
    exit 0
}

$command       = $Args[$index]
$commandLower  = $command.ToLower()
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

$raw = Get-JoinedText -Items $Args -StartIndex $index
Write-Log "No known command. Treating as raw text '$raw'."

if ([string]::IsNullOrWhiteSpace($raw)) {
    Open-BrowserWindow -Url $null -IsPrivate:$isPrivate
    Write-Log "Raw text empty; opened blank window."
} else {
    Open-BrowserWindow -Url $raw -IsPrivate:$isPrivate
    Write-Log "Opened browser with raw text as URL or search string."
}
