param(
    [Parameter(Mandatory=$true)]
    [string]$Command,
    [Parameter(Mandatory=$false)]
    [string]$Name
)

$ErrorActionPreference = "Stop"
$ThisScriptFolderPath = Split-Path -Parent $MyInvocation.MyCommand.Definition

$COMMAND_HELP = "help"
$COMMAND_SHOW_GIT_CHANGES = "show-git-changes"
$COMMAND_DIFF_FROM_MASTER = "diff-from-master"
$COMMAND_DIFF_FROM_MAIN = "diff-from-main"
$COMMAND_REMOVE_UNTRACKED = "remove-untracked"
$COMMAND_COPY_TO_CLIPBOARD_CURRENT_CHANGES_DIFF = "copy-to-clipboard-current-changes-diff"

# inspired by yt/uFrPgUjv_Y8  ; Enrico Campidoglio
$COMMAND_PRETTY_LOG = "pretty-log"
$COMMAND_WHAT_CHANGES_ARE_NEW = "what-changes-are-new-in-my-branch"
$COMMAND_WHAT_CHANGES_ARE_IN_MASTER_NOT_MY_BRANCH = "what-changes-are-in-master-but-not-in-my-branch"
$COMMAND_MOVE_FILES_TO_OTHER_BRANCH = "move-files-to-other-branch"
$COMMAND_CHECKOUT_PR = "checkout-pr"


$HELP_MESSAGE = @"
Usage:
   gitools.ps1 <command>
   gitools.cmd <command>

Commands:
    $($COMMAND_HELP):
      Shows this help message

    $($COMMAND_SHOW_GIT_CHANGES):
      Shows full paths of changed files between the current HEAD and origin

    $($COMMAND_DIFF_FROM_MASTER):
      Shows differences between the current branch and master

    $($COMMAND_DIFF_FROM_MAIN):
      Shows differences between the current branch and master

    $($COMMAND_REMOVE_UNTRACKED):
      Removes all untracked files and directories from the repository.

    $($COMMAND_COPY_TO_CLIPBOARD_CURRENT_CHANGES_DIFF):
      Produces a unified diff for all staged changes and copies it to the clipboard.

    $($COMMAND_PRETTY_LOG):
      Displays a pretty log of commits with decorations and relative dates.
      Example output, (but will be colorful!):

    $($COMMAND_WHAT_CHANGES_ARE_NEW):
      Shows commits that are new in your current branch which are not in the main branch (master/main).

    $($COMMAND_WHAT_CHANGES_ARE_IN_MASTER_NOT_MY_BRANCH):
      Shows commits that are in the main branch (master/main) but not in your current branch.

    $($COMMAND_MOVE_FILES_TO_OTHER_BRANCH) -Name <target_branch_name>:
      Moves all staged changes to another branch. The target branch is specified with the -Name parameter.
      If the branch doesn't exist, it will be created.

    $($COMMAND_CHECKOUT_PR) -Name <branch_name>:
      Checks out the specified PR branch and prepares it for review.
      Sets up the changes from the PR as unstaged modifications against the main branch.
      This allows reviewing the exact changes the PR introduces.
"@

function Get-MasterOrMainBranchName {
  $masterExists = git show-ref --verify --quiet refs/heads/master
  if ($LASTEXITCODE -eq 0) {
      return "master"
  }

  $mainExists = git show-ref --verify --quiet refs/heads/main
  if ($LASTEXITCODE -eq 0) {
      return "main"
  }

  return $null
}

function CheckBranchExists {
    param(
        [string]$branchName
    )

    git show-ref --verify --quiet refs/heads/$branchName
    return $LASTEXITCODE -eq 0
}

function Ensure-CleanWorkingDirectory {
    $status = git status --porcelain
    if ($status) {
        throw "Working directory is not clean. Please commit or stash your changes before checking out a PR."
    }
}

switch ($Command.ToLower()) {
    $COMMAND_HELP {
        Write-Host $HELP_MESSAGE
    }

    $COMMAND_SHOW_GIT_CHANGES {
        # Get the root of the git repository
        $repoRoot = git rev-parse --show-toplevel

        # Get the list of changed files
        $changedFiles = git whatchanged --name-only --pretty="" origin..HEAD

        # Display the full path of each changed file
        foreach ($file in $changedFiles) {
            Write-Output "${repoRoot}\${file}"
        }
    }

    $COMMAND_DIFF_FROM_MASTER {
        # Display differences between the current branch and master
        git diff master..
    }

    $COMMAND_DIFF_FROM_MAIN {
        # Display differences between the current branch and master
        git diff main..
    }

    $COMMAND_COPY_TO_CLIPBOARD_CURRENT_CHANGES_DIFF {
        Write-Host "Producing unified diff for all staged changes and copying to clipboard..." -ForegroundColor Cyan
        # Generate a unified diff for staged changes
        $diffString = git diff --cached | Out-String
        if ($diffString.Trim()) {
            # Copy the diff output to the clipboard
            $diffString | Set-Clipboard
            Write-Host $diffString
            Write-Host "Unified diff copied to clipboard." -ForegroundColor Green
        }
        else {
            Write-Host "No staged changes found." -ForegroundColor Yellow
        }
    }

    $COMMAND_REMOVE_UNTRACKED {
        Write-Host "Removing all untracked files and directories..." -ForegroundColor Yellow

        # Removing untracked files and directories
        git clean -fdx

        Write-Host "All untracked files and directories removed." -ForegroundColor Green
    }

    $COMMAND_PRETTY_LOG {
        Write-Host "Displaying a pretty log of commits..." -ForegroundColor Cyan
        # Execute the git pretty log command
        # %C(color): colorize the output
        # %h: abbreviated commit hash
        # %d: ref names, like the --decorate option of git-log
        # %s: subject, the commit message's title/summary
        # %ar: author date, relative to the current time
        # %Creset: reset the color
        git log --pretty='%C(red)%h%Creset %C(yellow)%d%Creset %s %C(cyan)(%ar)%Creset'
    }

    $COMMAND_WHAT_CHANGES_ARE_NEW {
      $mainBranch = Get-MasterOrMainBranchName
      if ($mainBranch -eq $null) {
          throw "Unable to determine the main branch name."
      }

      # Get the list of commits that are new in my branch compared to the main branch
      git log $mainBranch..HEAD
    }

    $COMMAND_WHAT_CHANGES_ARE_IN_MASTER_NOT_MY_BRANCH {
        $mainBranch = Get-MasterOrMainBranchName
        if ($mainBranch -eq $null) {
            throw "Unable to determine the main branch name."
        }

        # Get the list of commits that are in the main branch but not in my branch
        git log HEAD..$mainBranch
    }
    $COMMAND_MOVE_FILES_TO_OTHER_BRANCH {
        if (-not $PSBoundParameters.ContainsKey('Name')) {
            Write-Host "Error: The -Name parameter is required for the 'move-files-to-other-branch' command." -ForegroundColor Red
            exit 1
        }

        Write-Host "Moving staged files to branch: $($Name)" -ForegroundColor Yellow

        try {
            # Stash staged changes
            Write-Host "Stashing staged changes..." -ForegroundColor Cyan
            git stash push -k -m "Temporary stash of staged changes"

            # Check if branch exists, create if not
            if (-not (CheckBranchExists -branchName $Name)) {
                Write-Host "Branch $($Name) does not exist. Creating it..." -ForegroundColor Cyan
                git checkout -b $Name
            } else {
                Write-Host "Branch $($Name) exists. Checking out..." -ForegroundColor Cyan
                git checkout $Name
            }

            # Apply the stash
            Write-Host "Applying stashed changes..." -ForegroundColor Cyan
            git stash apply --index

            # Drop the stash
            Write-Host "Dropping the stash..." -ForegroundColor Cyan
            git stash drop

            Write-Host "Staged changes moved to branch: $($Name)" -ForegroundColor Green
        } catch {
            Write-Host "An error occurred: $_" -ForegroundColor Red
            exit 1
        }
    }

    $COMMAND_CHECKOUT_PR {
        throw "This shit does not work 2025-04-23"
        if (-not $PSBoundParameters.ContainsKey('Name')) {
            Write-Host "Error: -Name <branch_name> is required for '$COMMAND_CHECKOUT_PR'." -ForegroundColor Red
            exit 1
        }

        $prBranch = $Name
        Write-Host "=== checkout-pr: Preparing to review PR branch '$prBranch' ===" -ForegroundColor Cyan
        try {
            Write-Host "Step 1: Validating clean working directory..." -ForegroundColor Cyan
            Ensure-CleanWorkingDirectory
            Write-Host "  Working directory is clean." -ForegroundColor Green

            Write-Host "Step 2: Fetching all remotes..." -ForegroundColor Cyan
            git fetch --all
            if ($LASTEXITCODE -ne 0) { throw "git fetch failed." }
            Write-Host "  Fetch completed." -ForegroundColor Green

            $mainBranch = Get-MasterOrMainBranchName
            Write-Host "Step 3: Using main branch '$mainBranch'." -ForegroundColor Cyan

            Write-Host "Step 4: Checking out main branch and updating..." -ForegroundColor Cyan
            git checkout $mainBranch
            git pull --no-edit
            Write-Host "  '$mainBranch' is up to date." -ForegroundColor Green

            Write-Host "Step 5: Checking out PR branch '$prBranch'..." -ForegroundColor Cyan
            git checkout $prBranch
            Write-Host "  Switched to branch '$prBranch'." -ForegroundColor Green

            # New Step 6: Compare current branch to main
            Write-Host "Step 6: Listing files changed between 'origin/$mainBranch' and '$prBranch'..." -ForegroundColor Cyan
            Write-Host "  Executing: git diff --name-only origin/$mainBranch..$prBranch" -ForegroundColor Gray
            $rawChanged = git diff --name-only origin/$mainBranch..$prBranch

            if (-not $rawChanged) {
                Write-Host "  No file-level changes detected between origin/$mainBranch and $prBranch." -ForegroundColor Yellow
            } else {
                Write-Host "  Raw changed files:`n$rawChanged" -ForegroundColor Gray

                $filesToUnstage = @()
                foreach ($file in $rawChanged) {
                    $trimmed = $file.Trim()
                    if ($trimmed) {
                        $filesToUnstage += $trimmed
                        Write-Host "    Queued for unstage: $trimmed" -ForegroundColor Cyan
                    }
                }
                Write-Host "  Total files to unstage: $($filesToUnstage.Count)" -ForegroundColor Green

                foreach ($file in $filesToUnstage) {
                    Write-Host "    Unstaging: $file" -ForegroundColor Yellow
                    git reset HEAD -- $file
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "      Successfully unstaged: $file" -ForegroundColor Green
                    } else {
                        Write-Host "      Failed to unstage: $file" -ForegroundColor Red
                    }
                }
            }

            Write-Host "=== checkout-pr completed for '$prBranch' ===" -ForegroundColor Cyan
        }
        catch {
            Write-Host "Error in checkout-pr: $_" -ForegroundColor Red
            exit 1
        }
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
