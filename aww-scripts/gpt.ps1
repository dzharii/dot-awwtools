$ErrorActionPreference = "Stop"
$ThisScriptFolderPath = Split-Path -Parent $MyInvocation.MyCommand.Definition

$Command = $args[0]
$Rest = $args | Select-Object -Skip 1

if (-not($Command)) {
  $Command = ""
}

if (-not($Rest)) {
    $Rest = @()
}



$COMMAND_HELP = "help"
$COMMAND_TRANSLATE = "translate-fr"
$COMMAND_NO = "no"
$COMMAND_FIX_GRAMMAR = "fix-grammar"


$HELP_MESSAGE = @"
Usage:
   gpt.ps1 <command> [options]
   aww run gpt <command> [options]

Commands:
    $($COMMAND_HELP):
      Shows this help message

    $($COMMAND_TRANSLATE) "The text to translate"  / or clipboard:
      Translates the provided text to the target language using GPT.

    $($COMMAND_NO) "text to sya no to" / or clipboard:
      Translates the provided text to the target language using GPT.

    $($COMMAND_FIX_GRAMMAR) "Text to fix grammar" / or clipboard:
      Fixes grammar mistakes, rearranges words, or edits for clarity while maintaining original style.
"@


# Load the buffered logger module
. $(Join-Path $ThisScriptFolderPath "lib-buffered-logger.ps1")

# Load the HTTP module
. $(Join-Path $ThisScriptFolderPath "lib-aww-http.ps1")

# Check if $script:AWWLOG is defined; terminate if not
if (-not $script:AWWLOG) {
    Write-Error "Error: AWWLOG is not defined. lib-buffered-logger.ps1" -ForegroundColor Red
    return
}


try{
# Retrieve the OpenAI API key from the environment variable
$apiKey = $env:OPEN_AI_KEY

# Check if the API key is not empty or null
if (-not $apiKey) {
    Write-Host "Error: API key not found in environment variable 'OPEN_AI_KEY'."
    return
}

$apiEndpoint = "https://api.openai.com/v1/chat/completions"


function Get-ClipboardConsent {
    $response = Read-Host "Do you want to use text from clipboard? (yes/no)"
    if ($response -eq "yes") {
        return Get-Clipboard -Format Text
    } else {
        throw "No! for consent O_O"
    }
}

# Handles different commands
switch ($Command.ToLower()) {

    $COMMAND_HELP {
        Write-Host $HELP_MESSAGE
    }

    $COMMAND_NO {

        $Text = "$Rest"

        if (-not($Text)) {
            $Text = Get-ClipboardConsent
        }

        if (-not $Text) {
            Write-Host "Error: Text for refusal is required." -ForegroundColor Red
            exit 1
        }

        # Define the request body and headers
        $messages = @(
            @{
                role = "system"
                content = @"
Given any user input, logically disagree with it by providing a counter-argument in an unformatted paragraph.
Ensure the disagreement is respectful and based on logic, facts, or widely accepted principles.
Respond in the same language as the user's input.
Provide examples to support your disagreement when relevant, and address any potential counterpoints the user might raise.
"@
            },
            @{
                role = "user"
                content = "$Text"
            }
        )

        $requestBody = @{
            model = "gpt-4o-mini"
            messages = $messages
            max_tokens = 100
        } | ConvertTo-Json

        $headers = @{
            "Authorization" = "Bearer $($apiKey)"
            "Content-Type"  = "application/json"
        }

        # Use the Invoke-AwwHttpPost method to send the request to the OpenAI API
        $response = Invoke-AwwHttpPost -Uri $apiEndpoint -Headers $headers -Body $requestBody

        # Output the response
        if ($response.choices) {
            $result = "$($response.choices[0].message.content)"
            $script:AWWLOG.WriteHost("Translation: $($result)")
            $result | Set-Clipboard

        } else {
            $script:AWWLOG.WriteError("Error: No response received from OpenAI API.")
        }
    }

    $COMMAND_TRANSLATE {

        $Text = "$Rest"

        if (-not($Text)) {
            $Text = Get-ClipboardConsent
        }

        if (-not $Text) {
            $script:AWWLOG.WriteError("Error: Text for translation is required.")
            exit 1
        }

        # Define the request body and headers
        $messages = @(
            @{
                role = "system"
                content = "You are a helpful assistant."
            },
            @{
                role = "user"
                content = "Translate the following English text to french: $Text"
            }
        )

        $requestBody = @{
            model = "gpt-4o-mini"
            messages = $messages
            max_tokens = 100
        } | ConvertTo-Json

        $headers = @{
            "Authorization" = "Bearer $($apiKey)"
            "Content-Type"  = "application/json"
        }

        # Use the Invoke-AwwHttpPost method to send the request to the OpenAI API
        $response = Invoke-AwwHttpPost -Uri $apiEndpoint -Headers $headers -Body $requestBody

        # Output the response
        if ($response.choices) {
            $result = "$($response.choices[0].message.content)"
            $script:AWWLOG.WriteHost("Translation: $($result)")
            $result | Set-Clipboard

        } else {
            $script:AWWLOG.WriteError("Error: No response received from OpenAI API.")
        }
    }

    $COMMAND_FIX_GRAMMAR {
        # New code for the "fix-grammar" command
        $Text = "$Rest"

        if (-not $Text) {
            $script:AWWLOG.WriteError("Error: Text for grammar correction is required.")
            throw "No text for grammar correction."
        }

        $messages = @(
            @{
                role = "system"
                content = "Fix grammar mistakes, rearrange words, or edit for clarity if needed, while maintaining the original style."
            },
            @{
                role = "user"
                content = "$Text"
            }
        )

        $requestBody = @{
            model = "gpt-4o-mini"
            messages = $messages
            max_tokens = 100
        } | ConvertTo-Json

        $headers = @{
            "Authorization" = "Bearer $($apiKey)"
            "Content-Type"  = "application/json"
        }

        $response = Invoke-AwwHttpPost -Uri $apiEndpoint -Headers $headers -Body $requestBody

        if ($response.choices) {
            $result = "$($response.choices[0].message.content)"
            Write-Host "Grammar-corrected Text: $($result)"
        } else {
            $script:AWWLOG.WriteError("Error: No response received from OpenAI API.")
        }
    }

    Default {
        Write-Host $HELP_MESSAGE
        throw "Unknown command: $Command"
    }
}

$script:AWWLOG.WriteHost("Done: $(Get-Date -Format o)")
} catch {
    $script:AWWLOG.Flush()
    Write-Host "Error: $_" -ForegroundColor Red
}