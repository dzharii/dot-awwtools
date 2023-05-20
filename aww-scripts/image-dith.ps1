$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
$clipboard = [System.Windows.Forms.Clipboard]::GetImage()

if ($null -ne $clipboard) {
    $tempFile = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "clipboard.png")
    $ditheredFile = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "dithered.png")

    $clipboard.Save($tempFile, [System.Drawing.Imaging.ImageFormat]::Png)

    # & magick convert "$tempFile" -dither Riemersma -colors 256 "$ditheredFile"
    & magick convert "$tempFile" -dither Riemersma -colors 16 -mattecolor "#704214" -frame 10x10 "$ditheredFile"

    # Load the dithered image
    $ditheredImage = [System.Drawing.Image]::FromFile($ditheredFile)

    # Copy the dithered image to clipboard
    [System.Windows.Forms.Clipboard]::SetImage($ditheredImage)

    # Dispose image to free up resources
    $ditheredImage.Dispose()

    # Optionally delete temp files
    Remove-Item $tempFile
    Remove-Item $ditheredFile
}
else {
    Write-Host "No image data found on the clipboard."
}
