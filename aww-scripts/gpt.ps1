param(
    [Parameter(Mandatory=$true)]
    [string] $Command,

    [Parameter(Mandatory=$false)]
    [string] $Text
)

$ErrorActionPreference = "Stop"
$ThisScriptFolderPath = Split-Path -Parent $MyInvocation.MyCommand.Definition

$COMMAND_HELP = "help"
$COMMAND_TRANSLATE = "translate"

$HELP_MESSAGE = @"
Usage:
   gpt.ps1 <command> [options]
   aww run gpt <command> [options]

Commands:
    $($COMMAND_HELP):
      Shows this help message

    $($COMMAND_TRANSLATE) -Text <The text to translate>:
      Translates the provided text to the target language using GPT-4.

"@

# Load the HTTP module
Import-Module "$ThisScriptFolderPath\lib-aww-http.psm1"

# Retrieve the OpenAI API key from the environment variable
$apiKey = $env:OPEN_AI_KEY

# Check if the API key is not empty or null
if (-not $apiKey) {
    Write-Host "Error: API key not found in environment variable 'OPEN_AI_KEY'." -ForegroundColor Red
    return
}

$apiEndpoint = "https://api.openai.com/v1/completions"

# Handles different commands
switch ($Command.ToLower()) {

    $COMMAND_HELP {
        Write-Host $HELP_MESSAGE
    }

    $COMMAND_TRANSLATE {
        if (-not $Text) {
            Write-Host "Error: Text for translation is required." -ForegroundColor Red
            exit 1
        }

        # Define the request body and headers
        $prompt = "Translate the following English text: $Text"
        $requestBody = @{
            model = "gpt-4"
            prompt = $prompt
            max_tokens = 100
        } | ConvertTo-Json

        $headers = @{
            "Authorization" = "Bearer $apiKey"
            "Content-Type"  = "application/json"
        }

        # Use the HttpClient's POST method to send the request to the OpenAI API
        $response = $AwwHttp.POST -Uri $apiEndpoint -Headers $headers -Body $requestBody

        # Output the response
        if ($response.choices) {
            Write-Host "Translation: $($response.choices[0].text)"
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
