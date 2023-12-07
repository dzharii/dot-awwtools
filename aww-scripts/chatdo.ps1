
$ErrorActionPreference = "Stop"
# $host.ui.RawUI.WindowTitle = "My Title"
$ThisScriptFolderPath = Split-Path -Parent $MyInvocation.MyCommand.Definition

Add-Type -AssemblyName System.Windows.Forms

# Read data from the clipboard
$clipboardText = [Windows.Forms.Clipboard]::GetText()

# Split the clipboard content into lines
$lines = $clipboardText -split "`n"

# Validate the first line starts with "__FILE::"
if (-not $lines[0].StartsWith("__FILE::")) {
    throw "Clipboard content does not start with '__FILE::'"
}

$currentFilePath = $null
$fileContent = New-Object System.Text.StringBuilder

foreach ($line in $lines) {
    $line.Trim()
    if ($line.StartsWith("__FILE::")) {
        # Write previous file content to file
        if ($null -ne $currentFilePath) {
            $fullPath = [System.IO.Path]::GetFullPath($currentFilePath)
            $directory = [System.IO.Path]::GetDirectoryName($fullPath)

            # Create directory if it doesn't exist
            if (-not (Test-Path $directory)) {
                New-Item -ItemType Directory -Path $directory -Force | Out-Null
            }

            # Write content to file
            [System.IO.File]::WriteAllText($fullPath, $fileContent.ToString())

            # Reset StringBuilder
            $fileContent.Clear()
        }

        # Update current file path
        $currentFilePath = $line -replace '__FILE::', ''
        Write-Host "Processing file: $($currentFilePath)"
    } else {
        # Append line to current file content
        $fileContent.AppendLine($line)
    }
}

# Write the last file's content
if ($null -ne $currentFilePath) {
    Write-Host "Processing file: $($currentFilePath)"
    $fullPath = [System.IO.Path]::GetFullPath($currentFilePath)
    $directory = [System.IO.Path]::GetDirectoryName($fullPath)

    # Create directory if it doesn't exist
    if (-not (Test-Path $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    # Write content to file
    [System.IO.File]::WriteAllText($fullPath, $fileContent.ToString())
    Write-Host "Final file processed: $($currentFilePath)"
}

Write-Host "Script execution completed."




