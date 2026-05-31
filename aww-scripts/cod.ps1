# cod.ps1
# PowerShell 5.1 / PowerShell 7 compatible

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

$Model = "gpt-5.4-mini"
$ReasoningEffort = "medium"

function Get-LogTimestamp {
    return (Get-Date).ToString("o")
}

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Message
    )

    Write-Host "[$(Get-LogTimestamp)] $Message"
}

function Write-LogError {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Message
    )

    [Console]::Error.WriteLine("[$(Get-LogTimestamp)] $Message")
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

if (-not $args -or $args.Count -eq 0) {
    [Console]::Error.WriteLine("Usage: cod.ps1 <prompt>")
    exit 1
}

$Prompt = [string]::Join(" ", $args)
$Platform = Get-CurrentPlatform
$WorkingDirectory = (Get-Location).Path
$StartTime = Get-Date
$ExitCode = 1

$ReasoningConfig = "model_reasoning_effort=`"$ReasoningEffort`""

$ScriptPath = $MyInvocation.MyCommand.Path
if (-not $ScriptPath) {
    $ScriptPath = "<unknown>"
}

Write-Log "Start: $($StartTime.ToString("o"))"
Write-Log "Script: $ScriptPath"
Write-Log "PowerShell version: $($PSVersionTable.PSVersion.ToString())"
Write-Log "Directory: $WorkingDirectory"
Write-Log "Platform: $Platform"
Write-Log "Model: $Model"
Write-Log "Reasoning: $ReasoningEffort"
Write-Log "Prompt: $Prompt"

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

        Write-Log "Runtime: WSL default distro"
        Write-Log "Command start: $CommandLine"

        $CommandStartTime = Get-Date
        & wsl.exe @WslArgs
        $ExitCode = Get-NativeExitCode
        $CommandEndTime = Get-Date
        $CommandDuration = $CommandEndTime - $CommandStartTime

        Write-Log "Command result: exit code $ExitCode"
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

        Write-Log "Runtime: native"
        Write-Log "Command start: $CommandLine"

        $CommandStartTime = Get-Date
        $Prompt | & codex @CodexArgs
        $ExitCode = Get-NativeExitCode
        $CommandEndTime = Get-Date
        $CommandDuration = $CommandEndTime - $CommandStartTime

        Write-Log "Command result: exit code $ExitCode"
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

Write-Log "End: $($EndTime.ToString("o"))"
Write-Log ("Total duration: {0:N2}s" -f $Duration.TotalSeconds)

if ($ExitCode -eq 0) {
    Write-Log "Status: Success"
}
else {
    Write-LogError "Status: Failed, exit code $ExitCode"
}

exit $ExitCode