# Set the path to your FFmpeg executable
$ffmpegPath = "ffmpeg.exe"

# Set the desired screen capture resolution
$screenWidth = 1920
$screenHeight = 1080

# Set the desired output video framerate
$frameRate = 30

# Set the output video codec
$videoCodec = "libx265"

# Set the output video format
$videoFormat = "mp4"

# Set the default output folder
$outputFolder = "D:\FFVideos"

# Create the output folder if it doesn't exist
if (-not (Test-Path $outputFolder)) {
    New-Item -ItemType Directory -Path $outputFolder | Out-Null
}

# Set the output file name
$outputFileName = Join-Path $outputFolder ("screen_capture_$(Get-Date -Format 'yyyyMMdd_HHmmss').mp4")

# Build the FFmpeg command
$ffmpegCommand = @"
$($ffmpegPath) -f gdigrab -framerate $($frameRate) -video_size $($screenWidth)x$($screenHeight) -i desktop -c:v $($videoCodec) -pix_fmt yuv420p -preset ultrafast -crf 25 -threads 0 -tune zerolatency -y $($outputFileName)
"@

# Run the FFmpeg command in a new window
Start-Process -FilePath "cmd.exe" -ArgumentList "/c $ffmpegCommand" -NoNewWindow -Wait

# Set the optimized output file name
$optimizedOutputFileName = Join-Path $outputFolder ("optimized_screen_capture_$(Get-Date -Format 'yyyyMMdd_HHmmss').mp4")

# Build the FFmpeg command for the second pass to optimize the video file using libx265
$optimizeCommand = @"
$($ffmpegPath) -i $($outputFileName) -c:v libx265 -preset medium -crf 28 -c:a copy -movflags +faststart $($optimizedOutputFileName)
"@

# Run the FFmpeg command in a new window for the second pass
Start-Process -FilePath "cmd.exe" -ArgumentList "/c $optimizeCommand" -NoNewWindow -Wait
