$ErrorActionPreference = "Stop"

$appFile = 'index.html'
$myPath = $MyInvocation.MyCommand.Path
$myDirectory = Split-Path $myPath -Parent

$appFilePath = Join-Path -Path $myDirectory -ChildPath "assets-pasty"
$appFilePath = Join-Path -Path  $appFilePath -ChildPath $appFile
$appUriPath = (New-Object System.Uri("$appFilePath")).AbsoluteUri
$uriPath.AbsoluteUri
$urlArgs = [System.String]::Join(" ", $args)

$completeUrl = "`"${appUriPath}?q=${urlArgs}`""
Start-Process msedge $completeUrl
