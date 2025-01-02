param (
    [string]$Path = ".",
    [switch]$DryRun = $false
)

# Get the files in the specified directory with the filter "GX*.MP4" and sort them
$files = Get-ChildItem -Path $Path -Filter "GX*.MP4" | Sort-Object Name

# Group the files by their video id number
$groupedFiles = $files | Group-Object { $_.Name.Substring(4, 4) }

foreach ($group in $groupedFiles) {
    $videoId = $group.Name
    $outputFile = Join-Path -Path $Path -ChildPath "Video_libx265_$($videoId).MP4"

    # If there's only one file in the group, process it directly
    if ($group.Count -eq 1) {
        $inputFile = $($group.Group[0].FullName)
        $ffmpegArgs = "-i `"$($inputFile)`" -vcodec libx265 -preset faster -crf 28 `"$($outputFile)`""
    } else {
        # If there are multiple parts, concatenate them
        $concatList = ""
        foreach ($part in $group.Group) {
            $concatList += "file '" + $($part.FullName) + "'" + [Environment]::NewLine
        }
        $concatFile = Join-Path -Path $Path -ChildPath "concat_$($videoId).txt"
        Set-Content -Path $concatFile -Value $concatList

        $ffmpegArgs = "-f concat -safe 0 -i `"$($concatFile)`" -vcodec libx265 -preset faster -crf 28 `"$($outputFile)`""
    }

    $ffmpegCmd = "ffmpeg $($ffmpegArgs)"

    if ($DryRun) {
        Write-Host "Dry Run: $($ffmpegCmd)"
    } else {
        Write-Host "Executing: $($ffmpegCmd)"
        try {
            # Execute the ffmpeg command
            Invoke-Expression -Command $ffmpegCmd -ErrorAction Stop
        } catch {
            # Log the error and exit the script if an error occurs
            Write-Host "Error processing video $($videoId): $_"
            exit 1
        }
    }
}