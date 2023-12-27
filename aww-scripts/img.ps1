# Re-saves image back to clipboard, so the new image will lose some incorrect
# meta information like file name. This fixes the issue with typora 07/11/2023
# when it takes the file name from uygly ADO url.
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
$clipboard = [System.Windows.Forms.Clipboard]::GetImage()

if ($null -ne $clipboard) {
   # Copy image back to clipboard
   [System.Windows.Forms.Clipboard]::SetImage($clipboard)
}
else {
    Write-Host "No image data found on the clipboard."
}
