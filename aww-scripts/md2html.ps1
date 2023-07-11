param(
    [Parameter(Mandatory=$true)]
    [string]$InputMarkdown,
    [Parameter(Mandatory=$false)]
    [string]$OutputHtml = "output.html"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $InputMarkdown)) {
    Write-Error "Input file $InputMarkdown does not exist."
    exit 1
}

if (-not ([System.IO.Path]::GetExtension($InputMarkdown) -eq '.md')) {
    Write-Error "Input file $InputMarkdown is not a markdown file."
    exit 1
}

$ThisScriptFolderPath = Split-Path -Parent $MyInvocation.MyCommand.Definition

if ([string]::IsNullOrEmpty($OutputHtml)) {
    $OutputHtml = [System.IO.Path]::ChangeExtension($InputMarkdown, 'html')
}

# The path to your CSS file
$CssFilePath = Join-Path $ThisScriptFolderPath 'assets-md2html\github-markdown-css\github-markdown.css'

try {
    Write-Host "Converting markdown to HTML..."
    $command = "pandoc -s --css=`"$($CssFilePath)`" -f markdown -t html `"$($InputMarkdown)`" -o `"$($OutputHtml)`""
    Write-Host "Command: $command"
    Invoke-Expression $command | Out-Host

    Write-Host "Conversion successful. Output file is $OutputHtml"
} catch {
    Write-Error "Failed to convert markdown to HTML. Error details: $_"
}
