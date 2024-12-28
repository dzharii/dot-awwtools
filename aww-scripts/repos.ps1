param(
    [Parameter(Mandatory=$true)]
    [string]$Command
)

$ErrorActionPreference = "Stop"
$ThisScriptFolderPath = Split-Path -Parent $MyInvocation.MyCommand.Definition

$COMMAND_HELP = "help"
$COMMAND_CHECK_REPOS = "check-repos"
$COMMAND_COMMIT_AND_PUSH = "commit-and-push"

$REPO_PATH = @()

function Try-GetExtraRepos {
    param (
        [array]$REPO_PATH
    )

    # Get current user home directory and hostname
    $currentUserHome = [System.Environment]::GetFolderPath('UserProfile')
    $currentHostName = [System.Net.Dns]::GetHostName().ToUpper()
    $currentHostNameRepos = "{0}_REPOS.ps1" -f $currentHostName
    $repoScriptPath = Join-Path -Path $currentUserHome -ChildPath $currentHostNameRepos

    $reposFunctionHelp = @"
You can define the function Get-RepoPath in the file:
$($currentHostNameRepos) 
as follows: 

#+begin_src lang=ps1

function Get-RepoPath {
   return @(
       "C:\Home\my-github\aww-hudini"
  )
}

#+end_src
"@

    Write-Host "Expected script path to load: '$($repoScriptPath)'" -ForegroundColor Yellow

    # Initialize try-catch block to load external script
    try {
        if (Test-Path -Path $repoScriptPath) {
            Write-Host "Loading script file: '$($repoScriptPath)'" -ForegroundColor Cyan
            # Load the script file
            . $repoScriptPath

            # Ensure that Get-RepoPath is defined in the loaded script
            if (Get-Command -Name Get-RepoPath -ErrorAction SilentlyContinue) {
                Write-Host "Successfully loaded script and found Get-RepoPath function." -ForegroundColor Green
                $extraRepoPaths = Get-RepoPath

                # Check if paths exist and filter out non-existing paths
                $validExtraRepoPaths = @()
                foreach ($repoPath in $extraRepoPaths) {
                    if (Test-Path -Path $repoPath) {
                        $validExtraRepoPaths += $repoPath
                    } else {
                        Write-Host "Repo path does not exist: '$($repoPath)'" -ForegroundColor Red
                    }
                }

                # Merge $REPO_PATH with valid extra repo paths
                $mergedRepoPath = $REPO_PATH + $validExtraRepoPaths | Sort-Object -Unique
                return $mergedRepoPath
            } else {
                Write-Host "The loaded script does not define the required function Get-RepoPath." -ForegroundColor Red
                Write-Host $reposFunctionHelp
            }
        } else {
            Write-Host "Script file not found: '$($repoScriptPath)'" -ForegroundColor Red
            Write-Host $reposFunctionHelp
        }
    } catch {
        Write-Host "An error occurred while trying to load the repository list at Try-GetExtraRepos: $_" -ForegroundColor Red
    }

    return $REPO_PATH
}

# MERGE 
$REPO_PATH = Try-GetExtraRepos -REPO_PATH $REPO_PATH

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
