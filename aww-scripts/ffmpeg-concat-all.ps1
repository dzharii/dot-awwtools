param (
    [string]$Path = ".",
    [switch]$DryRun = $false
)

# Function to create ffmpeg command for concatenation
function CreateFfmpegCommand($inputFilesTextPath, $outputFilePath) {
    return "ffmpeg -f concat -safe 0 -i `"$inputFilesTextPath`" -c copy `"$outputFilePath`""
}

# Ensure that the path ends with a \
$Path = [System.IO.Path]::GetFullPath($Path)

# Get today's date in the desired format
$date = Get-Date -Format "yyyy-MM-dd"

# Define the output file path
$outputFile = Join-Path -Path $Path -ChildPath "$($date)-output.mp4"

# Generate a text file that contains all mp4 file paths
$concatList = Get-ChildItem -Path $Path -Filter "*.MP4" | Sort-Object Name | ForEach-Object {
    "file '$($_.FullName)'"
}

# Path for the temporary file listing
$concatFile = Join-Path -Path $Path -ChildPath "concat_list.txt"
Set-Content -Path $concatFile -Value $concatList

# Create ffmpeg command
$ffmpegCmd = CreateFfmpegCommand -inputFilesTextPath $concatFile -outputFilePath $outputFile

if ($DryRun) {
    Write-Host "Dry Run: $($ffmpegCmd)"
} else {
    Write-Host "Executing: $($ffmpegCmd)"
    try {
        # Execute the ffmpeg command
        Invoke-Expression -Command $ffmpegCmd -ErrorAction Stop
        # Remove the temporary concat_list.txt file after successful execution
        Remove-Item -Path $concatFile -Force
    } catch {
        # Log the error and exit the script if an error occurs
        Write-Host "Error processing video concatenation: $_"
        exit 1
    }
    Write-Host "Video concatenation complete. Output file: $outputFile"
}
