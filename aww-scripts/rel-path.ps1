# Accept arguments manually instead of param()
# Usage: ./script.ps1 <absolute-target-path> [pivot-directory]

$ErrorActionPreference = "Stop"

try {
  Write-Output "[Start] Parsing arguments"
  $rawTarget = if ($args.Count -ge 1) { $args[0] } else { $null }
  $rawPivot  = if ($args.Count -ge 2) { $args[1] } else { $null }

  Write-Output "  Received TargetPath raw: '$($rawTarget)'"
  Write-Output "  Received PivotPath raw: '$($rawPivot)'"

  if ([string]::IsNullOrWhiteSpace($rawTarget)) {
    throw "Validation error: missing required first argument TargetPath"
  }

  $TargetPath = $rawTarget
  $PivotPath  = if ([string]::IsNullOrWhiteSpace($rawPivot)) { (Get-Location).Path } else { $rawPivot }
  Write-Output "  Using TargetPath: '$($TargetPath)'"
  Write-Output "  Using PivotPath: '$($PivotPath)'"

  Write-Output "[Stage] Validating TargetPath is absolute"
  if (-not [IO.Path]::IsPathFullyQualified($TargetPath)) {
    throw "Validation error: target path must be an absolute path: '$($TargetPath)'"
  }

  Write-Output "[Stage] Resolving paths to canonical forms"
  $t = (Resolve-Path -LiteralPath $TargetPath).Path
  $p = (Resolve-Path -LiteralPath $PivotPath).Path
  Write-Output "  Resolved TargetPath: '$($t)'"
  Write-Output "  Resolved PivotPath: '$($p)'"

  Write-Output "[Stage] Validating PivotPath is a directory"
  if (-not (Test-Path -LiteralPath $p -PathType Container)) {
    throw "Validation error: pivot path must be a directory: '$($PivotPath)'"
  }

  Write-Output "[Stage] Validating roots are the same"
  $tr = [IO.Path]::GetPathRoot($t).TrimEnd('\','/')
  $pr = [IO.Path]::GetPathRoot($p).TrimEnd('\','/')
  Write-Output "  Target root: '$($tr)'"
  Write-Output "  Pivot root: '$($pr)'"
  if ($tr -ne $pr) {
    throw "Validation error: paths are on different roots: base='$($pr)' target='$($tr)'"
  }

  Write-Output "[Stage] Computing relative path"
  $rel = [IO.Path]::GetRelativePath($p, $t)
  Write-Output "  Computed relative path: '$($rel)'"

  Write-Output "[Stage] Output and clipboard"
  Write-Output $rel
  Set-Clipboard -Value $rel
  Write-Output "  Copied to clipboard: '$($rel)'"

  Write-Output "[Done]"
}
catch {
  Write-Error $_.Exception.Message
  Write-Output ""
  try {
    Set-Clipboard -Value ""
    Write-Output "  Copied empty string to clipboard due to error"
  } catch {}
  exit 1
}
