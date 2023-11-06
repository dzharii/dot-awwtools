param(
    [Parameter(Mandatory=$true)]
    [string]$Command
)

$ErrorActionPreference = "Stop"
$ThisScriptFolderPath = Split-Path -Parent $MyInvocation.MyCommand.Definition

$COMMAND_HELP = "help"
$COMMAND_SHOW_GIT_CHANGES = "show-git-changes"
$COMMAND_DIFF_FROM_MASTER = "diff-from-master"
$COMMAND_DIFF_FROM_MAIN = "diff-from-main"
$COMMAND_REMOVE_UNTRACKED = "remove-untracked"

# inspired by yt/uFrPgUjv_Y8  ; Enrico Campidoglio
$COMMAND_PRETTY_LOG = "pretty-log"
$COMMAND_WHAT_CHANGES_ARE_NEW = "what-changes-are-new-in-my-branch"
$COMMAND_WHAT_CHANGES_ARE_IN_MASTER_NOT_MY_BRANCH = "what-changes-are-in-master-but-not-in-my-branch"


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

    $($COMMAND_PRETTY_LOG):
      Displays a pretty log of commits with decorations and relative dates.
      Example output, (but will be colorful!):

    $($COMMAND_WHAT_CHANGES_ARE_NEW):
      Shows commits that are new in your current branch which are not in the main branch (master/main).

    $($COMMAND_WHAT_CHANGES_ARE_IN_MASTER_NOT_MY_BRANCH):
      Shows commits that are in the main branch (master/main) but not in your current branch.
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

    $COMMAND_REMOVE_UNTRACKED {
        Write-Host "Removing all untracked files and directories..." -ForegroundColor Yellow

        # Removing untracked files and directories
        git clean -fd

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



    Default {
        Write-Host $("=" * 80) -ForegroundColor Red
        Write-Host "Unknown command: $Command" -ForegroundColor Red
        Write-Host $("=" * 80) -ForegroundColor Red
        Write-Host $HELP_MESSAGE
        exit 1
    }
}

Write-Host "Done: $(Get-Date -Format o)"
