param(
    [Parameter(Mandatory=$true)]
    [string]$Command,
    [Parameter(Mandatory=$false)] 
    [string]$InputFile
)

$ErrorActionPreference = "Stop"
$ThisScriptFolderPath = Split-Path -Parent $MyInvocation.MyCommand.Definition

$COMMAND_HELP = "help"
$COMMAND_MD_ORG = "md-to-org"

$HELP_MESSAGE = @"
Usage:
   doc.ps1 <command> [-InputFile <path>]
   e.g., doc.ps1 $COMMAND_MD_ORG -InputFile "input.md"

Commands:
    $($COMMAND_HELP):
      Shows this help message

    $($COMMAND_MD_ORG):
      Converts a Markdown file to an Org file using Pandoc.
      Requires the -InputFile parameter specifying the path to the Markdown file.
"@

# Function to execute the Pandoc conversion
<#
.SYNOPSIS
    Executes the Pandoc command to convert a Markdown file to an Org file.

.DESCRIPTION
    This function checks if Pandoc is installed, verifies the input file exists,
    and checks that the output file does not already exist. It then constructs and
    executes the Pandoc command based on the specified parameters.
    The function returns an empty string if successful, or an error message string
    if there was a failure.

.PARAMETER InputFile
    The path to the input Markdown file.

.PARAMETER OutputFile
    The path to the output Org file.

.PARAMETER Columns
    Sets the maximum line width in characters for the output file.

.PARAMETER Wrap
    Controls the wrapping behavior of the output file (e.g., 'auto', 'none', 'preserve').

.EXAMPLE
    Invoke-PandocConversion -InputFile "input.md" -OutputFile "output.org" -Columns 130 -Wrap "auto"
#>
function Invoke-PandocConversion {
    param (
        [string]$InputFile,
        [string]$OutputFile,
        [int]$Columns = 130,
        [string]$Wrap = "auto"
    )

    # Define the URL to download Pandoc if it is not found
    $pandocDownloadUrl = "https://pandoc.org/installing.html"

    # Check if the 'pandoc' command is available
    if (-not (Get-Command pandoc -ErrorAction SilentlyContinue)) {
        return "Error: 'pandoc' is not installed on this system. Please install Pandoc from the following URL: $pandocDownloadUrl"
    }

    # Check if the input file exists
    if (-not (Test-Path -Path $InputFile)) {
        return "Error: Input file '$InputFile' does not exist."
    }

    # Check if the output file already exists
    $OutputFile = [System.IO.Path]::ChangeExtension($InputFile, ".org")
    if (Test-Path -Path $OutputFile) {
        return "Error: Output file '$OutputFile' already exists."
    }

    # Set the options for Pandoc
    $pandocOptions = @(
        "--from markdown",       # Specify input format
        "--to org",              # Specify output format
        "--output `"$OutputFile`"", # Output file
        "--wrap=$Wrap",          # Set line wrapping
        "--columns=$Columns"     # Set the default line width
    )

    # Construct the full command
    $pandocCommand = "pandoc $($pandocOptions -join ' ') `"$InputFile`""

    # Print the command before execution
    Write-Host "Executing Pandoc command: $pandocCommand"

    # Execute the command using Invoke-Expression and capture the output
    try {
        $output = Invoke-Expression -Command $pandocCommand
        $exitCode = $LASTEXITCODE

        # Print the output from Pandoc
        Write-Host $output

        # Check the exit code and return appropriate result
        if ($exitCode -eq 0) {
            return ""  # Success, return empty string
        } else {
            return "Error: Pandoc conversion failed with exit code $exitCode."
        }
    } catch {
        # Return the error message instead of throwing an exception
        return "Error executing Pandoc: $_"
    }
}

switch ($Command.ToLower()) {
    
    $COMMAND_HELP {
        Write-Host $HELP_MESSAGE
    }

    $COMMAND_MD_ORG {
        # Ensure that the InputFile parameter is provided
        if (-not $InputFile) {
            Write-Host "Error: The -InputFile parameter is required for the '$COMMAND_MD_ORG' command." -ForegroundColor Red
            Write-Host $HELP_MESSAGE
            exit 1
        }

        # Define the output file path
        $OutputFile = [System.IO.Path]::ChangeExtension($InputFile, ".org")

        try {
            # Execute the Pandoc conversion and capture the result
            $result = Invoke-PandocConversion -InputFile $InputFile -OutputFile $OutputFile -Columns 130 -Wrap "auto"

            # Check the result and throw an error if there was an issue
            if ($result -ne "") {
                throw $result  # Throw the error message returned by the function
            } else {
                Write-Host "Conversion completed successfully: '$InputFile' to '$OutputFile'" -ForegroundColor Green
            }
        } catch {
            # Detailed error handling for the main execution
            Write-Host "An error occurred during the conversion process:" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
            exit 1
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
