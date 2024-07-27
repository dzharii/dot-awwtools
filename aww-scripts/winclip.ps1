# Function to load necessary .NET assemblies
function Load-Assemblies {
    <#
    .SYNOPSIS
    Loads the necessary .NET assemblies for clipboard operations.
    .DESCRIPTION
    This function loads the System.Windows.Forms and System.Drawing assemblies
    required for accessing and manipulating clipboard content.
    .EXAMPLE
    Load-Assemblies
    #>
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop
        Write-Host "`e[32m[INFO] .NET assemblies loaded successfully.`e[0m"
    } catch {
        Write-Host "`e[31m[ERROR] Failed to load necessary .NET assemblies: $($_.Exception.Message)`e[0m"
        exit 1
    }
}

# Function to initialize logging with optional logging level
function Initialize-Logging {
    param (
        [string]$LogLevel = "INFO" # Default log level
    )
    <#
    .SYNOPSIS
    Initializes logging for the script.
    .DESCRIPTION
    This function initializes logging by setting the log level and outputting an
    initialization message.
    .PARAMETER LogLevel
    The log level for logging messages (default is "INFO").
    .EXAMPLE
    Initialize-Logging -LogLevel "DEBUG"
    #>
    Write-Host "`e[32m[INFO] Initializing logging at $($LogLevel) level...`e[0m"
}

# Function to determine clipboard content type
function Get-ClipboardContentType {
    <#
    .SYNOPSIS
    Determines the content type of the clipboard data.
    .DESCRIPTION
    This function checks the clipboard for various data formats and returns the
    type of content present (e.g., Text, Image, RichText).
    .OUTPUTS
    [string] - The type of content present in the clipboard.
    .EXAMPLE
    $contentType = Get-ClipboardContentType
    #>
    try {
        $clipboard = [System.Windows.Forms.Clipboard]::GetDataObject()
        if ($null -eq $clipboard) {
            throw "Clipboard is empty or not accessible."
        }

        if ($clipboard.GetDataPresent([System.Windows.Forms.DataFormats]::Text)) {
            return "Text"
        } elseif ($clipboard.GetDataPresent([System.Windows.Forms.DataFormats]::Bitmap)) {
            return "Image"
        } elseif ($clipboard.GetDataPresent([System.Windows.Forms.DataFormats]::Rtf)) {
            return "RichText"
        } else {
            return "Unknown"
        }
    } catch {
        Write-Host "`e[31m[ERROR] Failed to determine clipboard content type: $($_.Exception.Message)`e[0m"
        throw
    }
}

# Function to generate a unique and valid file name
function Generate-FileName {
    param (
        [string]$extension
    )
    <#
    .SYNOPSIS
    Generates a unique file name with the specified extension.
    .DESCRIPTION
    This function creates a unique file name using the current date, time, and a GUID,
    and appends the specified extension. The file name is sanitized for validity on
    both Windows and Linux file systems.
    .PARAMETER extension
    The file extension to be appended to the generated file name.
    .OUTPUTS
    [string] - The generated file name.
    .EXAMPLE
    $fileName = Generate-FileName -extension "txt"
    #>
    try {
        $currentDate = Get-Date -Format "yyyyMMdd_HHmmss"
        $guid = [guid]::NewGuid().ToString()
        $fileName = "$($currentDate)__$($guid).$($extension)"
        
        # Ensure the file name is valid for both Windows and Linux
        $fileName = $fileName -replace '[<>:"/\\|?*]', '_'
        return $fileName
    } catch {
        Write-Host "`e[31m[ERROR] Failed to generate file name: $($_.Exception.Message)`e[0m"
        throw
    }
}

# Function to save text content from clipboard
function Save-TextContent {
    <#
    .SYNOPSIS
    Saves text content from the clipboard to a file.
    .DESCRIPTION
    This function retrieves text content from the clipboard and saves it to a file
    with a .txt extension. The file name is generated uniquely.
    .EXAMPLE
    Save-TextContent
    #>
    try {
        $text = [System.Windows.Forms.Clipboard]::GetText()
        if ($null -eq $text) {
            throw "No text content available in clipboard."
        }
        $fileName = Generate-FileName -extension "txt"
        Set-Content -Path $fileName -Value $text -Encoding UTF8
        Write-Host "`e[32m[INFO] Text content saved to $($fileName)`e[0m"
    } catch {
        Write-Host "`e[31m[ERROR] Failed to save text content: $($_.Exception.Message)`e[0m"
        throw
    }
}

# Function to save image content from clipboard
function Save-ImageContent {
    <#
    .SYNOPSIS
    Saves image content from the clipboard to a file.
    .DESCRIPTION
    This function retrieves image content from the clipboard and saves it as a .png file.
    The file name is generated uniquely.
    .EXAMPLE
    Save-ImageContent
    #>
    try {
        $image = [System.Windows.Forms.Clipboard]::GetImage()
        if ($null -eq $image) {
            throw "No image content available in clipboard."
        }
        $fileName = Generate-FileName -extension "png"
        $image.Save($fileName, [System.Drawing.Imaging.ImageFormat]::Png)
        Write-Host "`e[32m[INFO] Image content saved to $($fileName)`e[0m"
    } catch {
        Write-Host "`e[31m[ERROR] Failed to save image content: $($_.Exception.Message)`e[0m"
        throw
    }
}

# Function to save rich text content from clipboard
function Save-RichTextContent {
    <#
    .SYNOPSIS
    Saves rich text content from the clipboard to a file.
    .DESCRIPTION
    This function retrieves rich text content from the clipboard and saves it to a file
    with a .rtf extension. The file name is generated uniquely.
    .EXAMPLE
    Save-RichTextContent
    #>
    try {
        $richText = [System.Windows.Forms.Clipboard]::GetData([System.Windows.Forms.DataFormats]::Rtf)
        if ($null -eq $richText) {
            throw "No rich text content available in clipboard."
        }
        $fileName = Generate-FileName -extension "rtf"
        Set-Content -Path $fileName -Value $richText -Encoding UTF8
        Write-Host "`e[32m[INFO] Rich text content saved to $($fileName)`e[0m"
    } catch {
        Write-Host "`e[31m[ERROR] Failed to save rich text content: $($_.Exception.Message)`e[0m"
        throw
    }
}

# Function to handle errors and exit
function Handle-Error {
    param (
        [string]$message
    )
    <#
    .SYNOPSIS
    Handles errors by logging the message and exiting the script.
    .DESCRIPTION
    This function logs an error message to the console and exits the script with an error code.
    .PARAMETER message
    The error message to be logged.
    .EXAMPLE
    Handle-Error -message "An unexpected error occurred."
    #>
    Write-Host "`e[31m[ERROR] $($message)`e[0m"
    exit 1
}

# Function to handle success and exit
function Handle-Success {
    <#
    .SYNOPSIS
    Handles successful operations by logging a success message and exiting the script.
    .DESCRIPTION
    This function logs a success message to the console and exits the script with a success code.
    .EXAMPLE
    Handle-Success
    #>
    Write-Host "`e[32m[INFO] Operation completed successfully`e[0m"
    exit 0
}

# Main script logic
try {
    Load-Assemblies
    Initialize-Logging -LogLevel "INFO"

    $contentType = Get-ClipboardContentType
    Write-Host "`e[32m[INFO] Clipboard content type: $($contentType)`e[0m"

    switch ($contentType) {
        "Text" { Save-TextContent }
        "Image" { Save-ImageContent }
        "RichText" { Save-RichTextContent }
        default {
            Handle-Error -message "Unsupported clipboard content type: $($contentType)"
        }
    }
    Handle-Success
} catch {
    Handle-Error -message $_.Exception.Message
} finally {
    Write-Host "`e[32m[INFO] Script execution finished`e[0m"
}
