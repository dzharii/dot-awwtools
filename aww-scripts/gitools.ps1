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
$COMMAND_DIFF_ALL_UNPUSHED = "diff-all-unpushed-changes"
$COMMAND_REMOVE_UNTRACKED = "remove-untracked"
$COMMAND_COPY_TO_CLIPBOARD_CURRENT_CHANGES_DIFF = "copy-to-clipboard-current-changes-diff"

# inspired by yt/uFrPgUjv_Y8  ; Enrico Campidoglio
$COMMAND_PRETTY_LOG = "pretty-log"
$COMMAND_WHAT_CHANGES_ARE_NEW = "what-changes-are-new-in-my-branch"
$COMMAND_WHAT_CHANGES_ARE_IN_MASTER_NOT_MY_BRANCH = "what-changes-are-in-master-but-not-in-my-branch"
$COMMAND_MOVE_FILES_TO_OTHER_BRANCH = "move-files-to-other-branch"
$COMMAND_CHECKOUT_PR = "checkout-pr"
$COMMAND_SHALLOW_CLONE = "shallow-clone"


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

    $($COMMAND_DIFF_ALL_UNPUSHED):
      Shows a unified diff of all uncommitted changes (both staged and unstaged) compared to the last commit.

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

    $($COMMAND_SHALLOW_CLONE) <repo_url> [<target_name>]:
      Clones a repo with depth 1, single-branch, and no tags.
      If <target_name> is omitted, it uses <owner>__<repo> derived from the URL.
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

function Test-RepoLike {
    param(
        [string]$value
    )

    if (-not $value) { return $false }
    return ($value -match "^[a-zA-Z][a-zA-Z0-9+.-]*://") -or ($value -match "^[^\\s@]+@[^\\s:]+:")
}

function Get-ShallowCloneTargetName {
    param(
        [string]$repoUrl
    )

    if (-not $repoUrl) { return $null }

    $clean = $repoUrl.Trim()
    $clean = $clean -replace "\\", "/"
    $clean = $clean -replace "/+$", ""
    $clean = $clean -replace "\.git$", ""
    $clean = $clean -replace ":", "/"

    $segments = $clean -split "/"
    $segments = $segments | Where-Object { $_ -ne "" }

    if ($segments.Count -ge 2) {
        return "$($segments[-2])__$($segments[-1])"
    }

    if ($segments.Count -eq 1) {
        return $segments[0]
    }

    return $null
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

    $COMMAND_DIFF_ALL_UNPUSHED {
        # Display all uncommitted changes in the working directory and staging area
        git diff HEAD
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

            Write-Host "Step 4: Checking out main branch and updating." -ForegroundColor Cyan
            git checkout $mainBranch
            git pull
            Write-Host "  '$mainBranch' is up to date." -ForegroundColor Green

            Write-Host "Step 5: Checking changes in PR branch '$prBranch'." -ForegroundColor Cyan
            git diff --name-status --merge-base `"$mainBranch`" `"$prBranch`"

            Write-Host "Step 6: Patching $mainBranch with new changes from $prBranch" -ForegroundColor Cyan

            $patchCommandlineScriptWindows = "$ThisScriptFolderPath/gitools-git-apply-patch-pr-to-main-windows.cmd"

            & $patchCommandlineScriptWindows $mainBranch $prBranch
            if ($LASTEXITCODE -ne 0) { throw "git apply failed." }

            Write-Host "=== checkout-pr completed for '$prBranch' ===" -ForegroundColor Cyan
        }
        catch {
            Write-Host "Error in checkout-pr: $_" -ForegroundColor Red
            exit 1
        }
    }

    $COMMAND_SHALLOW_CLONE {
        $repoUrl = $null
        $targetName = $null

        if ($PSBoundParameters.ContainsKey('Name')) {
            $repoUrl = $Name
            if ($args.Count -gt 0) { $targetName = $args[0] }

            if ($targetName -and -not (Test-RepoLike -value $repoUrl) -and (Test-RepoLike -value $targetName)) {
                $repoUrl = $targetName
                $targetName = $Name
            }
        } elseif ($args.Count -gt 0) {
            $repoUrl = $args[0]
            if ($args.Count -gt 1) { $targetName = $args[1] }
        }

        if (-not $repoUrl) {
            Write-Host "Error: <repo_url> is required for '$COMMAND_SHALLOW_CLONE'." -ForegroundColor Red
            exit 1
        }

        if (-not $targetName) {
            $targetName = Get-ShallowCloneTargetName -repoUrl $repoUrl
        }

        if (-not $targetName) {
            Write-Host "Error: Unable to derive a target name from '$repoUrl'. Provide <target_name> explicitly." -ForegroundColor Red
            exit 1
        }

        Write-Host "Shallow cloning '$repoUrl' into '$targetName'..." -ForegroundColor Cyan
        git clone --depth 1 --single-branch --no-tags $repoUrl $targetName
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
