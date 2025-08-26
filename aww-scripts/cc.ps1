<#
.SYNOPSIS
  cc.ps1 is a robust wrapper around MSVC cl.exe to compile C or C++ files.

.DESCRIPTION
  - Ensures cl.exe is available by importing the appropriate VsDevCmd environment.
  - Applies sensible defaults for Debug or Release.
  - Auto-selects language standard switches if supported by the installed toolset.
  - Lets you pass extra switches to cl that can override defaults.

.PARAMETER Source
  One or more source files to compile. Supports .c .cpp .cxx .cc

.PARAMETER Arch
  Target architecture for VsDevCmd. One of: x64, x86, arm64. Default x64.

.PARAMETER Out
  Output file name. If missing, inferred from the first source and build mode.

.PARAMETER OutDir
  Output directory. Will be created if it does not exist.

.PARAMETER Debug
  Use debug flags (/Zi /Od) instead of release (/O2 /DNDEBUG).

.PARAMETER CLArgs
  Extra arguments appended to cl, e.g. "/W4","/MD","/DNAME=1","/link","/SUBSYSTEM:CONSOLE".

.PARAMETER Std
  Auto or none for language standard detection. Default auto.

.PARAMETER ShowCommand
  Show the exact cl invocation before running it.

.PARAMETER Help
  Show essential usage help.

.EXAMPLE
  pwsh -File .\cc.ps1 -Source .\main.c

.EXAMPLE
  pwsh -File .\cc.ps1 -Source .\main.c -Out hello.exe -CLArgs "/W4","/O2","/MD"

.EXAMPLE
  pwsh -File .\cc.ps1 -Source .\main.cpp -Debug -CLArgs "/DAPP_VER=1","/std:c++20"

.EXAMPLE
  pwsh -File .\cc.ps1 -Source .\a.c,.\b.c -Out app.exe -CLArgs "/link","/SUBSYSTEM:CONSOLE"
#>

[CmdletBinding()]
param(
  [Parameter(Position = 0)]
  [string[]] $Source,

  [ValidateSet('x64','x86','arm64')]
  [string] $Arch = 'x64',

  [string] $Out,

  [string] $OutDir,

  [switch] $BuildDebug,

  [string[]] $CLArgs,

  [ValidateSet('none','auto')]
  [string] $Std = 'auto',

  [switch] $ShowCommand,

  [Alias('?','h')][switch] $Help
)

$ErrorActionPreference = 'Stop'

function Show-Usage {
  $scriptName = if ($PSCommandPath) { Split-Path -Leaf $PSCommandPath } else { 'cc.ps1' }
  $usage = @"
Usage:
  pwsh -File .\$scriptName -Source .\main.c
  pwsh -File .\$scriptName -Source .\main.c -Out hello.exe -CLArgs "/W4","/O2","/MD"
  pwsh -File .\$scriptName -Source .\main.cpp -Debug -CLArgs "/DAPP_VER=1","/std:c++20"
  pwsh -File .\$scriptName -Source .\a.c,.\b.c -Out app.exe -CLArgs "/link","/SUBSYSTEM:CONSOLE"

Options:
  -Source        One or more source files. Supports .c .cpp .cxx .cc
  -Arch          Target architecture: x64 x86 arm64. Default x64
  -Out           Output file name. .exe or .obj inferred
  -OutDir        Output directory. Created if missing
  -Debug         Use debug flags (/Zi /Od) instead of release (/O2 /DNDEBUG)
  -CLArgs        Extra arguments appended to cl
  -Std           auto or none for language standard detection. Default auto
  -ShowCommand   Show the exact cl invocation
  -Help, -?      Show this help

Notes:
  -CLArgs are appended last so they can override defaults.
"@
  Write-Host $usage
}

if ($Help -or -not $Source -or $Source.Count -eq 0) {
  Show-Usage
  exit 0
}

function Find-VsDevCmd {
  $candidates = @()
  $vswhereDefault = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
  if (Test-Path $vswhereDefault) { $candidates += $vswhereDefault }
  $vswhereInPath = Get-Command vswhere.exe -ErrorAction SilentlyContinue
  if ($vswhereInPath) { $candidates += $vswhereInPath.Path }

  foreach ($vsw in $candidates | Select-Object -Unique) {
    try {
      $installPath = & $vsw -latest -products * `
        -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
        -property installationPath 2>$null
      if ($installPath) {
        $devCmd = Join-Path $installPath 'Common7\Tools\VsDevCmd.bat'
        if (Test-Path $devCmd) { return $devCmd }
      }
    } catch {}
  }

  foreach ($y in '2022','2019','2017') {
    foreach ($e in 'Community','Professional','Enterprise','BuildTools') {
      foreach ($root in 'C:\Program Files','C:\Program Files (x86)') {
        $devCmd = Join-Path $root "Microsoft Visual Studio\$y\$e\Common7\Tools\VsDevCmd.bat"
        if (Test-Path $devCmd) { return $devCmd }
      }
    }
  }
  return $null
}

function Import-VSDevEnvironment {
  param(
    [Parameter(Mandatory=$true)][string]$VsDevCmd,
    [Parameter(Mandatory=$true)][string]$Arch
  )
  $cmdLine = "call `"$VsDevCmd`" -arch=$Arch && set"
  $envDump = & cmd.exe /c $cmdLine 2>$null
  if (-not $envDump) { throw "VsDevCmd.bat failed or produced no environment. Path: $VsDevCmd" }

  foreach ($line in $envDump) {
    if ($line -match '^(.*?)=(.*)$') {
      $name  = $matches[1]
      $value = $matches[2]
      if ($name -and $name -notmatch '^\s+$') {
        Set-Item -Path ("Env:$name") -Value $value -Force
      }
    }
  }
}

function Ensure-CL {
  $clPath = Get-Command cl.exe -ErrorAction SilentlyContinue
  if ($clPath) { return $true }
  $vsDev = Find-VsDevCmd
  if (-not $vsDev) { throw "Could not find VsDevCmd.bat. Install Visual Studio Build Tools or Visual Studio with C++ workload." }
  Import-VSDevEnvironment -VsDevCmd $vsDev -Arch $Arch
  $clPath = Get-Command cl.exe -ErrorAction SilentlyContinue
  if (-not $clPath) { throw "cl.exe still not on PATH after VsDevCmd. Installation appears broken." }
  return $true
}

$script:ClHelp = $null
function Get-CLHelp {
  if ($script:ClHelp) { return $script:ClHelp }
  try { $script:ClHelp = (& cl /? 2>&1 | Out-String) } catch { $script:ClHelp = "" }
  return $script:ClHelp
}

function Get-CStdSwitch {
  $help = Get-CLHelp
  if ($help -match '/std:c17') { return '/std:c17' }
  if ($help -match '/std:c11') { return '/std:c11' }
  return $null
}

function Get-CxxStdSwitch {
  $help = Get-CLHelp
  if ($help -match '/std:c\+\+20')     { return '/std:c++20' }
  if ($help -match '/std:c\+\+17')     { return '/std:c++17' }
  if ($help -match '/std:c\+\+latest') { return '/std:c++latest' }
  return $null
}

function Get-FullPath {
  param([string]$Path)
  return [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath (Split-Path -Path $Path -Parent) -ErrorAction SilentlyContinue ?? (Get-Location)).Path + [System.IO.Path]::DirectorySeparatorChar + [System.IO.Path]::GetFileName($Path))
}

function Resolve-Output {
  param(
    [string[]]$Src,
    [string]$OutName,
    [string]$Dir
  )
  $isObjOnly = ($CLArgs -contains '/c')
  if (-not $OutName) {
    if ($isObjOnly -and $Src.Count -eq 1) {
      $base = [IO.Path]::GetFileNameWithoutExtension($Src[0])
      $OutName = "$base.obj"
    } else {
      $base = [IO.Path]::GetFileNameWithoutExtension($Src[0])
      $OutName = "$base.exe"
    }
  }
  if (-not [IO.Path]::GetExtension($OutName)) {
    if ($isObjOnly) { $OutName = "$OutName.obj" } else { $OutName = "$OutName.exe" }
  }
  if ($Dir) {
    if (-not (Test-Path $Dir)) { New-Item -ItemType Directory -Force -Path $Dir | Out-Null }
    return [IO.Path]::GetFullPath((Join-Path $Dir $OutName))
  }
  return [IO.Path]::GetFullPath((Join-Path (Get-Location) $OutName))
}

Ensure-CL | Out-Null

$resolvedSources = @()
foreach ($s in $Source) {
  $p = Resolve-Path -LiteralPath $s -ErrorAction Stop
  $resolvedSources += $p.Path
}
if ($resolvedSources.Count -eq 0) { throw "No source files resolved." }

$exts = $resolvedSources | ForEach-Object { [IO.Path]::GetExtension($_).ToLowerInvariant() }
$hasCpp = $exts | Where-Object { $_ -in @('.cpp','.cxx','.cc') } | Select-Object -First 1
$hasC   = $exts | Where-Object { $_ -eq '.c' } | Select-Object -First 1
$lang = if ($hasCpp) { 'c++' } elseif ($hasC) { 'c' } else { 'unknown' }

$argv = @()
$argv += '/nologo'

if ($BuildDebug) { $argv += '/Zi','/Od' } else { $argv += '/O2','/DNDEBUG' }

if ($lang -eq 'c++') { $argv += '/EHsc' }

$stdAlreadySpecified = $false
if ($CLArgs) {
  foreach ($a in $CLArgs) { if ($a -match '^/std:') { $stdAlreadySpecified = $true; break } }
}
if ($Std -eq 'auto' -and -not $stdAlreadySpecified) {
  if     ($lang -eq 'c')   { $s = Get-CStdSwitch;   if ($s) { $argv += $s } }
  elseif ($lang -eq 'c++') { $s = Get-CxxStdSwitch; if ($s) { $argv += $s } }
}

$outPath = Resolve-Output -Src $resolvedSources -OutName $Out -Dir $OutDir
$argv += "/Fe:`"$outPath`""
$argv += $resolvedSources
if ($CLArgs) { $argv += $CLArgs }

if ($ShowCommand) { Write-Host "cl" ($argv -join ' ') }

& cl @argv
$code = $LASTEXITCODE
if ($code -ne 0) { throw "cl failed with exit code $code" }
exit $code
