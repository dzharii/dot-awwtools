param (
    [string]$Path = ".",
    [string]$Output = "output.md"
)

$ErrorActionPreference = "Stop"

# $host.ui.RawUI.WindowTitle = "My Title"
$ThisScriptFolderPath = Split-Path -Parent $MyInvocation.MyCommand.Definition


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

)

$files = Get-ChildItem -Path $Path -Include $extensions -Recurse


"Files: $files"

$markdown = ""

foreach ($file in $files) {
    $markdown += "## $($file.Name)`n`n"
    $markdown += "``````$($file.Extension.Substring(1))`n"
    $markdown += Get-Content $file.FullName -Raw
    $markdown += "`n``````"
    $markdown += "`n`n"
}

$markdown | Out-File $Output -Encoding utf8

