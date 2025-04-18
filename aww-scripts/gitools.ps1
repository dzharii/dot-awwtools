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

function Set-BranchNoPushConfig {
    param(
        [string]$branchName
    )
    
    # Configure this branch to be non-pushable
    git config branch.$($branchName).pushRemote "no_push"
    git config branch.$($branchName).remote "no_remote"
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
        if (-not $PSBoundParameters.ContainsKey('Name')) {
            Write-Host "Error: The -Name parameter is required for the '$($COMMAND_CHECKOUT_PR)' command." -ForegroundColor Red
            Write-Host "Usage: gitools.ps1 $($COMMAND_CHECKOUT_PR) -Name <branch_name>" -ForegroundColor Yellow
            exit 1
        }

        $prBranch = $Name
        Write-Host "Preparing to review PR from branch: $($prBranch)" -ForegroundColor Cyan
        
        try {
            # Step 1: Ensure we have a clean working directory
            Write-Host "Checking working directory status..." -ForegroundColor Cyan
            Ensure-CleanWorkingDirectory

            # Step 2: Fetch latest changes to ensure we have the branch
            Write-Host "Fetching latest changes from remote..." -ForegroundColor Cyan
            git fetch
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to fetch from remote. Please check your network connection and try again."
            }

            # Step 3: Check if the PR branch exists
            $branchExists = git show-ref --verify --quiet refs/heads/$prBranch
            $remoteBranchExists = git show-ref --verify --quiet refs/remotes/origin/$prBranch
            
            if ($LASTEXITCODE -ne 0 -and $remoteBranchExists -ne 0) {
                throw "PR branch '$($prBranch)' doesn't exist locally or remotely. Please verify the branch name."
            }

            # Step 4: Determine main branch (master or main)
            $mainBranch = Get-MasterOrMainBranchName
            if ($null -eq $mainBranch) {
                throw "Unable to determine the main branch (master/main). Repository structure may be non-standard."
            }

            # Step 5: Make sure main branch is up to date
            Write-Host "Updating $($mainBranch) branch..." -ForegroundColor Cyan
            git checkout $mainBranch
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to checkout $($mainBranch) branch."
            }
            
            git pull
            if ($LASTEXITCODE -ne 0) {
                Write-Host "Warning: Failed to pull latest changes for $($mainBranch). Continuing with local version." -ForegroundColor Yellow
            }

            Write-Host "Checkout to prBranch='$($prBranch)'" -ForegroundColor Cyan
            git checkout -b "$($prBranch)"
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to create checkout branch '$($prBranch)'."
            }

            # Step 7: Configure the branch to prevent accidental pushing
            Write-Host "Configuring branch to prevent accidental publishing..." -ForegroundColor Cyan
            Set-BranchNoPushConfig -branchName $prBranch

            # Step 8: Unstage changed files since the branch has created
            Write-Host "Unstaging changed" -ForegroundColor Cyan
            git reset --mixed (& git merge-base origin/$($mainBranch) HEAD)
        }
        catch {
            Write-Host "Error: $_" -ForegroundColor Red
            Write-Host "Operation failed. Attempting to restore previous state..." -ForegroundColor Red
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
