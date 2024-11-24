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

<#
.SYNOPSIS
Replaces all non-ASCII characters in a file with their ASCII equivalents based on a predefined replacement map.

.DESCRIPTION
The `Replace-NonAsciiCharacters` function processes a given input file line by line, replacing all non-ASCII characters with their closest ASCII equivalents. 
This is achieved by using a predefined replacement map (dictionary), which contains common replacements such as smart quotes, accented characters, 
and special symbols. The function ensures that the output file contains only ASCII-compatible characters.

The function reads the input file line by line, parses each line character by character, and performs replacements when a character matches 
an entry in the replacement map. If the character does not exist in the map, it is retained as-is. The processed content is then written to the 
specified output file.

This approach ensures efficient processing, even for large files, and produces a clean, sanitized output.

.PARAMETER InputFile
Specifies the path to the input file that will be processed. The file must exist; otherwise, the function will terminate with an error.

.PARAMETER OutputFile
Specifies the path to the output file where the processed content will be saved. If the file already exists, it will be overwritten.

.EXAMPLE
Replace-NonAsciiCharacters -InputFile "C:\Path\To\Input.txt" -OutputFile "C:\Path\To\Output.txt"

This example processes the file `Input.txt` located at `C:\Path\To\`, replacing all non-ASCII characters with their ASCII equivalents.
The sanitized content is saved in `Output.txt` in the same directory.

#>
function Replace-NonAsciiCharacters {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$InputFile, # The input file path

        [Parameter(Mandatory = $true)]
        [string]$OutputFile # The output file path
    )

    # Define the replacement map for non-ASCII characters
    $ReplacementMap = @{
        # Smart Quotes
        '‘' = "'";  # Left Single Quote → Straight Apostrophe
        '’' = "'";  # Right Single Quote → Straight Apostrophe
        '“' = '"';  # Left Double Quote → Straight Double Quote
        '”' = '"';  # Right Double Quote → Straight Double Quote

        # En Dash and Em Dash
        '–' = '-';  # En Dash → Hyphen
        '—' = '-';  # Em Dash → Hyphen

        # Accented Characters (Common Examples)
        'é' = 'e';  # Latin Small Letter E with Acute → e
        'è' = 'e';  # Latin Small Letter E with Grave → e
        'ê' = 'e';  # Latin Small Letter E with Circumflex → e
        'ë' = 'e';  # Latin Small Letter E with Diaeresis → e
        'á' = 'a';  # Latin Small Letter A with Acute → a
        'à' = 'a';  # Latin Small Letter A with Grave → a
        'â' = 'a';  # Latin Small Letter A with Circumflex → a
        'ä' = 'a';  # Latin Small Letter A with Diaeresis → a
        'ñ' = 'n';  # Latin Small Letter N with Tilde → n
        'ç' = 'c';  # Latin Small Letter C with Cedilla → c

        # Ellipsis
        '…' = '...';  # Horizontal Ellipsis → Three Dots

        # Other Symbols
        '©' = '(c)';  # Copyright Symbol → (c)
        '®' = '(R)';  # Registered Trademark Symbol → (R)
        '™' = '(TM)'; # Trademark Symbol → (TM)
    }

    # Validate input file existence
    if (-not (Test-Path -Path $InputFile)) {
        throw  "ERROR: The input file '$($InputFile)' does not exist."
    }

    try {
        Write-Host "Starting processing of the file '$InputFile'." -ForegroundColor Yellow

        # Read the file content line by line
        $Content = Get-Content -Path $InputFile -ErrorAction Stop
        $ProcessedLines = @() # Array to hold processed lines

        foreach ($Line in $Content) {
            # Create a StringBuilder to efficiently build the processed line
            $StringBuilder = New-Object System.Text.StringBuilder

            # Process each character in the line
            foreach ($Char in $Line.ToCharArray()) {
                # Check if the character exists in the replacement map
                if ($ReplacementMap.ContainsKey($Char)) {
                    # Replace the character with its ASCII equivalent
                    $null = $StringBuilder.Append($ReplacementMap[$Char])
                } else {
                    # Keep the character as is
                    $null = $StringBuilder.Append($Char)
                }
            }

            # Append the processed line to the array
            $ProcessedLines += $StringBuilder.ToString()
        }

        # Write the processed content to the output file
        Write-Host "Writing processed content to the output file '$OutputFile'." -ForegroundColor Green
        $ProcessedLines | Set-Content -Path $OutputFile -Encoding UTF8 -ErrorAction Stop

        Write-Host "Processing completed successfully." -ForegroundColor Green
    }
    catch {
        Write-Host "ERROR: An error occurred during processing. Details: $($_.Exception.Message)" -ForegroundColor Red
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
            $asciiConvertedInputFile = "$($InputFile).md"
            # Convert Non-ASCII characters
            Replace-NonAsciiCharacters -InputFile $InputFile -OutputFile $asciiConvertedInputFile
            # Execute the Pandoc conversion and capture the result
            $result = Invoke-PandocConversion -InputFile $asciiConvertedInputFile -OutputFile $OutputFile -Columns 130 -Wrap "auto"

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
