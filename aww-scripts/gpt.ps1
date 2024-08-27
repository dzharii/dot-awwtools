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
$COMMAND_TRANSLATE = "translate"

$HELP_MESSAGE = @"
Usage:
   gpt.ps1 <command> [options]
   aww run gpt <command> [options]

Commands:
    $($COMMAND_HELP):
      Shows this help message

    $($COMMAND_TRANSLATE) -Text "The text to translate":
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

# Handles different commands
switch ($Command.ToLower()) {

    $COMMAND_HELP {
        Write-Host $HELP_MESSAGE
    }

    $COMMAND_TRANSLATE {
        
        $Text = "$Rest"
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
                content = "Translate the following English text: $Text"
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
            Write-Host "Translation: $($response.choices[0].message.content)"
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
