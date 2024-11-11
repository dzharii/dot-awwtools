param(
    [Parameter(Mandatory=$true)]
    [string]$Command
)

$ErrorActionPreference = "Stop"
$ThisScriptFolderPath = Split-Path -Parent $MyInvocation.MyCommand.Definition

$COMMAND_HELP = "help"
$COMMAND_CHECK_REPOS = "check-repos"
$COMMAND_COMMIT_AND_PUSH = "commit-and-push"

$REPO_PATH = @(
    "C:\Home\my-github\aww-hudini"
    "C:\Home\my-github\awwlib-cpp"
    "C:\Home\my-github\awwtools"
    "C:\Home\my-github\dz-private-notes"
    "C:\Home\my-github\dzharii.github.io"
    "C:\Home\my-github\personal-blog-dmytro.zharii.com"
    "C:\Home\my-github\toys-awwtools-com"
    "C:\Home\my-github\w311-2024"
    "C:\Users\home\.awwtools"
    "C:\Home\my-gogs\me"
    "C:\Home\my-gogs\public-keys"
    "C:\Home\my-gogs\shared-notes"
)

$HELP_MESSAGE = @"
Usage:
   gitools.ps1 <command>
   gitools.cmd <command>

Commands:
    $($COMMAND_HELP):
      Shows this help message
    $($COMMAND_CHECK_REPOS):
      Checks the repository paths for uncommitted changes
    $($COMMAND_COMMIT_AND_PUSH):
      Commit and push uncommitted changes for each repository
"@

function Check-Repositories {
    param (
        [switch]$OnlyUncommitted
    )
    $report = @()
    foreach ($repo in $REPO_PATH) {
        if (Test-Path -Path $repo) {
            if (Test-Path -Path (Join-Path -Path $repo -ChildPath ".git")) {
                try {
                    $status = git -C $repo status --porcelain
                    if ($status) {
                        $report += [PSCustomObject]@{
                            Repository = $repo
                            Status = "Has uncommitted changes"
                        }
                    } elseif (-not $OnlyUncommitted) {
                        $report += [PSCustomObject]@{
                            Repository = $repo
                            Status = "Does not have uncommitted changes"
                        }
                    }
                } catch {
                    $report += [PSCustomObject]@{
                        Repository = $repo
                        Status = "Error: $($_.Exception.Message)"
                    }
                }
            } else {
                $report += [PSCustomObject]@{
                    Repository = $repo
                    Status = "Not a git repository (.git folder not found)"
                }
            }
        } else {
            $report += [PSCustomObject]@{
                Repository = $repo
                Status = "Path does not exist"
            }
        }
    }
    return $report
}

function Display-Report {
    param (
        [array]$Report
    )
    $tableBorder = "=" * 80
    Write-Host $tableBorder -ForegroundColor Yellow
    Write-Host "Repository Status Report" -ForegroundColor Cyan
    Write-Host $tableBorder -ForegroundColor Yellow
    $Report | ForEach-Object {
        $statusColor = if ($_.Status -eq "Has uncommitted changes") { "Red" } elseif ($_.Status -eq "Does not have uncommitted changes") { "Green" } else { "Yellow" }
        if ($_.Status -eq "Has uncommitted changes") {
            Write-Host ("{0,-60} {1}" -f $_.Repository, $_.Status) -ForegroundColor Yellow -BackgroundColor Black
        } elseif ($_.Status -like "Error:*") {
            Write-Host ("{0,-60} {1}" -f $_.Repository, $_.Status) -ForegroundColor LightRed -BackgroundColor Black
        } else {
            Write-Host ("{0,-60} {1}" -f $_.Repository, $_.Status) -ForegroundColor $statusColor
        }
    }
    Write-Host $tableBorder -ForegroundColor Yellow
}

switch ($Command.ToLower()) {
    $COMMAND_HELP {
        Write-Host $HELP_MESSAGE
    }

    $COMMAND_CHECK_REPOS {
        $report = Check-Repositories -OnlyUncommitted:$false
        Display-Report -Report $report
    }

    $COMMAND_COMMIT_AND_PUSH {
        $report = Check-Repositories -OnlyUncommitted:$true
        foreach ($item in $report) {
            if ($item.Status -eq "Has uncommitted changes") {
                $response = Read-Host "Do you want to commit changes to '$($item.Repository)'? (Y/N) [Default: N]"
                if ($response -eq "Y" -or $response -eq "y") {
                    Push-Location
                    Set-Location -Path $item.Repository
                    try {
                        & aww run git-push
                    } catch {
                        Write-Host "Error during commit and push for '$($item.Repository)': $($_.Exception.Message)" -ForegroundColor LightRed -BackgroundColor Black
                    }
                    Pop-Location
                }
            }
        }
        # Re-run the check and display the final report
        $finalReport = Check-Repositories -OnlyUncommitted:$false
        Display-Report -Report $finalReport
    }

    Default {
        Write-Host $("=" * 80) -ForegroundColor Red
        Write-Host "Unknown command: $Command" -ForegroundColor Red
        Write-Host $("=" * 80) -ForegroundColor Red
        Write-Host $HELP_MESSAGE
        exit 1
    }
}

Write-Host "Done: $(Get-Date -Format o)"
