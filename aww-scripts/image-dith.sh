#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status
set -o pipefail  # The return value of a pipeline is the status of the last command to exit with a non-zero status

# Check if xclip is installed
if ! command -v xclip &> /dev/null; then
    echo "xclip is not installed. Please install it using your package manager."
    exit 1
fi

echo "xclip is installed. Proceeding..."

# Define the output paths
rawImageOut="$HOME/tmp/clipboard.png"
dithImageOut="$HOME/tmp/dithered.png"

echo "rawImageOut='$rawImageOut'"
echo "dithImageOut='$dithImageOut'"

# Ensure the output directory exists
mkdir -p "$(dirname "$rawImageOut")"

# Copy the clipboard content to a temporary file
echo "Saving clipboard content to $rawImageOut"
xclip -selection clipboard -t image/png -o > "$rawImageOut"

# Check if the clipboard content was saved correctly
if [ ! -s "$rawImageOut" ]; then
    echo "No image data found on the clipboard or failed to save the clipboard content."
    exit 1
fi

echo "Image saved successfully. File path: $rawImageOut"

# Use ImageMagick to dither and manipulate the image
echo "Executing ImageMagick command"
convert "$rawImageOut" -dither Riemersma -colors 16 -mattecolor "#704214" -frame 10x10 "$dithImageOut"

# Check if the dithered image was created successfully
if [ ! -f "$dithImageOut" ]; then
    echo "Failed to create dithered image. The file $dithImageOut was not created."
    exit 1
fi

echo "Dithered image created successfully. File path: $dithImageOut"

# Copy the dithered image back to the clipboard
echo "Copying dithered image to clipboard"
xclip -selection clipboard -t image/png -i < "$dithImageOut"
echo "Dithered image copied to clipboard successfully."

# Optionally delete temp files
echo "Removing temporary files."
rm -f "$rawImageOut" "$dithImageOut"

echo "Script execution completed."
exit 0