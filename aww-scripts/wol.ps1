$Command="$($args[0])"

# See also https://superuser.com/questions/1768290/executing-wake-on-lan-from-vanilla-windows-cmd

# ====================================================================================
# Wake-on-LAN helper with verbose, colored logging and clear, self-documenting code.
# Commands:
#   wol.ps1 help
#   wol.ps1 add <name> <mac-address>
#   wol.ps1 send <name> [broadcast]
# Config files live at: ~/.aww-wol/<name>.json containing JSON: { "macAddr": "AA:BB:CC:DD:EE:FF" }
# ====================================================================================

$ErrorActionPreference = "Stop"

# -----------------------------
# Constants
# -----------------------------
$COMMAND_HELP = "help"
$COMMAND_SEND = "send"
$COMMAND_ADD  = "add"
$DEFAULT_BROADCAST = "255.255.255.255"
$CONFIG_DIR_NAME = ".aww-wol"
$CONFIG_EXT = ".json"
$UDP_PORT = 9

$HELP_MESSAGE = @"
Usage:
  wol.ps1 <command> [args...]
  aww run wol <command> [args...]

Commands:
  $($COMMAND_HELP)
    Shows this help message

  $($COMMAND_ADD) <name> <mac-address>
    Creates ~/.aww-wol/<name>.json with JSON containing the MAC address
    Fails if the file already exists
    Example: wol.ps1 add comp2 00-11-22-33-44-55

  $($COMMAND_SEND) <name> [broadcast]
    Reads ~/.aww-wol/<name>.json, parses JSON, and sends WOL magic packet
    Default broadcast is 255.255.255.255, UDP port 9
    Example: wol.ps1 send comp1 192.168.1.255
"@

# -----------------------------
# Logging helpers
# -----------------------------
function Write-Log {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet("INFO","ACTION","SUCCESS","WARN","ERROR","CONTEXT")]
        [string]$Level = "INFO",
        [int]$Indent = 0
    )
    $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
    $prefix = switch ($Level) {
        "INFO"    { "[INFO]" }
        "ACTION"  { "[ACT]"  }
        "SUCCESS" { "[OK]"   }
        "WARN"    { "[WARN]" }
        "ERROR"   { "[ERR]"  }
        "CONTEXT" { "[CTX]"  }
    }
    $color = switch ($Level) {
        "INFO"    { "Cyan" }
        "ACTION"  { "Yellow" }
        "SUCCESS" { "Green" }
        "WARN"    { "DarkYellow" }
        "ERROR"   { "Red" }
        "CONTEXT" { "Gray" }
    }
    $pad = " " * ($Indent * 2)
    Write-Host "$ts $prefix $pad$Message" -ForegroundColor $color
}

function Write-Section {
    param([string]$Title)
    Write-Host ("=" * 80) -ForegroundColor DarkCyan
    Write-Log -Message $Title -Level INFO
    Write-Host ("=" * 80) -ForegroundColor DarkCyan
}

# -----------------------------
# Paths and config
# -----------------------------
function Get-ConfigDirectory {
    $userHome = [Environment]::GetFolderPath("UserProfile")
    Join-Path $userHome $CONFIG_DIR_NAME
}

function Ensure-ConfigDirectory {
    $dir = Get-ConfigDirectory
    if (-not (Test-Path -LiteralPath $dir)) {
        Write-Log -Level ACTION -Message "Creating config directory: $dir"
        New-Item -ItemType Directory -Path $dir | Out-Null
        Write-Log -Level SUCCESS -Message "Created: $dir"
    } else {
        Write-Log -Level CONTEXT -Message "Config directory exists: $dir"
    }
    $dir
}

function Get-ConfigPath {
    param([Parameter(Mandatory)][string]$Name)
    Join-Path (Get-ConfigDirectory) ("{0}{1}" -f $Name, $CONFIG_EXT)
}

# -----------------------------
# MAC helpers
# -----------------------------
function Normalize-Mac {
    param([Parameter(Mandatory)][string]$Mac)

    $compact = ($Mac -replace "[:\-\.]", "").ToUpper()
    if ($compact.Length -ne 12) {
        throw "Invalid MAC length. Expected 12 hex characters after stripping separators. Got: $($compact.Length)"
    }
    if ($compact -notmatch "^[0-9A-F]{12}$") {
        throw "Invalid MAC characters. Only 0-9 and A-F are allowed. Got: $compact"
    }

    $parts = @()
    for ($i = 0; $i -lt 12; $i += 2) {
        $parts += $compact.Substring($i, 2)
    }
    [string]::Join(":", $parts)
}

function Mac-To-Bytes {
    param([Parameter(Mandatory)][string]$Mac)
    $hex = ($Mac -replace "[:\-\.]", "").ToUpper()
    $bytes = New-Object byte[] 6
    for ($i=0; $i -lt 6; $i++) {
        $bytes[$i] = [Convert]::ToByte($hex.Substring($i*2,2),16)
    }
    $bytes
}

# -----------------------------
# File parsing
# -----------------------------
function Read-Target-Mac {
    param([Parameter(Mandatory)][string]$Name)

    Ensure-ConfigDirectory | Out-Null

    $path = Get-ConfigPath -Name $Name
    Write-Log -Level CONTEXT -Message "Reading target file"
    Write-Log -Level CONTEXT -Message "Path: $path" -Indent 1

    if (-not (Test-Path -LiteralPath $path)) {
        # Create the path and a template file to guide the user
        Write-Log -Level WARN -Message "Config file not found. Creating template file." -Indent 1
        $template = @{ macAddr = "AA:BB:CC:DD:EE:FF" } | ConvertTo-Json -Depth 3
        $template | Out-File -LiteralPath $path -Encoding UTF8 -NoNewline
        Write-Log -Level SUCCESS -Message "Template created: $path" -Indent 1
        throw "Please edit the template file and set macAddr, then re-run the command."
    }

    $raw = Get-Content -LiteralPath $path -Raw
    Write-Log -Level CONTEXT -Message "Raw file content:" -Indent 1
    Write-Host $raw -ForegroundColor DarkGray

    $obj = $null
    $jsonOk = $false
    try {
        $obj = $raw | ConvertFrom-Json
        $jsonOk = $true
        Write-Log -Level SUCCESS -Message "Strict JSON parse succeeded" -Indent 1
    } catch {
        Write-Log -Level WARN -Message "Strict JSON parse failed, attempting minimal repair" -Indent 1
        $jsonOk = $false
    }

    if (-not $jsonOk) {
        $rxUnquotedKey = '(\{|,)\s*macAddr\s*:'
        $rxMacBody = '([0-9A-Fa-f]{2}(?:(?:[:\-])[0-9A-Fa-f]{2}){5})'
        $rxUnquotedMacValue = ":\s*$rxMacBody\s*(\}|,)"

        if ($raw -match $rxUnquotedKey) {
            Write-Log -Level ACTION -Message "Quoting unquoted macAddr property name" -Indent 1
            $raw = [regex]::Replace($raw, $rxUnquotedKey, '$1 "macAddr":')
        } else {
            Write-Log -Level CONTEXT -Message "macAddr property name appears properly quoted" -Indent 1
        }

        if ($raw -match $rxUnquotedMacValue) {
            Write-Log -Level ACTION -Message "Quoting unquoted MAC value" -Indent 1
            $raw = [regex]::Replace($raw, $rxUnquotedMacValue, ': "$1"$2')
        } else {
            Write-Log -Level CONTEXT -Message "MAC value appears properly quoted" -Indent 1
        }

        try {
            $obj = $raw | ConvertFrom-Json
            $jsonOk = $true
            Write-Log -Level SUCCESS -Message "JSON parse succeeded after minimal repair" -Indent 1
        } catch {
            Write-Log -Level ERROR -Message "JSON parse failed after repair: $($_.Exception.Message)" -Indent 1
            throw
        }
    }

    if (-not $obj.macAddr) {
        throw "JSON missing macAddr property in $path"
    }

    $mac = [string]$obj.macAddr
    Write-Log -Level SUCCESS -Message "Parsed macAddr: $mac" -Indent 1
    $mac
}

# -----------------------------
# Networking
# -----------------------------
function Send-WoL {
    param(
        [Parameter(Mandatory)][string]$MacAddress,
        [string]$BroadcastAddress
    )

    Write-Section "Preparing magic packet"
    $normalizedMac = Normalize-Mac -Mac $MacAddress
    Write-Log -Level CONTEXT -Message "Normalized MAC: $normalizedMac" -Indent 1

    $macBytes = Mac-To-Bytes -Mac $normalizedMac
    Write-Log -Level CONTEXT -Message ("MAC bytes: " + ($macBytes | ForEach-Object { $_.ToString("X2") }) -join "-") -Indent 1

    $packetLength = 6 + (16 * 6)
    $packet = New-Object byte[] $packetLength
    for ($i=0; $i -lt 6; $i++) { $packet[$i] = 0xFF }
    $offset = 6
    for ($rep=1; $rep -le 16; $rep++) {
        [Array]::Copy($macBytes, 0, $packet, $offset, 6)
        $offset += 6
    }
    Write-Log -Level SUCCESS -Message "Magic packet built. Length: $packetLength bytes" -Indent 1

    $ip = $null
    if (-not [System.Net.IPAddress]::TryParse($BroadcastAddress, [ref]$ip)) {
        throw "Invalid broadcast address: $BroadcastAddress"
    }

    Write-Section "Sending magic packet"
    Write-Log -Level CONTEXT -Message "Target broadcast: $BroadcastAddress" -Indent 1
    Write-Log -Level CONTEXT -Message "UDP port: $UDP_PORT" -Indent 1

    $udpClient = [System.Net.Sockets.UdpClient]::new()
    try {
        $udpClient.EnableBroadcast = $true
        $udpClient.Connect($ip, $UDP_PORT) | Out-Null
        Write-Log -Level ACTION -Message "Transmitting packet..." -Indent 1
        $sent = $udpClient.Send($packet, $packet.Length)
        Write-Log -Level SUCCESS -Message "Bytes sent: $sent" -Indent 1
    } finally {
        $udpClient.Close()
        Write-Log -Level INFO -Message "UDP client closed" -Indent 1
    }

    $normalizedMac
}

# -----------------------------
# Command handlers
# -----------------------------
function Handle-Add {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$MacInput
    )

    Write-Section "Add host"
    Ensure-ConfigDirectory | Out-Null

    $path = Get-ConfigPath -Name $Name
    if (Test-Path -LiteralPath $path) {
        Write-Log -Level ERROR -Message "File already exists: $($path)"
        exit 1
    }

    $normalizedMac = Normalize-Mac -Mac $MacInput
    Write-Log -Level CONTEXT -Message "Host name: $Name" -Indent 1
    Write-Log -Level CONTEXT -Message "MAC normalized: $normalizedMac" -Indent 1
    Write-Log -Level CONTEXT -Message "Config path: $path" -Indent 1

    $json = @{ macAddr = $normalizedMac } | ConvertTo-Json -Depth 3
    Write-Log -Level ACTION -Message "Writing JSON to file" -Indent 1
    $json | Out-File -LiteralPath $path -Encoding UTF8 -NoNewline

    Write-Log -Level SUCCESS -Message "Created: $path"
    Write-Log -Level CONTEXT -Message "File content:" -Indent 1
    Write-Host $json -ForegroundColor DarkGray
}

function Handle-Send {
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$Broadcast = $DEFAULT_BROADCAST
    )

    Write-Section "Wake host"
    Ensure-ConfigDirectory | Out-Null

    Write-Log -Level CONTEXT -Message "Computer name: $Name" -Indent 1
    Write-Log -Level CONTEXT -Message "Requested broadcast: $Broadcast" -Indent 1

    $mac = Read-Target-Mac -Name $Name
    $normalizedMac = Normalize-Mac -Mac $mac
    Write-Log -Level CONTEXT -Message "Final MAC used: $normalizedMac" -Indent 1

    try {
        $Broadcast = $(if ($Broadcast) {$Broadcast} else { $DEFAULT_BROADCAST })
        $finalMac = Send-WoL -MacAddress $normalizedMac -BroadcastAddress $Broadcast
        Write-Section "Result"
        Write-Log -Level SUCCESS -Message "Magic packet sent" -Indent 1
        Write-Log -Level CONTEXT -Message "Computer: $Name" -Indent 2
        Write-Log -Level CONTEXT -Message "MAC: $finalMac" -Indent 2
        Write-Log -Level CONTEXT -Message "Broadcast: $Broadcast" -Indent 2
        Write-Log -Level CONTEXT -Message "Port: $UDP_PORT" -Indent 2
    } catch {
        Write-Section "Result"
        Write-Log -Level ERROR -Message "Failed to send magic packet: $($_.Exception.Message)" -Indent 1
        exit 1
    }
}

# -----------------------------
# Main
# -----------------------------
switch ($Command.ToLower()) {
    $COMMAND_HELP {
        Write-Section "Help"
        Write-Host $HELP_MESSAGE
    }

    $COMMAND_ADD {
        if ($args.Count -lt 2) {
            Write-Section "Error"
            Write-Log -Level ERROR -Message "Missing arguments. Usage: wol.ps1 add <name> <mac-address>"
            exit 1
        }
        $name = [string]$args[1]
        $macInput = [string]$args[2]
        Handle-Add -Name $name -MacInput $macInput
    }

    $COMMAND_SEND {
        if ($args.Count -lt 1) {
            Write-Section "Error"
            Write-Log -Level ERROR -Message "Missing arguments. Usage: wol.ps1 send <name> [broadcast]"
            exit 1
        }
        $name = [string]$args[1]
        $broadcast = if ($args.Count -ge 2) { [string]$args[2] } else { $DEFAULT_BROADCAST }
        Handle-Send -Name $name -Broadcast $broadcast
    }

    Default {
        Write-Section "Error"
        Write-Log -Level ERROR -Message "Unknown command: $Command"
        Write-Host $HELP_MESSAGE
        exit 1
    }
}

Write-Section "Done"
Write-Log -Level SUCCESS -Message ("Completed at: " + (Get-Date -Format o))
