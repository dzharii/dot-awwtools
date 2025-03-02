# Set error action to stop on errors.
$ErrorActionPreference = "Stop"

# Check if any parameters were provided.
if ($args.Count -eq 0) {
    Write-Host "Error: No file parameters provided. At least one file path is required." -ForegroundColor Red
    exit 1
}

# Define constants to handle Markdown backticks.
# Using [char]96 ensures we get a literal backtick.
$BT = [char]96
$BT3 = "$($BT)$($BT)$($BT)"

# Initialize a variable to accumulate the Markdown content.
$outputContent = ""

# Process each provided file parameter.
for ($i = 0; $i -lt $args.Count; $i++) {
    $currentPath = $args[$i]
    
    # Validate that the path exists and is a file.
    if (-not (Test-Path -Path $currentPath -PathType Leaf)) {
        Write-Host "Error: File not found or is not a file: $($currentPath)" -ForegroundColor Red
        exit 1
    }
    
    # Convert the file path to an absolute path.
    try {
        $absolutePath = (Resolve-Path $currentPath).Path
        Write-Host "Validated and resolved file: $($absolutePath)" -ForegroundColor Green
    }
    catch {
        Write-Host "Error: Failed to resolve path for $($currentPath). Exception: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
    
    # Determine the file extension without the leading dot.
    $extension = [System.IO.Path]::GetExtension($absolutePath)
    if ($extension.StartsWith(".")) {
        $extension = $extension.Substring(1)
    }
    
    # Read the file content with error handling.
    try {
        $fileContent = Get-Content -Path $absolutePath -Raw
    }
    catch {
        Write-Host "Error: Could not read file: $($absolutePath). Exception: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
    
    # Construct the Markdown formatted section for the file.
    $markdownSection = ""
    # Include the absolute path enclosed in backticks.
    $markdownSection += "$($BT)$($absolutePath)$($BT):`n"
    # Opening code fence with the file extension for syntax highlighting.
    $markdownSection += "$($BT3)$($extension)`n"
    # Append the file content.
    $markdownSection += "$($fileContent)`n"
    # Closing code fence.
    $markdownSection += "$($BT3)`n`n"
    
    # Accumulate this section into the overall output.
    $outputContent += $markdownSection
}

# Output the merged Markdown content to stdout.
Write-Host "Merged markdown content:" -ForegroundColor Cyan
Write-Host $outputContent

# Attempt to copy the output to the clipboard.
try {
    $outputContent | Set-Clipboard
    Write-Host "Merged markdown content has been copied to the clipboard." -ForegroundColor Cyan
}
catch {
    Write-Host "Error: Failed to copy to clipboard. Exception: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
