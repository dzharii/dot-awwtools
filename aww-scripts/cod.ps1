# cod.ps1
# 2026-05-30
# PowerShell 5.1 / PowerShell 7 compatible

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

# This model is dumb
# $Model = "gpt-5.4-mini"
$Model = "gpt-5.5"
$ReasoningEffort = "medium"

function Get-LogTimestamp {
    return (Get-Date).ToString("o")
}

function Write-Text {
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string] $Message = "",

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string] $ForegroundColor = "",

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string] $BackgroundColor = "",

        [Parameter(Mandatory = $false)]
        [switch] $NoNewline
    )

    $writeHostParams = @{
        Object = $Message
    }

    if (-not [string]::IsNullOrWhiteSpace($ForegroundColor)) {
        $writeHostParams.ForegroundColor = $ForegroundColor
    }

    if (-not [string]::IsNullOrWhiteSpace($BackgroundColor)) {
        $writeHostParams.BackgroundColor = $BackgroundColor
    }

    if ($NoNewline) {
        $writeHostParams.NoNewline = $true
    }

    Write-Host @writeHostParams
}

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Message,

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string] $ForegroundColor = "",

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string] $BackgroundColor = ""
    )

    Write-Text "[$(Get-LogTimestamp)] $Message" `
        -ForegroundColor $ForegroundColor `
        -BackgroundColor $BackgroundColor
}

function Write-LogError {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Message
    )

    Write-Log $Message -ForegroundColor "Red"
}

function Format-CommandArgumentForLog {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string] $Value
    )

    if ($Value -eq "") {
        return '""'
    }

    if ($Value -match '^[A-Za-z0-9_\-./:=@]+$') {
        return $Value
    }

    return '"' + ($Value -replace '"', '\"') + '"'
}

function Format-CommandLineForLog {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Command,

        [Parameter(Mandatory = $false)]
        [string[]] $Arguments = @()
    )

    $parts = @($Command)

    foreach ($argument in $Arguments) {
        $parts += (Format-CommandArgumentForLog $argument)
    }

    return [string]::Join(" ", $parts)
}

function Get-CurrentPlatform {
    $isWindowsVar = Get-Variable -Name IsWindows -ErrorAction SilentlyContinue
    $isLinuxVar = Get-Variable -Name IsLinux -ErrorAction SilentlyContinue

    if ($null -ne $isWindowsVar -and [bool]$isWindowsVar.Value) {
        return "Windows"
    }

    if ($null -ne $isLinuxVar -and [bool]$isLinuxVar.Value) {
        return "Linux"
    }

    if ($env:OS -eq "Windows_NT") {
        return "Windows"
    }

    return "Unknown"
}

function ConvertTo-PosixSingleQuotedString {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string] $Value
    )

    return "'" + $Value.Replace("'", "'\''") + "'"
}

function Get-NativeExitCode {
    if ($null -ne $LASTEXITCODE) {
        return [int]$LASTEXITCODE
    }

    if ($?) {
        return 0
    }

    return 1
}

function Set-ProcessEnv {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string] $Value
    )

    [Environment]::SetEnvironmentVariable(
        $Name,
        $Value,
        [System.EnvironmentVariableTarget]::Process
    )
}

function Read-CodexPrompt {
    param(
        [Parameter(Mandatory = $true)]
        [string] $WorkingDirectory
    )

    Write-Text ""
    Write-Text "Codex task input" -ForegroundColor "Cyan"
    Write-Text "Current directory: $WorkingDirectory"
    Write-Text ""
    Write-Text "Type the task you want Codex to execute."
    Write-Text "Press Enter to submit."
    Write-Text "Press Shift+Enter for a new line when PSReadLine is available."
    Write-Text "Press Ctrl+C to cancel."
    Write-Text "Submit an empty prompt to cancel."
    Write-Text ""

    try {
        Import-Module PSReadLine -ErrorAction Stop

        Write-Text "codex> " -ForegroundColor "Magenta" -NoNewline

        $value = [Microsoft.PowerShell.PSConsoleReadLine]::ReadLine(
            $Host.Runspace,
            $ExecutionContext
        )

        if ($null -eq $value) {
            return $null
        }

        return $value.Trim()
    }
    catch [System.OperationCanceledException] {
        return $null
    }
    catch [System.Management.Automation.PipelineStoppedException] {
        return $null
    }
    catch {
        Write-Text "PSReadLine is not available. Falling back to Read-Host." -ForegroundColor "Cyan"

        try {
            $value = Read-Host "codex"

            if ($null -eq $value) {
                return $null
            }

            return $value.Trim()
        }
        catch {
            return $null
        }
    }
}

$WorkingDirectory = (Get-Location).Path
$Platform = Get-CurrentPlatform
$StartTime = Get-Date
$ExitCode = 1

if (-not $args -or $args.Count -eq 0) {
    $Prompt = Read-CodexPrompt -WorkingDirectory $WorkingDirectory

    if ([string]::IsNullOrWhiteSpace($Prompt)) {
        Write-Log "Status: Cancelled, empty prompt" -ForegroundColor "Cyan"
        exit 0
    }
}
else {
    $Prompt = [string]::Join(" ", $args)
}

$ReasoningConfig = "model_reasoning_effort=`"$ReasoningEffort`""

$ScriptPath = $MyInvocation.MyCommand.Path
if (-not $ScriptPath) {
    $ScriptPath = "<unknown>"
}

Write-Log "Start: $($StartTime.ToString("o"))" -ForegroundColor "Cyan"
Write-Log "Script: $ScriptPath"
Write-Log "PowerShell version: $($PSVersionTable.PSVersion.ToString())"
Write-Log "Directory: $WorkingDirectory"
Write-Log "Platform: $Platform"
Write-Log "Model: $Model"
Write-Log "Reasoning: $ReasoningEffort"

Write-Log "Prompt:" -ForegroundColor "Cyan"
Write-Text $Prompt -ForegroundColor "Magenta"

$oldNoUpdateNotifier = [Environment]::GetEnvironmentVariable(
    "NO_UPDATE_NOTIFIER",
    [System.EnvironmentVariableTarget]::Process
)
$oldNpmUpdateNotifierLower = [Environment]::GetEnvironmentVariable(
    "npm_config_update_notifier",
    [System.EnvironmentVariableTarget]::Process
)
$oldNpmUpdateNotifierUpper = [Environment]::GetEnvironmentVariable(
    "NPM_CONFIG_UPDATE_NOTIFIER",
    [System.EnvironmentVariableTarget]::Process
)
$oldCI = [Environment]::GetEnvironmentVariable(
    "CI",
    [System.EnvironmentVariableTarget]::Process
)

try {
    Set-ProcessEnv "NO_UPDATE_NOTIFIER" "1"
    Set-ProcessEnv "npm_config_update_notifier" "false"
    Set-ProcessEnv "NPM_CONFIG_UPDATE_NOTIFIER" "false"
    Set-ProcessEnv "CI" "1"

    Write-Log "Update-notifier environment enabled"

    if ($Platform -eq "Windows") {
        $PromptBase64 = [Convert]::ToBase64String(
            [System.Text.Encoding]::UTF8.GetBytes($Prompt)
        )

        $QuotedPromptBase64 = ConvertTo-PosixSingleQuotedString $PromptBase64
        $QuotedModel = ConvertTo-PosixSingleQuotedString $Model
        $QuotedReasoningConfig = ConvertTo-PosixSingleQuotedString $ReasoningConfig

        $BashCommand = @(
            "printf %s $QuotedPromptBase64",
            "|",
            "base64 -d",
            "|",
            "env",
            "CI=1",
            "NO_UPDATE_NOTIFIER=1",
            "npm_config_update_notifier=false",
            "NPM_CONFIG_UPDATE_NOTIFIER=false",
            "codex",
            "exec",
            "--yolo",
            "--model $QuotedModel",
            "--color never",
            "--skip-git-repo-check",
            "--config $QuotedReasoningConfig",
            "-"
        ) -join " "

        $WslArgs = @(
            "bash",
            "-ic",
            $BashCommand
        )

        $CommandLine = Format-CommandLineForLog "wsl.exe" $WslArgs

        Write-Log "Runtime: WSL default distro" -ForegroundColor "Cyan"
        Write-Log "Command start:" -ForegroundColor "Cyan"
        Write-Text $CommandLine -ForegroundColor "Magenta"

        $CommandStartTime = Get-Date
        & wsl.exe @WslArgs
        $ExitCode = Get-NativeExitCode
        $CommandEndTime = Get-Date
        $CommandDuration = $CommandEndTime - $CommandStartTime

        Write-Log "Command result: exit code $ExitCode" -ForegroundColor "Cyan"
        Write-Log ("Command duration: {0:N2}s" -f $CommandDuration.TotalSeconds)
    }
    elseif ($Platform -eq "Linux") {
        $CodexArgs = @(
            "exec",
            "--yolo",
            "--model", $Model,
            "--color", "never",
            "--skip-git-repo-check",
            "--config", $ReasoningConfig,
            "-"
        )

        $CommandLine = Format-CommandLineForLog "codex" $CodexArgs

        Write-Log "Runtime: native" -ForegroundColor "Cyan"
        Write-Log "Command start:" -ForegroundColor "Cyan"
        Write-Text $CommandLine -ForegroundColor "Magenta"

        $CommandStartTime = Get-Date
        $Prompt | & codex @CodexArgs
        $ExitCode = Get-NativeExitCode
        $CommandEndTime = Get-Date
        $CommandDuration = $CommandEndTime - $CommandStartTime

        Write-Log "Command result: exit code $ExitCode" -ForegroundColor "Cyan"
        Write-Log ("Command duration: {0:N2}s" -f $CommandDuration.TotalSeconds)
    }
    else {
        throw "Unsupported platform: $Platform. This wrapper supports Windows and Linux."
    }
}
catch {
    Write-LogError "Error: $($_.Exception.Message)"
    $ExitCode = 1
}
finally {
    Set-ProcessEnv "NO_UPDATE_NOTIFIER" $oldNoUpdateNotifier
    Set-ProcessEnv "npm_config_update_notifier" $oldNpmUpdateNotifierLower
    Set-ProcessEnv "NPM_CONFIG_UPDATE_NOTIFIER" $oldNpmUpdateNotifierUpper
    Set-ProcessEnv "CI" $oldCI
}

$EndTime = Get-Date
$Duration = $EndTime - $StartTime

Write-Log "End: $($EndTime.ToString("o"))" -ForegroundColor "Cyan"
Write-Log ("Total duration: {0:N2}s" -f $Duration.TotalSeconds)

if ($ExitCode -eq 0) {
    Write-Log "Status: Success" -ForegroundColor "Green"
}
else {
    Write-LogError "Status: Failed, exit code $ExitCode"
}

exit $ExitCode