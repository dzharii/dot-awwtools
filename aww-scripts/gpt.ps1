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
"@

# Load the HTTP module
. $(Join-Path $ThisScriptFolderPath "lib-aww-http.ps1")

# Retrieve the OpenAI API key from the environment variable
$apiKey = $env:OPEN_AI_KEY

# Check if the API key is not empty or null
if (-not $apiKey) {
    Write-Host "Error: API key not found in environment variable 'OPEN_AI_KEY'." -ForegroundColor Red
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
            Write-Host "Translation: $($result)"
            $result | Set-Clipboard

        } else {
            Write-Host "Error: No response received from OpenAI API." -ForegroundColor Red
        }
    }

    $COMMAND_TRANSLATE {
        
        $Text = "$Rest"

        if (-not($Text)) {
            $Text = Get-ClipboardConsent
        }

        if (-not $Text) {
            Write-Host "Error: Text for translation is required." -ForegroundColor Red
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
            Write-Host "Translation: $($result)"
            $result | Set-Clipboard

        } else {
            Write-Host "Error: No response received from OpenAI API." -ForegroundColor Red
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
