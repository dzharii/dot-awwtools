param (
    [Parameter(Mandatory=$true)]
    [string]$At
)

# Check for administrative privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    $scriptPath = $MyInvocation.MyCommand.Path
    Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -At `"$At`"" -Verb RunAs
    exit
}

# Set error action preference to stop on first error
$ErrorActionPreference = "Stop"

# Set task name
$taskName = "SHUT UP AND SHUT DOWN!"

# Split the At parameter to get the hour and minute
$hour, $minute = $At.Split(':')

# Check if the task exists
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

if ($task -eq $null) {
    # Create the task if it doesn't exist
    $action = New-ScheduledTaskAction -Execute "C:\Windows\System32\shutdown.exe" -Argument "/s /t 120"
    $trigger = New-ScheduledTaskTrigger -Daily -At "$($hour):$($minute)"
    $settings = New-ScheduledTaskSettingsSet
    $principal = New-ScheduledTaskPrincipal -UserID "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    $task = New-ScheduledTask -Action $action -Trigger $trigger -Settings $settings -Principal $principal

    Register-ScheduledTask -TaskName $taskName -InputObject $task
} else {
    # Update the trigger time if the task exists
    $task.Triggers[0].StartBoundary = (Get-Date -Hour $hour -Minute $minute -Second 0).ToString("s")
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Register-ScheduledTask -TaskName $taskName -InputObject $task
}

Write-Host "Task '$taskName' updated or created with trigger time $($hour):$($minute)"
