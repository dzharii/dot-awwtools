$ErrorActionPreference = "Stop"

# Check if xclip is installed
if (-not (Test-Path /usr/bin/xclip)) {
    throw "xclip is not installed. Please install it using your package manager."
}

Write-Host "xclip is installed. Proceeding..."

$rawImageOut = Join-Path (Resolve-Path "~/tmp") "clipboard.png"
$dithImageOut = Join-Path (Resolve-Path "~/tmp") "dithered.png"

Write-Host "`$rawImageOut='$($rawImageOut)'`n`$dithImageOut='$($dithImageOut)'`n"

# Copy the clipboard content to a temporary file
Write-Host "Saving clipboard content to $rawImageOut"
$copyCommand = "xclip -selection clipboard -t image/png -o > $rawImageOut"
Write-Host "Executing command: $copyCommand"
Invoke-Expression -Command $copyCommand

# Check if the clipboard content was saved correctly
if (-not (Test-Path -Path $rawImageOut) -or (Get-Item $rawImageOut).Length -le 0) {
    throw "No image data found on the clipboard or failed to save the clipboard content."
}

Write-Host "Image saved successfully. File path: $rawImageOut"

# Use ImageMagick to dither and manipulate the image
$convertCommand = "convert $rawImageOut -dither Riemersma -colors 16 -mattecolor #704214 -frame 10x10 $dithImageOut"
Write-Host "Executing command: $convertCommand"
Invoke-Expression -Command $convertCommand

# Check if the dithered image was created successfully
if (-not (Test-Path -Path $dithImageOut)) {
    throw "Failed to create dithered image. The file $dithImageOut was not created."
}

Write-Host "Dithered image created successfully. File path: $dithImageOut"

# Copy the dithered image back to the clipboard
$copyDitheredCommand = "xclip -selection clipboard -t image/png -i $dithImageOut"
Write-Host "Copying dithered image to clipboard. Command: $copyDitheredCommand"
Invoke-Expression -Command $copyDitheredCommand
Write-Host "Dithered image copied to clipboard successfully."

# Optionally delete temp files
Write-Host "Removing temporary files."
Remove-Item $rawImageOut -ErrorAction SilentlyContinue
Remove-Item $dithImageOut -ErrorAction SilentlyContinue

Write-Host "Script execution completed."
