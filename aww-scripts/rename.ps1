<#
.SYNOPSIS
    Recursively searches for a specific string in directory names, filenames, and content of all text files within the current directory and its subdirectories, replacing it with another string.

.DESCRIPTION
    This script takes two parameters: -SearchString and -ReplacementString.
    It searches recursively in the current directory for directories, filenames, and text files' content, replacing the specified string.

.PARAMETER SearchString
    The string to search for in directory names, filenames, and file contents.

.PARAMETER ReplacementString
    The string to replace the SearchString with in directory names, filenames, and file contents.

.EXAMPLE
    ./Replace-StringInFiles.ps1 -SearchString "old" -ReplacementString "new"

.NOTES
    Author: PowerShell 5 Pro
    Date: 2024-08-09
#>

param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$SearchString,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ReplacementString
)

# Set the error action preference to stop to catch errors in try-catch blocks.
$ErrorActionPreference = "Stop"

# Initialize counters and log start of the script
$ProcessedCount = 0
$TotalFiles = 0
$TotalDirectories = 0
$StartTime = Get-Date

Write-Host "Script started at: $($StartTime)"
Write-Host "Parameters - SearchString: '$($SearchString)', ReplacementString: '$($ReplacementString)'"

# Function to log messages
function Log-Message {
    param (
        [string]$Message
    )
    Write-Host $Message
}

# Function to get all directories recursively
function Get-Directories {
    param (
        [string]$DirectoryPath
    )
    
    try {
        # Use .NET Directory class to get all directories
        $directories = [System.IO.Directory]::GetDirectories($DirectoryPath, "*", [System.IO.SearchOption]::AllDirectories)
        return $directories
    }
    catch {
        Log-Message "Error retrieving directories: $($_.Exception.Message)"
        return @()
    }
}

# Function to get all text files recursively
function Get-TextFiles {
    param (
        [string]$DirectoryPath
    )
    
    try {
        # Use .NET Directory class to get all files
        $files = [System.IO.Directory]::GetFiles($DirectoryPath, "*.*", [System.IO.SearchOption]::AllDirectories)
        $textFiles = @()
        
        foreach ($file in $files) {
            # Check if the file is a text file
            if (Is-TextFile -FilePath $file) {
                $textFiles += $file
            }
        }
        return $textFiles
    }
    catch {
        Log-Message "Error retrieving files: $($_.Exception.Message)"
        return @()
    }
}

# Function to check if a file is a text file
function Is-TextFile {
    param (
        [string]$FilePath
    )

    try {
        # Open the file and read the first few bytes to determine if it's a text file
        $reader = [System.IO.StreamReader]::new($FilePath)
        [void]$reader.ReadLine()
        $reader.Close()
        return $true
    }
    catch {
        Log-Message "Skipping non-text file: $($FilePath)"
        return $false
    }
}

# Function to rename directories
function Rename-Directories {
    param (
        [array]$Directories,
        [string]$SearchString,
        [string]$ReplacementString
    )

    foreach ($directory in $Directories) {
        $directoryName = [System.IO.Path]::GetFileName($directory)
        $parentDirectory = [System.IO.Path]::GetDirectoryName($directory)

        if ($directoryName -like "*$($SearchString)*") {
            $newDirectoryName = $directoryName -replace [regex]::Escape($SearchString), $ReplacementString
            $newDirectoryPath = [System.IO.Path]::Combine($parentDirectory, $newDirectoryName)

            try {
                [System.IO.Directory]::Move($directory, $newDirectoryPath)
                Log-Message "Renamed directory '$($directoryName)' to '$($newDirectoryName)'"
            }
            catch {
                Log-Message "Error renaming directory '$($directory)': $($_.Exception.Message)"
            }
        }
    }
}

# Function to process files
function Process-Files {
    param (
        [array]$Files,
        [string]$SearchString,
        [string]$ReplacementString
    )

    foreach ($file in $Files) {
        Log-Message "Processing file $($ProcessedCount + 1) of $($TotalFiles): '$($file)'"

        # Rename file if the filename contains the search string
        try {
            $fileName = [System.IO.Path]::GetFileName($file)
            $directory = [System.IO.Path]::GetDirectoryName($file)

            if ($fileName -like "*$($SearchString)*") {
                $newFileName = $fileName -replace [regex]::Escape($SearchString), $ReplacementString
                $newFilePath = [System.IO.Path]::Combine($directory, $newFileName)
                
                [System.IO.File]::Move($file, $newFilePath)
                Log-Message "Renamed '$($fileName)' to '$($newFileName)'"

                # Update file path for content replacement
                $file = $newFilePath
            }

            # Replace content in the file
            $content = [System.IO.File]::ReadAllText($file)

            if ($content -like "*$($SearchString)*") {
                $newContent = $content -replace [regex]::Escape($SearchString), $ReplacementString
                [System.IO.File]::WriteAllText($file, $newContent)
                Log-Message "Replaced occurrences of '$($SearchString)' in '$($fileName)'"
            }
        }
        catch {
            Log-Message "Error processing file '$($file)': $($_.Exception.Message)"
        }

        $ProcessedCount++
    }
}

# Main script logic
try {
    # Get all directories in the directory
    $Directories = Get-Directories -DirectoryPath (Get-Location).Path
    $TotalDirectories = $Directories.Count
    Log-Message "Detected $($TotalDirectories) directories for processing."

    # Rename directories first
    Rename-Directories -Directories $Directories -SearchString $SearchString -ReplacementString $ReplacementString

    # Get all text files in the directory after renaming directories
    $Files = Get-TextFiles -DirectoryPath (Get-Location).Path
    $TotalFiles = $Files.Count
    Log-Message "Detected $($TotalFiles) text files for processing."

    # Process each file
    Process-Files -Files $Files -SearchString $SearchString -ReplacementString $ReplacementString
}
catch {
    Log-Message "A critical error occurred: $($_.Exception.Message)"
}
finally {
    # Final reporting
    $EndTime = Get-Date
    Write-Host "Script completed at: $($EndTime)"
    Write-Host "Processed $($ProcessedCount) files."
    Write-Host "Total elapsed time: $($EndTime - $StartTime)"
}
