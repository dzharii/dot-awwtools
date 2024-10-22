param (
    [Parameter(Mandatory=$true)]
    [string]$DayName
)
$ErrorActionPreference = "Stop"

$today = Get-Date

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
$nextDesiredDateString = $nextDesiredDate.ToString("yyyy-MM-dd")

Write-Output $nextDesiredDateString
