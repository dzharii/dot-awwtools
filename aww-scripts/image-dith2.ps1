DOES NOT WORK :(

$ErrorActionPreference = "Stop"

# Check if xclip is installed
if (Test-Path /usr/bin/xclip) {
    # Copy the clipboard content to a temporary file
    xclip -selection clipboard -t image/png -o > /tmp/clipboard.png

    # Check if the file exists and is not empty
    if ((Test-Path -Path "/tmp/clipboard.png") -and (Get-Item "/tmp/clipboard.png").Length -gt 0) {
        $tempFile = "/tmp/clipboard.png"
        $ditheredFile = "/tmp/dithered.png"

        # Use ImageMagick to dither and manipulate the image (you need to have ImageMagick installed)
        & convert "$tempFile" -dither Riemersma -colors 16 -mattecolor "#704214" -frame 10x10 "$ditheredFile"

        # Copy the dithered image back to the clipboard using xclip
        xclip -selection clipboard -t image/png -i "$ditheredFile"

        # Optionally delete temp files
        Remove-Item $tempFile
        Remove-Item $ditheredFile
    }
    else {
        Write-Host "No image data found on the clipboard."
    }
}
else {
    Write-Host "xclip is not installed. Please install it using your package manager."
}
