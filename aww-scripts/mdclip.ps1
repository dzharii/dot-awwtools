$Files = $args
Write-Host $Files

# Set ErrorActionPreference to Stop for robust error handling
$ErrorActionPreference = 'Stop'

$BT = "``"
$BT3 = "$($BT)$($BT)$($BT)"


# Initialize a variable to store the final Markdown output
$MarkdownOutput = ""

# Define a mapping of file extensions to Markdown code block languages
$ExtensionToLanguageMap = @{
    ".txt"  = "txt"
    ".ps1"  = "ps1"
    ".md"   = "md"
    ".json" = "json"
    ".xml"  = "xml"
    ".html" = "html"
    ".css"  = "css"
    ".js"   = "javascript"
}

# Begin processing files
foreach ($File in $Files) {
    Write-Host "Processing file: $($File)" -ForegroundColor Cyan

    # Check if the file exists
    if (-Not (Test-Path -Path $File)) {
        Write-Host "File not found: $($File)" -ForegroundColor Red
        exit 1
    }

    try {
        # Read the file content
        $FileContent = Get-Content -Path $File -Raw
        Write-Host "Successfully read content of: $($File)" -ForegroundColor Green

        # Extract the file extension and map it to a language
        $FileExtension = [System.IO.Path]::GetExtension($File)
        $CodeLanguage = $ExtensionToLanguageMap[$FileExtension.ToLower()]
        if (-not $CodeLanguage) {
            $CodeLanguage = ""
        }

        # Append the formatted file content to the Markdown output
        $MarkdownOutput += "File $($BT)$($File)$($BT):`n"
        $MarkdownOutput += "$($BT3)$($CodeLanguage)`n"
        $MarkdownOutput += "$($FileContent)`n"
        $MarkdownOutput += "$($BT3)" + "`n`n"

    } catch {
        Write-Host "Error reading file: $($File). Error: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# Check if any content was generated
if ($MarkdownOutput) {
    # Copy the Markdown output to the clipboard using Set-Clipboard
    $MarkdownOutput | Set-Clipboard
    Write-Host "Markdown text copied to clipboard successfully." -ForegroundColor Green
} else {
    Write-Host "No content to copy. Ensure the specified files exist and are readable." -ForegroundColor Yellow
}