param (
    [Parameter(Mandatory=$true)]
    [string]$DayName
)

$ErrorActionPreference = "Stop"

$today = Get-Date

# Function to handle day names (e.g., monday, tuesday, etc.)
function Get-NextDateFromDay {
    param (
        [string]$DayName
    )

    # Convert the day name to DayOfWeek enum value using a switch statement
    switch ($DayName.ToLower()) {
        'monday'    { $desiredDayOfWeek = [System.DayOfWeek]::Monday }
        'tuesday'   { $desiredDayOfWeek = [System.DayOfWeek]::Tuesday }
        'wednesday' { $desiredDayOfWeek = [System.DayOfWeek]::Wednesday }
        'thursday'  { $desiredDayOfWeek = [System.DayOfWeek]::Thursday }
        'friday'    { $desiredDayOfWeek = [System.DayOfWeek]::Friday }
        'saturday'  { $desiredDayOfWeek = [System.DayOfWeek]::Saturday }
        'sunday'    { $desiredDayOfWeek = [System.DayOfWeek]::Sunday }
        default {
            Write-Error "Invalid day name. Please enter a valid day of the week."
            exit 1
        }
    }

    $currentDayOfWeek = $today.DayOfWeek

    # Calculate days to add to reach the next desired day
    $daysToAdd = ($desiredDayOfWeek - $currentDayOfWeek + 7) % 7
    if ($daysToAdd -eq 0) {
        $daysToAdd = 7
    }

    $nextDesiredDate = $today.AddDays($daysToAdd)
    return $nextDesiredDate
}

# Function to handle relative days (today, tomorrow, yesterday)
function Get-RelativeDate {
    param (
        [string]$Relative
    )

    switch ($Relative.ToLower()) {
        'tomorrow'  { $adjustedDate = $today.AddDays(1) }
        'yesterday' { $adjustedDate = $today.AddDays(-1) }
        'today'     { $adjustedDate = $today }
        default {
            Write-Error "Invalid relative keyword. Use 'tomorrow', 'yesterday', or 'today'."
            exit 1
        }
    }

    return $adjustedDate
}

# Function to format the date as "yyyy-MM-dd ddd" (e.g., "2024-10-23 Wed")
function Format-DateOutput {
    param (
        [DateTime]$Date
    )

    return $Date.ToString("yyyy-MM-dd ddd")
}

# Main logic to determine if input is a day name or relative keyword
switch ($DayName.ToLower()) {
    'tomorrow'  { $outputDate = Get-RelativeDate -Relative 'tomorrow' }
    'yesterday' { $outputDate = Get-RelativeDate -Relative 'yesterday' }
    'today'     { $outputDate = Get-RelativeDate -Relative 'today' }
    default     { $outputDate = Get-NextDateFromDay -DayName $DayName }
}

# Format the output date
$formattedOutput = Format-DateOutput -Date $outputDate

Write-Output $formattedOutput
