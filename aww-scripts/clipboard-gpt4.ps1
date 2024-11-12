$ErrorActionPreference = "Stop"
$ThisScriptFolderPath = Split-Path -Parent $MyInvocation.MyCommand.Definition

$Command = $args[0]
$Rest = $args | Select-Object -Skip 1

if (-not($Command)) {
  $Command = ""
}

# sample for command line text, not used now tag=#ectfwqgicmf
# if (-not($Rest)) {
#     $Rest = @()
# }



$COMMAND_HELP = "help"
$COMMAND_TRANSLATE = "translate-fr"
$COMMAND_NO = "no"
$COMMAND_FIX_GRAMMAR = "fix-grammar"
$COMMAND_FIX_DICTATION = "fix-dictation"
$COMMAND_ASK_CODE = "ask-code"


$HELP_MESSAGE = @"
Usage:
   gpt.ps1 <command> [options]
   aww run gpt <command> [options]

Commands:
    $($COMMAND_HELP):
      Shows this help message

    $($COMMAND_TRANSLATE) "The text to translate" in clipboard:
      Translates the provided text to French using GPT.

    $($COMMAND_NO) "Text to say no to" in clipboard:
      Provides a respectful and logical counter-argument to the provided text using GPT.

    $($COMMAND_FIX_GRAMMAR) "Text to fix grammar" in clipboard:
      Fixes grammar mistakes, rearranges words, or edits for clarity while maintaining the original style.

    $($COMMAND_FIX_DICTATION) "Text to fix dictation" in clipboard:
      Fixes any dictation issues, such as wrong words or misinterpretations, in text dictated via speech recognition software.

    $($COMMAND_ASK_CODE) "Request for code" in clipboard:
      Treats all user requests as requests for code implementation and responds with only the raw code.
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

# Not needed now, the script repurposed to use clipboard tag=#ectfwqgicmf
# function Get-ClipboardConsent {
#    $response = Read-Host "Do you want to use text from clipboard? (yes/no)"
#    if ($response -eq "yes") {
#        return Get-Clipboard -Format Text
#    } else {
#        throw "No! for consent O_O"
#    }
#}

# Handles different commands
switch ($Command.ToLower()) {

    $COMMAND_HELP {
        Write-Host $HELP_MESSAGE
    }

    $COMMAND_NO {

        $Text = Get-Clipboard -Format Text

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

        $Text = Get-Clipboard -Format Text

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
        $Text = Get-Clipboard -Format Text

        if (-not $Text) {
            Write-Host "Error: Text for fix-grammar not provided" -ForegroundColor Red
            exit 1
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

    $COMMAND_FIX_DICTATION {
        # New code for the "fix-dictation" command
        $Text = Get-Clipboard -Format Text

        if (-not $Text) {
            Write-Host "Error: Text for fix-dictation not provided" -ForegroundColor Red
            exit 1
        }

        $messages = @(
            @{
                role = "system"
                content = "The following text was dictated via speech recognition software. Fix any dictation issues, such as wrong words or misinterpretations, while maintaining the original style."
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
            Write-Host "Dictation-corrected Text: $($result)"
        } else {
            WriteHost "Error: No response received from OpenAI API." -ForegroundColor Red
        }
    }

    $COMMAND_ASK_CODE {
        # New code for the "ask-code" command
        $Text = Get-Clipboard -Format Text

        if (-not $Text) {
            Write-Host "Error: Text for ask-code not provided" -ForegroundColor Red
            exit 1
        }

        $messages = @(
            @{
                role = "system"
                content = "Treat all user requests as requests for code implementation. Respond with only the raw code in plain text, without Markdown formatting, comments, or any extra text. If a user request does not clearly specify a task requiring code, or if it is ambiguous or nonsensical in a coding context, respond with a refusal message. Do not guess or interpret beyond code requests."
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
            Write-Host "$($result)"
        } else {
            WriteHost "Error: No response received from OpenAI API."  -ForegroundColor Red
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