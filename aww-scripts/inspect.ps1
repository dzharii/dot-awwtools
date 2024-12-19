param (
    [Parameter(Mandatory = $true)]
    [string]$Command
)

$ErrorActionPreference = "Stop"
$ThisScriptFolderPath = Split-Path -Parent $MyInvocation.MyCommand.Definition

$COMMAND_HELP = "help"
$COMMAND_WINDOW_INFORMATION = "window-information"
$COMMAND_GET_WINDOW_TITLE = "get-window-title"

$HELP_MESSAGE = @"
Usage:
   inspect.ps1 <command>
   aww run inspect <command>

Commands:
    $($COMMAND_HELP):
      Shows this help message

    $($COMMAND_WINDOW_INFORMATION):
      Generates a detailed report of the currently focused window, including:
        - Window properties (name, class name, position, etc.)
        - Process information (name, ID, CPU usage, etc.)
        - Process current working directory
        - Additional technical details such as memory usage and thread count.
      The report will be saved as a Markdown file in the current directory.

    $($COMMAND_GET_WINDOW_TITLE):
      Returns the title of the currently focused window.
"@

# -------------------------------------------
# Function: Get-FocusedWindowReport
# Description: Captures information about the currently focused window and its process.
# Generates a Markdown report with details on the window, process, and other technical metrics.
# -------------------------------------------
function Get-FocusedWindowReport {
    $result = [PSCustomObject]@{
        Success = $false
        ErrorMessage = ""
        Data = $null
    }

    try {
        Write-Host "#3bd4dcqn170 Starting process to identify the currently focused window..." -ForegroundColor Yellow

        # Load the UIAutomationClient assembly
        try {
            Add-Type -AssemblyName UIAutomationClient
        } catch {
            $result.ErrorMessage = "#8qy9x2kps7t Failed to load UIAutomationClient assembly. Ensure the required assembly is available."
            return $result
        }

        # Get the focused element (UI Automation)
        $automation = [System.Windows.Automation.AutomationElement]::FocusedElement

        if ($null -eq $automation) {
            $result.ErrorMessage = "#kv93mns81u No focused window was found."
            return $result
        }

        # Extract details from the focused window
        $windowName = $automation.Current.Name
        $className = $automation.Current.ClassName
        $processId = $automation.Current.ProcessId
        $boundingRectangle = $automation.Current.BoundingRectangle
        $controlType = $automation.Current.ControlType.ProgrammaticName
        $isEnabled = $automation.Current.IsEnabled
        $isOffscreen = $automation.Current.IsOffscreen

        # Validate process ID before proceeding
        if (-not (Get-Process -Id $processId -ErrorAction SilentlyContinue)) {
            $result.ErrorMessage = "#a7m2jkq8zu Invalid or inaccessible process ID: $processId"
            return $result
        }

        # Get the process details for the window
        try {
            $process = Get-Process -Id $processId -ErrorAction Stop
        } catch {
            $result.ErrorMessage = "#f93k4lnt67 Failed to retrieve process details for PID: $($processId). The process may not exist or is inaccessible."
            return $result
        }

        # Attempt to retrieve the process's current directory
        $currentDirectory = $null
        try {
            $dotNetProcess = [System.Diagnostics.Process]::GetProcessById($processId)
            $currentDirectory = $dotNetProcess.StartInfo.WorkingDirectory

            if ([string]::IsNullOrEmpty($currentDirectory)) {
                $mainModulePath = $process.MainModule.FileName
                $currentDirectory = [System.IO.Path]::GetDirectoryName($mainModulePath)
            }
        } catch {
            $currentDirectory = "Unknown"
        }

        # Generate the markdown report
        $windowDimensions = "Left=$($boundingRectangle.Left), Top=$($boundingRectangle.Top), Width=$($boundingRectangle.Width), Height=$($boundingRectangle.Height)"
        $BT1 = "``"
        $markdownReport = @"
# Focused Window Report

---

## Window Information
| **Property**       | **Value**                  |
|---------------------|----------------------------|
| **Name**           | $($BT1)$($windowName)$($BT1)|
| **Class Name**     | $($BT1)$($className)$($BT1)|
| **Control Type**   | $($BT1)$($controlType)$($BT1)|
| **Is Enabled**     | $($BT1)$($isEnabled)$($BT1)|
| **Is Offscreen**   | $($BT1)$($isOffscreen)$($BT1)|
| **Bounding Rectangle** | $($BT1)$($windowDimensions)$($BT1)|
| **Process ID**     | $($BT1)$($processId)$($BT1)|

---

## Process Information
| **Property**       | **Value**                  |
|---------------------|----------------------------|
| **Process Name**   | $($BT1)$($process.Name)$($BT1)|
| **Process ID**     | $($BT1)$($process.Id)$($BT1)|
| **Current Directory** | $($BT1)$($currentDirectory)$($BT1)|
| **Start Time**     | $($BT1)$($process.StartTime)$($BT1)|
| **Total CPU Time** | $($BT1)$($process.TotalProcessorTime)$($BT1)|
| **Main Window Title** | $($BT1)$($process.MainWindowTitle)$($BT1)|
| **Main Module Name** | $($BT1)$($process.MainModule.ModuleName)$($BT1)|

---

## Other Technical Details
| **Property**       | **Value**                  |
|---------------------|----------------------------|
| **Handle Count**   | $($BT1)$($process.HandleCount)$($BT1)|
| **Thread Count**   | $($BT1)$($process.Threads.Count)$($BT1)|
| **Peak Working Set** | $($BT1)$($process.PeakWorkingSet64)$($BT1) bytes |
| **Paged Memory Size** | $($BT1)$($process.PagedMemorySize64)$($BT1) bytes |
| **Non-paged Memory** | $($BT1)$($process.NonpagedSystemMemorySize64)$($BT1) bytes |
| **Working Set Size** | $($BT1)$($process.WorkingSet64)$($BT1) bytes |
| **Virtual Memory** | $($BT1)$($process.VirtualMemorySize64)$($BT1) bytes |

---

**Report generated on:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@

        $result.Data = $markdownReport
        $result.Success = $true
        return $result
    } catch {
        $result.ErrorMessage = "#n53k7qyt92 $($_.Exception.Message)"
        return $result
    }
}

# -------------------------------------------
# Function: Get-WindowTitle
# Description: Retrieves the title of the currently focused window.
# -------------------------------------------
function Get-WindowTitle {
    try {
        Add-Type @"
            using System;
            using System.Runtime.InteropServices;
            public class User32 {
                [DllImport("user32.dll")]
                public static extern IntPtr GetForegroundWindow();
                [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
                public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder lpString, int nMaxCount);
            }
"@

        $hWnd = [User32]::GetForegroundWindow()
        $title = New-Object -TypeName System.Text.StringBuilder -ArgumentList 256
        [User32]::GetWindowText($hWnd, $title, $title.Capacity)
        return $title.ToString()
    } catch {
        Write-Host "Failed to retrieve the window title. Error: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}



# -------------------------------------------
# Main Switch for Commands
# -------------------------------------------
switch ($Command.ToLower()) {
    $COMMAND_HELP {
        Write-Host $HELP_MESSAGE
    }

    $COMMAND_WINDOW_INFORMATION {
        # Call the function to generate the focused window report
        $result = Get-FocusedWindowReport
        if (-not $result.Success) {
            Write-Host $result.ErrorMessage -ForegroundColor Red
            exit 1
        } else {
            Write-Host $result.Data
        }
    }

    $COMMAND_GET_WINDOW_TITLE {
        # Call the Get-WindowTitle function to get the focused window's title
        $title = Get-WindowTitle
        if ($null -eq $title) {
            Write-Host "No window title found or an error occurred." -ForegroundColor Red
            exit 1
        } else {
            Write-Host "The current window title is: '$title'"
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
