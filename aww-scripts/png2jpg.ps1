# convert-png-to-jpg.ps1
# Converts PNG files in the current directory to JPEG.
# Skips files when the matching .jpg already exists.

$ErrorActionPreference = "Stop"

$MagickCommand = "magick"
$JpegQuality = 95

function Wait-ForUserToRead {
    Write-Host ""
    Write-Host "Press Enter after reading the instructions..." -ForegroundColor Yellow
    [void][System.Console]::ReadLine()
}

function Assert-ImageMagickAvailable {
    $magick = Get-Command $MagickCommand -ErrorAction SilentlyContinue

    if ($null -ne $magick) {
        Write-Host "ImageMagick found: $($magick.Source)" -ForegroundColor Green
        return
    }

    Write-Host ""
    Write-Host "ImageMagick was not found." -ForegroundColor Red
    Write-Host ""
    Write-Host "The command 'magick' is not available in this PowerShell session."
    Write-Host "Install ImageMagick, then close and reopen PowerShell so PATH is refreshed."
    Write-Host ""
    Write-Host "Option 1 - install with winget:" -ForegroundColor Cyan
    Write-Host "winget install -e --id ImageMagick.ImageMagick" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Option 2 - install from the official ImageMagick download page:" -ForegroundColor Cyan
    Write-Host "https://imagemagick.org/download/#gsc.tab=0" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Winget package page:" -ForegroundColor Cyan
    Write-Host "https://winget.run/pkg/ImageMagick/ImageMagick" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "After installation, verify it with:" -ForegroundColor Cyan
    Write-Host "magick -version" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "If ImageMagick is installed but this script still cannot find it, restart PowerShell."
    Write-Host "If that does not work, check that the ImageMagick install directory is in your PATH."

    Wait-ForUserToRead

    throw "Cannot continue because ImageMagick command 'magick' is missing."
}

Assert-ImageMagickAvailable

Get-ChildItem -Path . -File -Filter "*.png" | Sort-Object Name | ForEach-Object {
    $pngPath = $_.FullName
    $jpgPath = [System.IO.Path]::ChangeExtension($pngPath, ".jpg")

    if (Test-Path -LiteralPath $jpgPath) {
        Write-Host "SKIPPED: $pngPath" -ForegroundColor DarkYellow
        return
    }

    $displayCommand = "magick `"$pngPath`" -background white -alpha remove -alpha off -quality $JpegQuality `"$jpgPath`""

    Write-Host ""
    Write-Host "EXECUTING:" -ForegroundColor Cyan
    Write-Host $displayCommand -ForegroundColor Magenta

    & $MagickCommand `
        $pngPath `
        -background white `
        -alpha remove `
        -alpha off `
        -quality $JpegQuality `
        $jpgPath

    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAILED: $pngPath" -ForegroundColor Red
        return
    }

    Write-Host "CREATED: $jpgPath" -ForegroundColor Green
}