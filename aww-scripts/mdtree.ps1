param (
    [string]$Path = ".",
    [string]$Output = "output.md"
)

$ErrorActionPreference = "Stop"

# $host.ui.RawUI.WindowTitle = "My Title"
$ThisScriptFolderPath = Split-Path -Parent $MyInvocation.MyCommand.Definition

function Format-MarkdownCodeBlock($content, $type) {
    $result = "``````$type`n"
    $result += $content
    $result += "`n``````"
    return $result
}


$extensions = @(
    "*.scala"
    "*.json"
    "*.sh"
    "*.ps1"
    "*.h"
    "*.hpp"
    "*.c"
    "*.cpp"
    "*.cxx"

    "*.rplc"
    "*.rpli"
    "*.xml"
    "*.ini"
    "*.md"
)

$files = Get-ChildItem -Path $Path -Include $extensions -Recurse


$markdown = ""

foreach ($file in $files) {
    Write-Host "Processing:`n - $($file.FullName)"

    $fileContent = Get-Content $file.FullName -Raw
    $fileExtension = $file.Extension.Substring(1)

    $markdown += "## $($file.Name)`n`n"

    if ($fileExtension -eq "md") {
        $markdown += $fileContent
    } else {
        $markdown += Format-MarkdownCodeBlock $fileContent $fileExtension
    }
    $markdown += "`n`n"
}

$markdown | Out-File $Output -Encoding utf8

