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
$COMMAND_DOWNLOAD = "download"
$COMMAND_DOWNLOAD_MP3 = "download-mp3"
$COMMAND_VIDEO_TO_PDF = "video-to-pdf"


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
      Converts vtt file to plain text file with same name + ".txt"
      Options:
          -Url: vtt file path

    $($COMMAND_DOWNLOAD) -Url:
      Download a YouTube video.
      Options:
          -Url: The YouTube video URL (required for the 'download' command).

    $($COMMAND_DOWNLOAD_MP3) -Url:
      Download a YouTube video as MP3.
      Options:
          -Url: The YouTube video URL (required for the 'download-mp3' command).

    $($COMMAND_VIDEO_TO_PDF) -Url:
      Extract keyframes with overlaid timestamps from a video file and compile them into a PDF.
      Options:
        -Url: The path to the video file (note: this is a file path, not a URL).
"@

# Validate URL format (for 'subs' and 'download' commands)
function Validate-Url {
    param (
        [string]$InputUrl
    )
    if (-not $InputUrl) {
        Write-Host "Error: The -Url parameter is required." -ForegroundColor Red
        exit 1
    }
    if ($InputUrl -notmatch "^https?://[a-zA-Z0-9\-.]+\.[a-zA-Z]{2,}(/\S*)?$") {
        Write-Host "Error: Invalid URL format provided: $($InputUrl)" -ForegroundColor Red
        exit 1
    }
}

function Format-FFmpegFontPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FontPath
    )

    # Replace backslashes with forward slashes for ffmpeg compatibility
    $formattedPath = $FontPath -replace '\\', '/'

    # Escape colons (for Windows drive letters like C:) by doubling them
    $formattedPath = $formattedPath -replace ':', '\\:'

    return $formattedPath
}

function Get-FFmpegFontPath {
    [CmdletBinding()]
    param(
        # The font name to search for (without extension)
        [string]$FontName = "Arial"
    )

    # Define file extensions to check
    $extensions = @("ttf", "otf")

    # Detect operating system using .NET's Environment class
    $platform = [System.Environment]::OSVersion.Platform

    if ($platform -eq [System.PlatformID]::Win32NT) {
        # On Windows, fonts are typically stored in C:\Windows\Fonts
        $fontDir = "C:/Windows/Fonts"
        foreach ($ext in $extensions) {
            # Build a pattern for an exact match (case-insensitive)
            $pattern = "$($FontName).$($ext)"
            $found = Get-ChildItem -Path "$($fontDir)" -Filter "$($pattern)" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($found) {
                return Format-FFmpegFontPath -FontPath $found.FullName
            }
        }
    }
    elseif ($platform -eq [System.PlatformID]::Unix) {
        # Differentiate between Linux and macOS by checking for macOS specific directory
        if (Test-Path "/System/Library/Fonts") {
            # macOS common directories
            $fontDirs = @("/Library/Fonts", "/System/Library/Fonts", "$($env:HOME)/Library/Fonts")
        }
        else {
            # Linux common directories
            $fontDirs = @("/usr/share/fonts/truetype", "/usr/local/share/fonts", "$($env:HOME)/.fonts")
        }
        foreach ($dir in $fontDirs) {
            if (Test-Path "$($dir)") {
                foreach ($ext in $extensions) {
                    $pattern = "*$($FontName)*.$($ext)"
                    $found = Get-ChildItem -Path "$($dir)" -Filter "$($pattern)" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
                    if ($found) {
                        return Format-FFmpegFontPath -FontPath $found.FullName
                    }
                }
            }
        }
    }
    else {
        Write-Error "Unsupported operating system."
        return $null
    }

    Write-Warning "Font '$($FontName)' not found in common directories."
    return $null
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

    $COMMAND_DOWNLOAD {
        # Ensure that the URL parameter is provided and valid for 'download' command
        Validate-Url -InputUrl $Url

        # Construct the yt-dlp command for downloading the video
        $ytDlpCommand = "yt-dlp.exe -o `"%(title)s.%(ext)s`" --restrict-filenames `"$($Url)`""

        # Log the command for visibility
        Write-Host "Executing yt-dlp command to download video:"
        Write-Host "$($ytDlpCommand)" -ForegroundColor Cyan

        try {
            # Execute the yt-dlp command
            Invoke-Expression $ytDlpCommand
            if ($LASTEXITCODE -ne 0) {
                Write-Host "Error: yt-dlp command failed with exit code $($LASTEXITCODE)" -ForegroundColor Red
                exit $LASTEXITCODE
            } else {
                Write-Host "Video downloaded successfully." -ForegroundColor Green
            }
        }
        catch {
            Write-Host "Error: An exception occurred while executing yt-dlp command." -ForegroundColor Red
            Write-Host "$($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
    }

    $COMMAND_DOWNLOAD_MP3 {
        # Ensure that the URL parameter is provided and valid for 'download-mp3' command
        Validate-Url -InputUrl $Url

        # Construct the yt-dlp command for downloading the video as MP3
        $ytDlpCommand = "yt-dlp.exe -x --audio-format mp3 -o `"%(title)s.%(ext)s`" --restrict-filenames `"$($Url)`""

        # Log the command for visibility
        Write-Host "Executing yt-dlp command to download MP3:"
        Write-Host "$($ytDlpCommand)" -ForegroundColor Cyan

        try {
            # Execute the yt-dlp command
            Invoke-Expression $ytDlpCommand
            if ($LASTEXITCODE -ne 0) {
                Write-Host "Error: yt-dlp command failed with exit code $($LASTEXITCODE)" -ForegroundColor Red
                exit $LASTEXITCODE
            } else {
                Write-Host "MP3 downloaded successfully." -ForegroundColor Green
            }
        }
        catch {
            Write-Host "Error: An exception occurred while executing yt-dlp command." -ForegroundColor Red
            Write-Host "$($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
    }

    $COMMAND_VIDEO_TO_PDF {

        # This command expects a local file path in -Url
        if (!(Test-Path $Url)) {
            Write-Host "Error: The specified video file '$Url' does not exist." -ForegroundColor Red
            exit 1
        }
        $videoFile = $Url
        # Use the current directory for output files
        $outputFolder = (Get-Location).Path

        # Get the valid font path using the cross-platform function
        $fontPath = Get-FFmpegFontPath -FontName "Arial"
        if (-not $fontPath) {
            Write-Host "Error: Could not locate a valid font file for Arial. ('$($fontPath)')" -ForegroundColor Red
            exit 1
        }


        # Build the ffmpeg command as an array and join the elements.
        # This command uses scene detection and the drawtext filter with:
        # - Font: Arial (letting ffmpeg search for it by name)
        # - Text: timestamp in hh:mm:ss format
        # - Black font, white background, and 20px padding
        $ffmpegCmdArray = @(
            "ffmpeg",
            "-i",
            "`"$($videoFile)`"",
            "-vf",
            "`"select='gt(scene,0.4)',drawtext=fontfile=$($fontPath):text='%{pts\:hms}':x=10:y=10:fontsize=24:fontcolor=black:box=1:boxcolor=white@1.0:boxborderw=20`"",
            "-vsync",
            "vfr",
            "-q:v",
            "2",
            "`"$($outputFolder)\slide_%03d.jpg`""
        )
        $ffmpegCmd = $ffmpegCmdArray -join " "

        Write-Host "Executing ffmpeg command to extract slides with timestamps:" -ForegroundColor Cyan
        Write-Host "$($ffmpegCmd)" -ForegroundColor Cyan

        try {
            Invoke-Expression $ffmpegCmd
            if ($LASTEXITCODE -ne 0) {
                Write-Host "Error: ffmpeg command failed with exit code $($LASTEXITCODE)" -ForegroundColor Red
                exit $LASTEXITCODE
            } else {
                Write-Host "Frames extracted successfully." -ForegroundColor Green
            }
        }
        catch {
            Write-Host "Error: An exception occurred while executing ffmpeg command." -ForegroundColor Red
            Write-Host "$($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }

        # Convert the extracted images into a single PDF using ImageMagick
        $pdfOutput = Join-Path $outputFolder "slides.pdf"
        $convertCmd = "magick convert `"$($outputFolder)\slide_*.jpg`" `"$($pdfOutput)`""
        Write-Host "Executing ImageMagick command to convert images to PDF:" -ForegroundColor Cyan
        Write-Host "$($convertCmd)" -ForegroundColor Cyan

        try {
            Invoke-Expression $convertCmd
            if ($LASTEXITCODE -ne 0) {
                Write-Host "Error: ImageMagick convert command failed with exit code $($LASTEXITCODE)" -ForegroundColor Red
                exit $LASTEXITCODE
            } else {
                Write-Host "PDF created successfully: $($pdfOutput)" -ForegroundColor Green
            }
        }
        catch {
            Write-Host "Error: An exception occurred while executing ImageMagick command." -ForegroundColor Red
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
