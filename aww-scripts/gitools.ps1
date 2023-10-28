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

"@

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


    Default {
        Write-Host $("=" * 80) -ForegroundColor Red
        Write-Host "Unknown command: $Command" -ForegroundColor Red
        Write-Host $("=" * 80) -ForegroundColor Red
        Write-Host $HELP_MESSAGE
        exit 1
    }
}

Write-Host "Done: $(Get-Date -Format o)"
