param(
    [Parameter(Mandatory=$true)]
    [string]$Command,

    [Parameter(Mandatory=$false)]
    [string]$Url
)

$ErrorActionPreference = "Stop"
$ThisScriptFolderPath = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Define command constants
$COMMAND_HELP = "help"
$COMMAND_SUBS = "subs"
$COMMAND_VTT_TO_TXT = "vtt-to-txt"

$HELP_MESSAGE = @"
Usage:
   yt.ps1 <command> [options]

Commands:
    $($COMMAND_HELP):
      Youtube video management tools. 
      Shows this help message

    $($COMMAND_SUBS) -Url:
      Download subtitles for a specified YouTube URL.
      Options:
          -Url: The YouTube video URL (required for the 'subs' command).

    $($COMMAND_VTT_TO_TXT) -Url:
      Converts vtt file to planin text file with same name + ".txt"
      Options:
          -Url: vtt file path
"@

# Validate URL format (for 'subs' command)
function Validate-Url {
    param (
        [string]$InputUrl
    )
    if (-not $InputUrl) {
        Write-Host "Error: The -Url parameter is required for the 'subs' command." -ForegroundColor Red
        exit 1
    }
    if ($InputUrl -notmatch "^https?://[a-zA-Z0-9\-.]+\.[a-zA-Z]{2,}(/\S*)?$") {
        Write-Host "Error: Invalid URL format provided: $($InputUrl)" -ForegroundColor Red
        exit 1
    }
}

switch ($Command.ToLower()) {
    
    $COMMAND_HELP {
        Write-Host $HELP_MESSAGE
    }

    $COMMAND_SUBS {
        # Ensure that the URL parameter is provided and valid for 'subs' command
        Validate-Url -InputUrl $Url

        # Construct the yt-dlp command for downloading subtitles
        $ytDlpCommand = "yt-dlp.exe --write-subs --write-auto-sub --sub-langs `"en`" --skip-download -o `"%(title).200B.%(ext)s`" --restrict-filenames `"$($Url)`""
        
        # Log the command for visibility
        Write-Host "Executing yt-dlp command:"
        Write-Host "$($ytDlpCommand)" -ForegroundColor Cyan

        try {
            # Execute the yt-dlp command
            Invoke-Expression $ytDlpCommand
            if ($LASTEXITCODE -ne 0) {
                Write-Host "Error: yt-dlp command failed with exit code $($LASTEXITCODE)" -ForegroundColor Red
                exit $LASTEXITCODE
            } else {
                Write-Host "Subtitles downloaded successfully." -ForegroundColor Green
            }
        }
        catch {
            Write-Host "Error: An exception occurred while executing yt-dlp command." -ForegroundColor Red
            Write-Host "$($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
    }

    $COMMAND_VTT_TO_TXT {
        if (!(Test-Path $Url)) {
            throw "The vtt file path='$($Url)' does not exit."
        }
        $inputFilePath = $Url
        $outputFilePath = "$($inputFilePath).txt"

        # Initialize an array to store the cleaned lines
        $cleanedLines = @()
        $previousLine = ""

        # Read each line from the input file
        foreach ($line in Get-Content -Path $inputFilePath) {
            # Skip the 'WEBVTT' header or any metadata lines (e.g., 'Kind: captions')
            if ($line -match "^(WEBVTT|Kind:|Language:)") {
                continue
            }

            # Remove timestamps (format: '00:00:00.520 --> 00:00:03.350 align:start position:0%')
            $line = [regex]::Replace($line, "\d{2}:\d{2}:\d{2}\.\d{3} --> \d{2}:\d{2}:\d{2}\.\d{3}.*", "")

            # Remove inline timestamps and tags (format: '<00:00:00.680><c>...</c>')
            $line = [regex]::Replace($line, "<\d{2}:\d{2}:\d{2}\.\d{3}>|<.*?>", "")

            # Trim leading and trailing whitespace
            $line = $line.Trim()

            # Check if the line is non-empty and different from the previous line
            if ($line -ne "" -and $line -ne $previousLine) {
                # Add the line to the output if it's unique in sequence
                $cleanedLines += $line
                # Update the previous line variable to the current line
                $previousLine = $line
            }
        }

        # Write the cleaned unique lines to the output file
        $cleanedLines | Set-Content -Path $outputFilePath

        Write-Host "Cleaned transcript saved to $($outputFilePath)"
    }

    Default {
        Write-Host $("=" * 80) -ForegroundColor Red
        Write-Host "Unknown command: $($Command)" -ForegroundColor Red
        Write-Host $("=" * 80) -ForegroundColor Red
        Write-Host $HELP_MESSAGE
        exit 1
    }
}

Write-Host "Done: $(Get-Date -Format o)"
