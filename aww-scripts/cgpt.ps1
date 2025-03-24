$ErrorActionPreference = "Stop"

# Define the folder where the script is located (for potential future use)
$ThisScriptFolderPath = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Base URL for ChatGPT prompt query
$BaseUrl = "https://chatgpt.com/?q="

# Parse the command and accompanying user text from arguments
$Command = $args[0]
$Rest = $args | Select-Object -Skip 1

# Fallback for empty command
if (-not $Command) {
    $Command = ""
}

# Combine remaining arguments into a single string for user input
$UserText = [string]::Join(' ', $Rest).Trim()

# Define supported commands as constants
$COMMAND_HELP = "help"
$COMMAND_SUMMARIZE = "summarize"
$COMMAND_P = "p"
$COMMAND_PROMPT = "prompt"

# Help message displayed for users
$HELP_MESSAGE = @"
Usage:
   cgpt.ps1 <prompt-name> <user text>

Examples:
   cgpt.ps1 summarize This article explains the impact of AI on education.
   cgpt.ps1 prompt Write a Python function to reverse a string.
   cgpt.ps1 p What's the fastest way to boil an egg?

Commands:
    $($COMMAND_HELP):
      Displays this help message.

    $($COMMAND_SUMMARIZE):
      Executes a specialized summarization prompt designed for analyzing web content. Appends the provided user text to the pre-defined summarization logic.

    $($COMMAND_P), $($COMMAND_PROMPT):
      Sends the user-supplied text directly to ChatGPT without any pre-defined prompt.

Notes:
- All arguments after the command are treated as the user prompt.
- Prompt content is URL-encoded and opened in your default web browser.
- Ensure your default browser is configured to handle URLs correctly.
"@

# Template used for the 'summarize' command
$PromptSummarize = @"
Begin your response with 'Tags:' followed by up to 10 meaningful tags that capture the main ideas of the article. 
Then, in 30 words or fewer, provide the article's main idea (without labeling it). 
After that, present key sub-ideas or secondary points that should not be missed, but do not include a heading for that section. 
Finally, conclude with a brief note (1-2 sentences) on why this article is interesting or important, also without a heading. 
Search the web / use webtool to find the content by url: 
"@

<#!
.SYNOPSIS
    Constructs and launches a ChatGPT URL using the provided prompt and user input.
.DESCRIPTION
    This function combines a predefined prompt and user-supplied text, encodes the result,
    and launches the URL in the system's default browser for ChatGPT interaction.
.PARAMETER Prompt
    The predefined prompt text to prepend to the user input.
.PARAMETER UserText
    The text input provided by the user.
#>
function Invoke-ChatGptPrompt {
    param (
        [string]$Prompt,
        [string]$UserText
    )

    $FinalPrompt = "$($Prompt) $($UserText)"
    $EncodedPrompt = [URI]::EscapeUriString($FinalPrompt)
    $FinalUrl = "$($BaseUrl)$($EncodedPrompt)"

    Write-Host "Launching ChatGPT prompt..." -ForegroundColor Green
    Start-Process $FinalUrl
}

# Dispatch command logic
switch ($Command.ToLower()) {
    $COMMAND_HELP {
        Write-Host $HELP_MESSAGE
        return
    }
    $COMMAND_SUMMARIZE {
        if (-not $UserText) {
            throw "User input is required for command '$Command'"
        }

        Invoke-ChatGptPrompt -Prompt $PromptSummarize -UserText $UserText
    }
    {($_ -eq $COMMAND_P) -or ($_ -eq $COMMAND_PROMPT)} {
        if (-not $UserText) {
            throw "User input is required for command '$Command'"
        }

        # Encode plain user prompt for direct submission
        $EncodedPrompt = [URI]::EscapeUriString($UserText)
        $FinalUrl = "$($BaseUrl)$($EncodedPrompt)"

        Write-Host "Launching ChatGPT with user input only..." -ForegroundColor Green
        Start-Process $FinalUrl
    }
    Default {
        throw "Unknown command: '$Command'"
    }
}

# Log script completion with timestamp
Write-Host "Done: $(Get-Date -Format o)"
