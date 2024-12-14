param(
    [Parameter(Mandatory=$true)]
    [string]$Command
)

## Inspired by:
# https://github.com/ibttf/interview-coder
# An invisible desktop application that will help you pass your technical interviews.

$ErrorActionPreference = "Stop"
$ThisScriptFolderPath = Split-Path -Parent $MyInvocation.MyCommand.Definition

$COMMAND_HELP = "help"

$HELP_MESSAGE = @"
Usage:
   leetcode-cheat.ps1 <command>
   aww run leetcode-cheat <command>

Commands:
    $($COMMAND_HELP):
      Shows this help message

"@

switch ($Command.ToLower()) {
    
    $COMMAND_HELP {
        Write-Host $HELP_MESSAGE
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
