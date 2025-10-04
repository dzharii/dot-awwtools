param(
    [Parameter(Mandatory = $true)]
    [string]$Command,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Arguments = @()
)

$ErrorActionPreference = "Stop"
$ThisScriptFolderPath = Split-Path -Parent $MyInvocation.MyCommand.Definition

$COMMAND_HELP = "help"
$COMMAND_REL = "rel"
$COMMAND_RELC = "relc"
$COMMAND_UREL = "urel"

$HELP_MESSAGE = @"
Usage:
   path.ps1 <command> [arguments]
   aww run path <command> [arguments]

Commands:
    $($COMMAND_HELP):
      Shows this help message

    $($COMMAND_REL) <target-path> [pivot-directory]:
      Calculate relative path from pivot to target (default: current directory)

    $($COMMAND_RELC) <target-path> [pivot-directory]:
      Calculate relative path with Unix-style separators (convenient for C includes)

    $($COMMAND_UREL) <target-path> [pivot-directory]:
      Alias for relc command

"@

# Test if a path is absolute (cross-platform)
function Test-IsAbsolutePath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    if ($IsWindows -or $env:OS -like "*Windows*") {
        return ($Path -match '^(?:[A-Za-z]:\\|\\\\)')
    }
    else {
        return $Path.StartsWith("/")
    }
}

# Calculate relative path from base directory to target path
function Get-RelativePathInternal {
    param([string]$BaseDir, [string]$TargetPath)

    $baseFull = [IO.Path]::GetFullPath($BaseDir).TrimEnd('\', '/')
    $targetFull = [IO.Path]::GetFullPath($TargetPath)

    $baseUri = [Uri]("$baseFull$([IO.Path]::DirectorySeparatorChar)")
    $targetUri = [Uri]$targetFull

    $relativeUri = $baseUri.MakeRelativeUri($targetUri)
    $rel = [Uri]::UnescapeDataString($relativeUri.ToString())
    $sep = [IO.Path]::DirectorySeparatorChar
    return ($rel -replace '/', $sep)
}

# Convert path separators to Unix style (forward slashes)
function ConvertTo-UnixPath {
    param([string]$Path)
    return $Path -replace '\\', '/'
}

# Validate and process relative path arguments
function Get-ValidatedPaths {
    param([string[]]$Arguments)

    Write-Output "[Start] Parsing arguments"
    $rawTarget = if ($Arguments.Count -ge 1) { $Arguments[0] } else { $null }
    $rawPivot = if ($Arguments.Count -ge 2) { $Arguments[1] } else { $null }
    Write-Output "  Received TargetPath raw: '$($rawTarget)'"
    Write-Output "  Received PivotPath raw: '$($rawPivot)'"

    if ([string]::IsNullOrWhiteSpace($rawTarget)) {
        throw "Validation error: missing required first argument TargetPath"
    }

    $TargetPath = $rawTarget
    $PivotPath = if ([string]::IsNullOrWhiteSpace($rawPivot)) { (Get-Location).Path } else { $rawPivot }
    Write-Output "  Using TargetPath: '$($TargetPath)'"
    Write-Output "  Using PivotPath: '$($PivotPath)'"

    Write-Output "[Stage] Validating TargetPath is absolute"
    if (-not (Test-IsAbsolutePath $TargetPath)) {
        throw "Validation error: target path must be an absolute path: '$($TargetPath)'"
    }

    Write-Output "[Stage] Resolving paths to canonical forms"
    $t = (Resolve-Path -LiteralPath $TargetPath).Path
    $p = (Resolve-Path -LiteralPath $PivotPath).Path
    Write-Output "  Resolved TargetPath: '$($t)'"
    Write-Output "  Resolved PivotPath: '$($p)'"

    Write-Output "[Stage] Validating PivotPath is a directory"
    if (-not (Test-Path -LiteralPath $p -PathType Container)) {
        throw "Validation error: pivot path must be a directory: '$($PivotPath)'"
    }

    Write-Output "[Stage] Validating roots are the same"
    $tr = [IO.Path]::GetPathRoot($t).TrimEnd('\', '/')
    $pr = [IO.Path]::GetPathRoot($p).TrimEnd('\', '/')
    Write-Output "  Target root: '$($tr)'"
    Write-Output "  Pivot root: '$($pr)'"
    if ($IsWindows -or $env:OS -like "*Windows*") {
        if ($tr -ne $pr) {
            throw "Validation error: paths are on different roots: base='$($pr)' target='$($tr)'"
        }
    }

    return @{
        TargetPath = $t
        PivotPath  = $p
    }
}

# Process relative path command with native separators
function Invoke-RelativePathCommand {
    param([string[]]$Arguments)

    try {
        $paths = Get-ValidatedPaths -Arguments $Arguments

        Write-Output "[Stage] Computing relative path"
        $rel = Get-RelativePathInternal -BaseDir $paths.PivotPath -TargetPath $paths.TargetPath
        Write-Output "  Computed relative path: '$($rel)'"

        Write-Output "[Stage] Output and clipboard"
        Write-Output $rel
        Set-Clipboard -Value $rel
        Write-Output "  Copied to clipboard: '$($rel)'"

        Write-Output "[Done]"
    }
    catch {
        Write-Error $_.Exception.Message
        Write-Output ""
        try {
            Set-Clipboard -Value ""
            Write-Output "  Copied empty string to clipboard due to error"
        }
        catch {}
        exit 1
    }
}

# Process relative path command with Unix-style separators
function Invoke-RelativePathUnixCommand {
    param([string[]]$Arguments)

    try {
        $paths = Get-ValidatedPaths -Arguments $Arguments

        Write-Output "[Stage] Computing relative path"
        $rel = Get-RelativePathInternal -BaseDir $paths.PivotPath -TargetPath $paths.TargetPath
        $unixRel = ConvertTo-UnixPath -Path $rel
        Write-Output "  Computed relative path: '$($unixRel)'"

        Write-Output "[Stage] Output and clipboard"
        Write-Output $unixRel
        Set-Clipboard -Value $unixRel
        Write-Output "  Copied to clipboard: '$($unixRel)'"

        Write-Output "[Done]"
    }
    catch {
        Write-Error $_.Exception.Message
        Write-Output ""
        try {
            Set-Clipboard -Value ""
            Write-Output "  Copied empty string to clipboard due to error"
        }
        catch {}
        exit 1
    }
}

switch ($Command.ToLower()) {

    $COMMAND_HELP {
        Write-Host $HELP_MESSAGE
    }

    $COMMAND_REL {
        Invoke-RelativePathCommand -Arguments $Arguments
    }

    $COMMAND_RELC {
        Invoke-RelativePathUnixCommand -Arguments $Arguments
    }

    $COMMAND_UREL {
        Invoke-RelativePathUnixCommand -Arguments $Arguments
    }

    Default {
        Write-Host $("=" * 80) -ForegroundColor Red
        Write-Host "Unknown command: $Command" -ForegroundColor Red
        Write-Host $("=" * 80) -ForegroundColor Red
        Write-Host $HELP_MESSAGE
        exit 1
    }
}

Write-Host "Done: $(Get-Date -Format o)"
