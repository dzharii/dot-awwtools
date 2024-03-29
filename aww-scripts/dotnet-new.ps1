param(
    [Parameter(Mandatory=$true)]
    [string]$kind,
    [Parameter(Mandatory=$true)]
    [string]$name
)

$ErrorActionPreference = "Stop"

if (!$kind.Trim()) {
    Write-Host "The '-kind' (console... mvc)  parameter is required and must not be empty." -ForegroundColor Red
    exit 1
}

if (!$name.Trim()) {
    Write-Host "The '-name' (progject name) parameter is required and must not be empty." -ForegroundColor Red
    exit 1
}

#  Capitalize first letter of kind
$kindName = $kind.Substring(0, 1).ToUpper() + $kind.Substring(1)

try {
    # Create a new directory for the solution
    New-Item -ItemType Directory -Path ".\$($name)"

    # Change to the new directory
    Set-Location ".\$($name)"

    # Create a new .NET solution
    $command = "dotnet new sln -n `"$($name)`""
    Write-Host "Executing: $command"
    Invoke-Expression $command | Out-Host

    # Create the specified project type
    $projectName = "$($name)$($kindName)"
    $command = "dotnet new $kind -n `"$($projectName)`""
    Write-Host "Executing: $command"
    Invoke-Expression $command | Out-Host
    $command = "dotnet sln `"$($name).sln`" add `".\$($projectName)\$($projectName).csproj`""
    Write-Host "Executing: $command"
    Invoke-Expression $command | Out-Host

    # Create a new Class Library project
    $libraryName = "$($name)Lib"
    $command = "dotnet new classlib -n `"$($libraryName)`""
    Write-Host "Executing: $command"
    Invoke-Expression $command | Out-Host
    $command = "dotnet sln `"$($name).sln`" add `".\$($libraryName)\$($libraryName).csproj`""
    Write-Host "Executing: $command"
    Invoke-Expression $command | Out-Host

    # Create a new XUnit test project
    $testProjectName = "$($name)Tests"
    $command = "dotnet new xunit -n `"$($testProjectName)`""
    Write-Host "Executing: $command"
    Invoke-Expression $command | Out-Host
    $command = "dotnet sln `"$($name).sln`" add `".\$($testProjectName)\$($testProjectName).csproj`""
    Write-Host "Executing: $command"
    Invoke-Expression $command | Out-Host

    # Add a reference to the Class Library from the Console App and XUnit test project
    $command = "dotnet add `".\$($projectName)\$($projectName).csproj`" reference `".\$($libraryName)\$($libraryName).csproj`""
    Write-Host "Executing: $command"
    Invoke-Expression $command | Out-Host
    $command = "dotnet add `".\$($testProjectName)\$($testProjectName).csproj`" reference `".\$($libraryName)\$($libraryName).csproj`""
    Write-Host "Executing: $command"
    Invoke-Expression $command | Out-Host
}
catch {
    Write-Host "An error occurred while executing: $command`nError: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}