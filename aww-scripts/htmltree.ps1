param (
    [string]$Path = ".",
    [string]$Output = "output.html"
)

$ErrorActionPreference = "Stop"

$ThisScriptFolderPath = Split-Path -Parent $MyInvocation.MyCommand.Definition

function Format-HtmlCodeBlock($content, $type) {
    $encodedContent = [System.Net.WebUtility]::HtmlEncode($content)
    $result = "<pre><code class=`"$type`">`n"
    $result += $encodedContent
    $result += "`n</code></pre>"
    return $result
}

$extensions = @(
    "*.scala",
    "*.json",
    "*.sh",
    "*.ps1",
    "*.rplc",
    "*.rpli",
    "*.xml",
    "*.ini",
    "*.md"
)

$files = Get-ChildItem -Path $Path -Include $extensions -Recurse

$html = @"
<!DOCTYPE html>
<html>
<head>
    <style>
	$( Get-Content "$($ThisScriptFolderPath)\assets-htmltree\github-markdown-css\github-markdown.css" -Raw)
    </style>
</head>
<body class="markdown-body">
"@

foreach ($file in $files) {
    Write-Host "Processing:`n - $($file.FullName)"

    $fileContent = Get-Content $file.FullName -Raw
    $fileExtension = $file.Extension.Substring(1)

    $html += "<h2>$($file.FullName)</h2>`n"

    $html += Format-HtmlCodeBlock $fileContent $fileExtension
    $html += "`n`n"
}

$html += @"
</body>
</html>
"@

$html | Out-File $Output -Encoding utf8
