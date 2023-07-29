param (
    [string]$Path = ".",
    [string]$FilterPath = "",
    [string]$FilterName = "",
    [string]$Output = "output.md"
)

$ErrorActionPreference = "Stop"

Add-Type -TypeDefinition @"
using System.Text.RegularExpressions;

public class RegexFileFilter
{
    private Regex _regex;

    public RegexFileFilter(string pattern)
    {
        _regex = string.IsNullOrWhiteSpace(pattern) ? null : new Regex(pattern);
    }

    public bool ShouldKeepFile(string fileFullName)
    {
        return _regex == null ? true : _regex.IsMatch(fileFullName);
    }
}
"@

# Create a new instance of the C# class with the provided filter
$pathFilterRegexp = New-Object RegexFileFilter($FilterPath)
$nameFilterRegexp = New-Object RegexFileFilter($FilterName)




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
    if (-not $pathFilterRegexp.ShouldKeepFile($file.FullName)) {
        Write-Host "Skipping pathFilterRegexp:`n - $($file.FullName)"
        continue
    }

    if (-not $nameFilterRegexp.ShouldKeepFile($file.Name)) {
        Write-Host "Skipping: nameFilterRegexp`n - $($file.FullName)"
        continue
    }

    Write-Host "Processing:`n - $($file.FullName)"

    $fileContent = Get-Content $file.FullName -Raw
    $fileExtension = $file.Extension.Substring(1)

    $relativePath = $file.FullName.Replace((Resolve-Path $Path).Path + '\', '')
    $markdown += "## $($relativePath)`n`n"

    if ($fileExtension -eq "md") {
        $markdown += $fileContent
    } else {
        $markdown += Format-MarkdownCodeBlock $fileContent $fileExtension
    }
    $markdown += "`n`n"
}

$markdown | Out-File $Output -Encoding utf8

