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

$HELP_MESSAGE = @"
Usage:
   yt.ps1 <command> [options]

Commands:
    $($COMMAND_HELP):
      Youtube video management tools. 
      Shows this help message

    $($COMMAND_SUBS):
      Download subtitles for a specified YouTube URL.
      Options:
          -Url: The YouTube video URL (required for the 'subs' command).
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
        $ytDlpCommand = "yt-dlp.exe --write-subs --sub-lang `"en.*`" --skip-download -o `"%(title).200B.%(ext)s`" --restrict-filenames `"$($Url)`""
        
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

    Default {
        Write-Host $("=" * 80) -ForegroundColor Red
        Write-Host "Unknown command: $($Command)" -ForegroundColor Red
        Write-Host $("=" * 80) -ForegroundColor Red
        Write-Host $HELP_MESSAGE
        exit 1
    }
}

Write-Host "Done: $(Get-Date -Format o)"
