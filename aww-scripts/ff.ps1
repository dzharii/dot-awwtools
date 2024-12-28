param(
    [Parameter(Mandatory=$true)]
    [string]$Command,

    [Parameter(Mandatory=$false)]
    [string]$FilePath,

    [Parameter(Mandatory=$false)]
    [string]$FromTime,

    [Parameter(Mandatory=$false)]
    [string]$ToTime

)

$ErrorActionPreference = "Stop"
$ThisScriptFolderPath = Split-Path -Parent $MyInvocation.MyCommand.Definition

$COMMAND_HELP = "help"
$COMMAND_CLIP = "make-clip"

$HELP_MESSAGE = @"
Usage:
   ff.ps1 <command>
   aww run ff <command>

Commands:
    $($COMMAND_HELP):
      Shows this help message

    $($COMMAND_CLIP):
      Creates a video clip from the specified file using -FilePath, -FromTime, and -ToTime.

      Examples:
      1. Create a clip from 15 seconds to 25 seconds:
         ff.ps1 make-clip -FilePath "input.mp4" -FromTime "00:15" -ToTime "00:25"

      2. Create a clip from 1 hour 20 minutes to 1 hour 20 minutes and 25 seconds:
         ff.ps1 make-clip -FilePath "input.mp4" -FromTime "1:20:00" -ToTime "1:20:25"

      3. Create a 25-second clip starting at 15 seconds:
         ff.ps1 make-clip -FilePath "input.mp4" -FromTime "00:15" -ToTime "25s"

"@

function ParseTimeParameters {
    param (
        [string]$FromTime,
        [string]$ToTime
    )

    # Convert time strings to TimeSpan
    try {
        $fromTimeSpan = [System.TimeSpan]::Parse($FromTime)
    } catch {
        Write-Host "Error: Invalid FromTime format: '$($FromTime)'" -ForegroundColor Red
        exit 1
    }

    # Handle ToTime special cases (e.g., 15s, 20m)
    if ($ToTime -match "^\d+s$|\d+m$|\d+h$") {
        $durationValue = [int]($ToTime -replace "[smh]", "")
        $durationType = $ToTime[-1]

        switch ($durationType) {
            "s" { $toTimeSpan = $fromTimeSpan.Add([System.TimeSpan]::FromSeconds($durationValue)) }
            "m" { $toTimeSpan = $fromTimeSpan.Add([System.TimeSpan]::FromMinutes($durationValue)) }
            "h" { $toTimeSpan = $fromTimeSpan.Add([System.TimeSpan]::FromHours($durationValue)) }
        }
    } else {
        try {
            $toTimeSpan = [System.TimeSpan]::Parse($ToTime)
        } catch {
            Write-Host "Error: Invalid ToTime format: '$($ToTime)'" -ForegroundColor Red
            exit 1
        }
    }

    return @($fromTimeSpan.ToString("hh\:mm\:ss"), $toTimeSpan.ToString("hh\:mm\:ss"))
}

function Invoke-FFmpegMakeClip {
    param (
        [string]$FilePath,
        [string]$FromTime,
        [string]$ToTime
    )

    # Validate parameters
    if (-not $FilePath) {
        Write-Host "Error: FilePath parameter is missing. FilePath = '$($FilePath)'" -ForegroundColor Red
        exit 1
    }
    if (-not (Test-Path $FilePath)) {
        Write-Host "Error: FilePath does not exist or is invalid. FilePath = '$($FilePath)'" -ForegroundColor Red
        exit 1
    }
    if (-not $FromTime) {
        Write-Host "Error: FromTime parameter is missing. FromTime = '$($FromTime)'" -ForegroundColor Red
        exit 1
    }
    if (-not $ToTime) {
        Write-Host "Error: ToTime parameter is missing. ToTime = '$($ToTime)'" -ForegroundColor Red
        exit 1
    }

    # Check if ffmpeg is installed
    if (-not (Get-Command "ffmpeg" -ErrorAction SilentlyContinue)) {
        Write-Host "Error: ffmpeg executable not found. Please install ffmpeg and ensure it is in the system PATH." -ForegroundColor Red
        exit 1
    }

    # Parse time parameters
    $parsedTimes = ParseTimeParameters -FromTime $FromTime -ToTime $ToTime
    $fromTimeParsed = $parsedTimes[0]
    $toTimeParsed = $parsedTimes[1]

    # Generate safe output file name
    $BaseName = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
    $SafeBaseName = $BaseName -replace "[^a-zA-Z0-9_\-\.]", "_"
    $OutputDir = Join-Path -Path $ThisScriptFolderPath -ChildPath "clips"
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir | Out-Null
    }
    $OutputFile = Join-Path -Path $OutputDir -ChildPath "$($SafeBaseName)`_$($fromTimeParsed)`_to_$($toTimeParsed).mp4"

    # Call ffmpeg to create the clip
    $FFmpegCommand = "ffmpeg -i `"$($FilePath)`" -ss $($fromTimeParsed) -to $($toTimeParsed) -c copy `"$($OutputFile)`""
    Write-Host "Preparing to execute the following command:" -ForegroundColor Cyan
    Write-Host "$($FFmpegCommand)" -ForegroundColor Gray

    try {
        & ffmpeg -i "$FilePath" -ss $fromTimeParsed -to $toTimeParsed -c copy "$OutputFile"
        Write-Host "Clip created successfully: $($OutputFile)" -ForegroundColor Green
    } catch {
        Write-Host "Error during ffmpeg execution: $($_)" -ForegroundColor Red
        exit 1
    }
}

switch ($Command.ToLower()) {
    $COMMAND_HELP {
        Write-Host $HELP_MESSAGE
    }

    $COMMAND_CLIP {
        Invoke-FFmpegMakeClip -FilePath $FilePath -FromTime $FromTime -ToTime $ToTime
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
