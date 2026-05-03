param(
    [Parameter(Mandatory = $false, Position = 0)]
    [string]$Command = "help"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# PowerShell 7 can turn native command failures into errors when this preference is enabled.
# This script checks $LASTEXITCODE manually for Git commands, so native command errors should not throw early.
if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
    $PSNativeCommandUseErrorActionPreference = $false
}

$SCRIPT:COMMAND_NAME = "gitwt.ps1"
$SCRIPT:COMMAND_HELP = "help"
$SCRIPT:COMMAND_NEW  = "new"
$SCRIPT:COMMAND_LIST = "list"
$SCRIPT:COMMAND_DOC  = "doc"

$SCRIPT:DOC_FILE_NAME = "gitwt.md.html"
$SCRIPT:InvocationLine = $SCRIPT:COMMAND_NAME

function Get-ScriptFolderPath {
    if ($PSScriptRoot) {
        return $PSScriptRoot
    }

    if ($MyInvocation.MyCommand.Definition) {
        return Split-Path -Parent $MyInvocation.MyCommand.Definition
    }

    return (Get-Location).Path
}

$SCRIPT:ScriptFolderPath = Get-ScriptFolderPath

function Use-Color {
    if ($env:NO_COLOR) {
        return $false
    }

    if (-not (Get-Variable -Name PSStyle -ErrorAction SilentlyContinue)) {
        return $false
    }

    return $true
}

function Format-StyledText {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Style
    )

    if (-not (Use-Color)) {
        return $Text
    }

    return $Style + $Text + $PSStyle.Reset
}

function Format-Title {
    param([string]$Text)

    return Format-StyledText -Text $Text -Style $PSStyle.Foreground.Cyan
}

function Format-Command {
    param([string]$Text)

    # Plain blue is hard to read on black terminal backgrounds.
    return Format-StyledText -Text $Text -Style $PSStyle.Foreground.BrightCyan
}

function Format-Muted {
    param([string]$Text)

    # BrightBlack is too dim in many console themes.
    return Format-StyledText -Text $Text -Style $PSStyle.Foreground.White
}

function Format-Ok {
    param([string]$Text)

    return Format-StyledText -Text $Text -Style $PSStyle.Foreground.Green
}

function Format-Warn {
    param([string]$Text)

    return Format-StyledText -Text $Text -Style $PSStyle.Foreground.Yellow
}

function Format-Error {
    param([string]$Text)

    return Format-StyledText -Text $Text -Style $PSStyle.Foreground.Red
}

function Format-ByKind {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Text,

        [Parameter(Mandatory = $false)]
        [ValidateSet("normal", "ok", "warn", "error", "muted")]
        [string]$Kind = "normal"
    )

    switch ($Kind) {
        "ok" {
            return Format-Ok -Text $Text
        }

        "warn" {
            return Format-Warn -Text $Text
        }

        "error" {
            return Format-Error -Text $Text
        }

        "muted" {
            return Format-Muted -Text $Text
        }

        default {
            return $Text
        }
    }
}

function Get-TerminalWidth {
    try {
        $width = [Console]::WindowWidth
        $width = [Math]::Max(60, $width)
        $width = [Math]::Min($width, 120)
        return $width
    }
    catch {
        return 100
    }
}

function Write-Blank {
    Write-Host ""
}

function Write-CommandHeader {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommandLine
    )

    $line = Format-Title -Text $CommandLine
    Write-Host $line
}

function Write-Section {
    param([string]$Title)

    Write-Blank

    $line = Format-Title -Text $Title
    Write-Host $line

    Write-Blank
}

function Write-Field {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Value,

        [Parameter(Mandatory = $false)]
        [ValidateSet("normal", "ok", "warn", "error", "muted")]
        [string]$Kind = "normal"
    )

    $label = $Name.PadRight(13)
    $labelText = Format-Muted -Text $label
    $valueText = Format-ByKind -Text $Value -Kind $Kind
    $line = $labelText + $valueText

    Write-Host $line
}

function Wrap-Text {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [int]$Width
    )

    if ($Width -lt 10) {
        return @($Text)
    }

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return @("")
    }

    $words = $Text -split "\s+"
    $lines = New-Object System.Collections.Generic.List[string]
    $line = ""

    foreach ($word in $words) {
        if ($line.Length -eq 0) {
            $line = $word
            continue
        }

        $candidate = $line + " " + $word

        if ($candidate.Length -le $Width) {
            $line = $candidate
        }
        else {
            [void]$lines.Add($line)
            $line = $word
        }
    }

    if ($line.Length -gt 0) {
        [void]$lines.Add($line)
    }

    return $lines.ToArray()
}

function Limit-Text {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [int]$Width
    )

    if ($Width -le 0) {
        return ""
    }

    if ($Text.Length -le $Width) {
        return $Text
    }

    if ($Width -le 3) {
        return $Text.Substring(0, $Width)
    }

    return $Text.Substring(0, $Width - 3) + "..."
}

function Write-WrappedLine {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Indent,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Text,

        [Parameter(Mandatory = $false)]
        [ValidateSet("normal", "muted", "warn", "error", "ok")]
        [string]$Kind = "normal"
    )

    $width = Get-TerminalWidth
    $available = $width - $Indent.Length

    if ($available -lt 20) {
        $available = 20
    }

    $lines = @(Wrap-Text -Text $Text -Width $available)

    foreach ($line in $lines) {
        $styledLine = Format-ByKind -Text $line -Kind $Kind
        $outputLine = $Indent + $styledLine
        Write-Host $outputLine
    }
}

function ConvertTo-ShellQuotedArg {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Value
    )

    if ($Value -eq "") {
        return '""'
    }

    if ($Value -match "^[a-zA-Z0-9_./:=@%+,~-]+$") {
        return $Value
    }

    $escaped = $Value.Replace('"', '\"')
    return '"' + $escaped + '"'
}

function ConvertTo-CommandLine {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Executable,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $parts = New-Object System.Collections.Generic.List[string]
    [void]$parts.Add($Executable)

    foreach ($arg in $Arguments) {
        $quoted = ConvertTo-ShellQuotedArg -Value $arg
        [void]$parts.Add($quoted)
    }

    return ($parts.ToArray() -join " ")
}

function Write-CommandLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommandLine
    )

    Write-WrappedLine -Indent "  " -Text $CommandLine -Kind "muted"
}

function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Args,

        [Parameter(Mandatory = $false)]
        [switch]$AllowFailure,

        [Parameter(Mandatory = $false)]
        [switch]$LogCommand
    )

    $commandLine = ConvertTo-CommandLine -Executable "git" -Arguments $Args

    if ($LogCommand) {
        Write-CommandLog -CommandLine $commandLine
    }

    $output = & git @Args 2>&1
    $exitCode = $LASTEXITCODE

    if (($exitCode -ne 0) -and (-not $AllowFailure)) {
        $message = ($output | Out-String).Trim()

        if (-not $message) {
            $message = "Git command failed with exit code " + $exitCode + "."
        }

        throw $commandLine + " failed. " + $message
    }

    return [pscustomobject]@{
        ExitCode    = $exitCode
        Output      = @($output)
        CommandLine = $commandLine
    }
}

function Test-GitAvailable {
    try {
        $null = & git --version 2>$null
        return ($LASTEXITCODE -eq 0)
    }
    catch {
        return $false
    }
}

function Assert-GitAvailable {
    if (-not (Test-GitAvailable)) {
        throw "Git was not found on PATH."
    }
}

function Get-GitRepositoryRoot {
    Assert-GitAvailable

    $result = Invoke-Git -Args @("rev-parse", "--show-toplevel") -AllowFailure

    if ($result.ExitCode -ne 0) {
        return $null
    }

    $firstLine = $result.Output | Select-Object -First 1

    if ($null -eq $firstLine) {
        return $null
    }

    $root = $firstLine.ToString().Trim()

    if (-not $root) {
        return $null
    }

    return $root
}

function Assert-InGitRepository {
    $root = Get-GitRepositoryRoot

    if (-not $root) {
        throw $SCRIPT:COMMAND_NAME + " must be run inside a Git repository for this command."
    }

    return $root
}

function Get-ShortHead {
    $result = Invoke-Git -Args @("rev-parse", "--short", "HEAD") -AllowFailure

    if ($result.ExitCode -ne 0) {
        return $null
    }

    $firstLine = $result.Output | Select-Object -First 1

    if ($null -eq $firstLine) {
        return $null
    }

    $shortHead = $firstLine.ToString().Trim()

    if (-not $shortHead) {
        return $null
    }

    return $shortHead
}

function Get-CurrentBranchName {
    $result = Invoke-Git -Args @("branch", "--show-current") -AllowFailure

    if ($result.ExitCode -ne 0) {
        return $null
    }

    $firstLine = $result.Output | Select-Object -First 1

    if ($null -eq $firstLine) {
        return $null
    }

    $branch = $firstLine.ToString().Trim()

    if (-not $branch) {
        return $null
    }

    return $branch
}

function Get-BranchDisplay {
    $branch = Get-CurrentBranchName

    if ($branch) {
        return $branch
    }

    $shortHead = Get-ShortHead

    if ($shortHead) {
        return "detached:" + $shortHead
    }

    return "unknown"
}

function Get-StartPoint {
    $branch = Get-CurrentBranchName

    if ($branch) {
        return $branch
    }

    $shortHead = Get-ShortHead

    if ($shortHead) {
        return "HEAD"
    }

    throw "Could not resolve the current Git branch or HEAD."
}

function Get-StatusInfo {
    $result = Invoke-Git -Args @("status", "--porcelain") -AllowFailure

    if ($result.ExitCode -ne 0) {
        return [pscustomobject]@{
            Display      = "unknown"
            ChangedCount = 0
            IsClean      = $false
            Kind         = "warn"
        }
    }

    $lines = @($result.Output | Where-Object {
        ($null -ne $_) -and ($_.ToString().Length -gt 0)
    })

    $count = $lines.Count

    if ($count -eq 0) {
        return [pscustomobject]@{
            Display      = "clean"
            ChangedCount = 0
            IsClean      = $true
            Kind         = "ok"
        }
    }

    if ($count -eq 1) {
        $suffix = "file"
    }
    else {
        $suffix = "files"
    }

    $display = $count.ToString() + " changed " + $suffix

    return [pscustomobject]@{
        Display      = $display
        ChangedCount = $count
        IsClean      = $false
        Kind         = "warn"
    }
}

function Get-RepositoryContext {
    $root = Get-GitRepositoryRoot

    if (-not $root) {
        return $null
    }

    $rootItem = Get-Item -LiteralPath $root
    $repoName = $rootItem.Name
    $parentPath = Split-Path -Parent $root

    $timestamp = Get-Date -Format "yyyy-MM-ddTHH-mm"
    $targetName = $repoName + "-wt-" + $timestamp
    $targetPath = Join-Path $parentPath $targetName
    $targetDisplay = Join-Path ".." $targetName

    $branchDisplay = Get-BranchDisplay
    $startPoint = Get-StartPoint
    $shortHead = Get-ShortHead
    $status = Get-StatusInfo

    return [pscustomobject]@{
        Root          = $root
        RepoName      = $repoName
        ParentPath    = $parentPath
        BranchDisplay = $branchDisplay
        StartPoint    = $startPoint
        ShortHead     = $shortHead
        Status        = $status
        TargetName    = $targetName
        TargetPath    = $targetPath
        TargetDisplay = $targetDisplay
    }
}

function Normalize-PathForCompare {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        $resolved = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
    }
    catch {
        $resolved = [System.IO.Path]::GetFullPath($Path)
    }

    $resolved = $resolved.TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )

    if ($IsWindows) {
        return $resolved.ToLowerInvariant()
    }

    return $resolved
}

function Convert-BranchRefToDisplay {
    param(
        [AllowNull()]
        [string]$BranchRef,

        [AllowNull()]
        [string]$Head,

        [bool]$Detached
    )

    if ($Detached) {
        if ($Head) {
            return $Head.Substring(0, [Math]::Min(7, $Head.Length))
        }

        return "detached"
    }

    if (-not $BranchRef) {
        if ($Head) {
            return $Head.Substring(0, [Math]::Min(7, $Head.Length))
        }

        return "unknown"
    }

    return ($BranchRef -replace "^refs/heads/", "")
}

function Get-Worktrees {
    param(
        [Parameter(Mandatory = $false)]
        [switch]$LogCommand
    )

    $result = Invoke-Git -Args @("worktree", "list", "--porcelain") -AllowFailure -LogCommand:$LogCommand

    if ($result.ExitCode -ne 0) {
        return @()
    }

    $records = New-Object System.Collections.Generic.List[object]
    $current = @{}

    foreach ($rawLine in $result.Output) {
        $line = $rawLine.ToString()

        if ([string]::IsNullOrWhiteSpace($line)) {
            if ($current.ContainsKey("worktree")) {
                [void]$records.Add([hashtable]$current)
            }

            $current = @{}
            continue
        }

        if ($line -match "^worktree\s+(.+)$") {
            $current["worktree"] = $Matches[1]
            continue
        }

        if ($line -match "^HEAD\s+(.+)$") {
            $current["HEAD"] = $Matches[1]
            continue
        }

        if ($line -match "^branch\s+(.+)$") {
            $current["branch"] = $Matches[1]
            continue
        }

        if ($line -eq "detached") {
            $current["detached"] = $true
            continue
        }

        if ($line -match "^locked(?:\s+(.+))?$") {
            $current["locked"] = $true
            $current["lockReason"] = $Matches[1]
            continue
        }

        if ($line -match "^prunable(?:\s+(.+))?$") {
            $current["prunable"] = $true
            $current["prunableReason"] = $Matches[1]
            continue
        }

        if ($line -eq "bare") {
            $current["bare"] = $true
            continue
        }
    }

    if ($current.ContainsKey("worktree")) {
        [void]$records.Add([hashtable]$current)
    }

    $repoRoot = Get-GitRepositoryRoot
    $repoRootComparable = $null

    if ($repoRoot) {
        $repoRootComparable = Normalize-PathForCompare -Path $repoRoot
    }

    $items = New-Object System.Collections.Generic.List[object]

    foreach ($record in $records) {
        $path = [string]$record["worktree"]

        if ($record.ContainsKey("HEAD")) {
            $head = [string]$record["HEAD"]
        }
        else {
            $head = $null
        }

        if ($record.ContainsKey("branch")) {
            $branchRef = [string]$record["branch"]
        }
        else {
            $branchRef = $null
        }

        $detached = $record.ContainsKey("detached")
        $locked = $record.ContainsKey("locked")
        $prunable = $record.ContainsKey("prunable")
        $bare = $record.ContainsKey("bare")

        $pathComparable = Normalize-PathForCompare -Path $path
        $isCurrent = $false

        if ($repoRootComparable) {
            $isCurrent = ($pathComparable -eq $repoRootComparable)
        }

        if ($isCurrent) {
            $kind = "current"
        }
        elseif ($detached) {
            $kind = "detached"
        }
        elseif ($bare) {
            $kind = "bare"
        }
        else {
            $kind = "worktree"
        }

        $branchDisplay = Convert-BranchRefToDisplay -BranchRef $branchRef -Head $head -Detached $detached

        if ($locked) {
            $kind = $kind + "+lock"
        }

        if ($prunable) {
            $kind = "stale"
        }

        if ($head) {
            $commit = $head.Substring(0, [Math]::Min(7, $head.Length))
        }
        else {
            $commit = ""
        }

        if ($record.ContainsKey("lockReason")) {
            $lockReason = [string]$record["lockReason"]
        }
        else {
            $lockReason = ""
        }

        if ($record.ContainsKey("prunableReason")) {
            $pruneReason = [string]$record["prunableReason"]
        }
        else {
            $pruneReason = ""
        }

        $item = [pscustomobject]@{
            Kind        = $kind
            Branch      = $branchDisplay
            Commit      = $commit
            Path        = $path
            IsCurrent   = [bool]$isCurrent
            IsDetached  = [bool]$detached
            IsPrunable  = [bool]$prunable
            IsLocked    = [bool]$locked
            LockReason  = $lockReason
            PruneReason = $pruneReason
        }

        [void]$items.Add($item)
    }

    return $items.ToArray()
}

function Invoke-WorktreePruneSafely {
    param(
        [Parameter(Mandatory = $false)]
        [switch]$LogCommand
    )

    $result = Invoke-Git -Args @("worktree", "prune") -AllowFailure -LogCommand:$LogCommand
    return ($result.ExitCode -eq 0)
}

function Write-CommandHelp {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommandText,

        [Parameter(Mandatory = $true)]
        [string]$Description,

        [Parameter(Mandatory = $false)]
        [string[]]$Details = @()
    )

    $width = Get-TerminalWidth
    $isNarrow = ($width -lt 72)
    $commandWidth = 18

    if ($isNarrow) {
        $commandTextStyled = Format-Command -Text $CommandText
        Write-Host ("  " + $commandTextStyled)

        Write-WrappedLine -Indent "      " -Text $Description

        foreach ($detail in $Details) {
            Write-WrappedLine -Indent "      " -Text $detail -Kind "muted"
        }

        return
    }

    $indent = "  "
    $commandColumn = $CommandText.PadRight($commandWidth)
    $commandColumnStyled = Format-Command -Text $commandColumn
    $continuationPrefix = $indent + (" " * $commandWidth)

    $descriptionWidth = $width - $indent.Length - $commandWidth

    if ($descriptionWidth -lt 20) {
        $descriptionWidth = 20
    }

    $descriptionLines = @(Wrap-Text -Text $Description -Width $descriptionWidth)

    if ($descriptionLines.Count -eq 0) {
        $descriptionLines = @("")
    }

    $firstLine = $indent + $commandColumnStyled + $descriptionLines[0]
    Write-Host $firstLine

    for ($i = 1; $i -lt $descriptionLines.Count; $i++) {
        $line = $continuationPrefix + $descriptionLines[$i]
        Write-Host $line
    }

    foreach ($detail in $Details) {
        $detailLines = @(Wrap-Text -Text $detail -Width $descriptionWidth)

        foreach ($detailLine in $detailLines) {
            $detailLineStyled = Format-Muted -Text $detailLine
            $line = $continuationPrefix + $detailLineStyled
            Write-Host $line
        }
    }
}

function Get-WorktreeKindStyle {
    param([string]$Kind)

    if ($Kind -eq "current") {
        return "ok"
    }

    if (($Kind -eq "detached") -or ($Kind -like "*lock*") -or ($Kind -eq "stale")) {
        return "warn"
    }

    return "normal"
}

function Write-WorktreeList {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Worktrees
    )

    Write-Section "Current worktrees"

    if ((-not $Worktrees) -or ($Worktrees.Count -eq 0)) {
        Write-WrappedLine -Indent "  " -Text "No worktree information available." -Kind "muted"
        return
    }

    $width = Get-TerminalWidth
    $useWide = ($width -ge 88)

    if (-not $useWide) {
        foreach ($wt in $Worktrees) {
            $kindStyle = Get-WorktreeKindStyle -Kind $wt.Kind
            $kindText = Format-ByKind -Text $wt.Kind -Kind $kindStyle
            Write-Host ("  " + $kindText)

            Write-Field -Name "    Branch" -Value $wt.Branch
            Write-Field -Name "    Path" -Value $wt.Path -Kind "muted"

            if ($wt.IsLocked -and $wt.LockReason) {
                Write-Field -Name "    Lock" -Value $wt.LockReason -Kind "warn"
            }

            if ($wt.IsPrunable -and $wt.PruneReason) {
                Write-Field -Name "    Stale" -Value $wt.PruneReason -Kind "warn"
            }

            Write-Blank
        }

        return
    }

    $kindWidth = 12
    $branchWidth = 24
    $pathWidth = $width - 4 - $kindWidth - $branchWidth

    if ($pathWidth -lt 24) {
        $pathWidth = 24
    }

    $kindHeader = "Kind".PadRight($kindWidth)
    $branchHeader = "Branch".PadRight($branchWidth)
    $pathHeader = "Path"

    $kindHeaderStyled = Format-Muted -Text $kindHeader
    $branchHeaderStyled = Format-Muted -Text $branchHeader
    $pathHeaderStyled = Format-Muted -Text $pathHeader

    $headerLine = "  " + $kindHeaderStyled + $branchHeaderStyled + $pathHeaderStyled
    Write-Host $headerLine

    foreach ($wt in $Worktrees) {
        $kind = Limit-Text -Text $wt.Kind -Width ($kindWidth - 1)
        $branch = Limit-Text -Text $wt.Branch -Width ($branchWidth - 1)
        $path = Limit-Text -Text $wt.Path -Width $pathWidth

        $kindPadded = $kind.PadRight($kindWidth)
        $branchPadded = $branch.PadRight($branchWidth)

        $kindStyle = Get-WorktreeKindStyle -Kind $wt.Kind
        $kindOut = Format-ByKind -Text $kindPadded -Kind $kindStyle
        $pathOut = Format-Muted -Text $path

        $line = "  " + $kindOut + $branchPadded + $pathOut
        Write-Host $line
    }
}

function Write-ContextBlock {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Context
    )

    if ($Context.BranchDisplay -like "detached:*") {
        $branchKind = "warn"
    }
    else {
        $branchKind = "normal"
    }

    Write-Field -Name "Repository" -Value $Context.RepoName
    Write-Field -Name "Branch" -Value $Context.BranchDisplay -Kind $branchKind
    Write-Field -Name "Status" -Value $Context.Status.Display -Kind $Context.Status.Kind
    Write-Field -Name "Root" -Value $Context.Root -Kind "muted"
}

function Write-Notes {
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [object]$Context
    )

    if (-not $Context) {
        return
    }

    if ($Context.Status.ChangedCount -gt 0) {
        Write-Section "Note"

        $note = "This repository has uncommitted changes. A new worktree starts from the current branch or HEAD. Uncommitted file changes are not copied."
        Write-WrappedLine -Indent "  " -Text $note -Kind "warn"
    }
}

function Write-Help {
    $context = $null
    $gitAvailable = Test-GitAvailable

    try {
        if ($gitAvailable) {
            $context = Get-RepositoryContext
        }
    }
    catch {
        $context = $null
    }

    Write-CommandHeader -CommandLine $SCRIPT:InvocationLine
    Write-Blank

    if ($context) {
        Write-ContextBlock -Context $context
    }
    else {
        if (-not $gitAvailable) {
            Write-WrappedLine -Indent "" -Text "Git was not found on PATH." -Kind "error"
        }
        else {
            Write-WrappedLine -Indent "" -Text "No Git repository detected." -Kind "warn"
        }
    }

    Write-Section "Commands"

    if ($context) {
        $newCommand = $SCRIPT:COMMAND_NAME + " " + $SCRIPT:COMMAND_NEW
        $listCommand = $SCRIPT:COMMAND_NAME + " " + $SCRIPT:COMMAND_LIST
        $docCommand = $SCRIPT:COMMAND_NAME + " " + $SCRIPT:COMMAND_DOC

        $fromDetail = "From:    " + $context.BranchDisplay
        $targetDetail = "Target:  " + $context.TargetDisplay

        Write-CommandHelp -CommandText $newCommand -Description "Create a new sibling worktree" -Details @($fromDetail, $targetDetail)
        Write-Blank

        Write-CommandHelp -CommandText $listCommand -Description "Show worktrees for this repository"
        Write-Blank

        Write-CommandHelp -CommandText $docCommand -Description "Open the local Git worktree reference"
    }
    else {
        $newCommand = $SCRIPT:COMMAND_NAME + " " + $SCRIPT:COMMAND_NEW
        $listCommand = $SCRIPT:COMMAND_NAME + " " + $SCRIPT:COMMAND_LIST
        $docCommand = $SCRIPT:COMMAND_NAME + " " + $SCRIPT:COMMAND_DOC

        Write-CommandHelp -CommandText $newCommand -Description "Create a new sibling worktree" -Details @("Requires a Git repository")
        Write-Blank

        Write-CommandHelp -CommandText $listCommand -Description "Show worktrees for this repository" -Details @("Requires a Git repository")
        Write-Blank

        Write-CommandHelp -CommandText $docCommand -Description "Open the local Git worktree reference"
    }

    if ($context) {
        $null = Invoke-WorktreePruneSafely
        $worktrees = @(Get-Worktrees)

        Write-WorktreeList -Worktrees $worktrees
        Write-Notes -Context $context
    }
}

function Write-List {
    $null = Assert-InGitRepository

    Write-CommandHeader -CommandLine $SCRIPT:InvocationLine

    Write-Section "Commands"
    Write-WrappedLine -Indent "" -Text "Refreshing worktree metadata..." -Kind "muted"
    $null = Invoke-WorktreePruneSafely -LogCommand

    Write-Blank
    Write-WrappedLine -Indent "" -Text "Reading worktrees..." -Kind "muted"
    $worktrees = @(Get-Worktrees -LogCommand)

    Write-WorktreeList -Worktrees $worktrees
}

function New-Worktree {
    $context = Get-RepositoryContext

    if (-not $context) {
        throw $SCRIPT:COMMAND_NAME + " must be run inside a Git repository for this command."
    }

    if (Test-Path -LiteralPath $context.TargetPath) {
        throw "Target worktree folder already exists: " + $context.TargetPath
    }

    Write-CommandHeader -CommandLine $SCRIPT:InvocationLine
    Write-Blank

    Write-Field -Name "Repository" -Value $context.RepoName
    Write-Field -Name "From" -Value $context.BranchDisplay
    Write-Field -Name "Target" -Value $context.TargetPath -Kind "muted"

    if ($context.Status.ChangedCount -gt 0) {
        Write-Blank

        $warning = "This repository has uncommitted changes. They will not be copied into the new worktree."
        Write-WrappedLine -Indent "" -Text $warning -Kind "warn"
    }

    Write-Section "Commands"
    Write-WrappedLine -Indent "" -Text "Creating worktree..." -Kind "muted"

    $gitArgs = @(
        "worktree",
        "add",
        "--detach",
        $context.TargetPath,
        $context.StartPoint
    )

    $result = Invoke-Git -Args $gitArgs -AllowFailure -LogCommand

    if ($result.ExitCode -ne 0) {
        $message = ($result.Output | Out-String).Trim()

        if (-not $message) {
            $message = "Unable to create worktree."
        }

        throw $result.CommandLine + " failed. " + $message
    }

    Write-Blank
    Write-Field -Name "Created" -Value $context.TargetPath -Kind "ok"

    if ($context.BranchDisplay -like "detached:*") {
        $modeKind = "warn"
    }
    else {
        $modeKind = "normal"
    }

    $mode = "detached from " + $context.BranchDisplay
    Write-Field -Name "Mode" -Value $mode -Kind $modeKind

    Write-Blank
    Write-WrappedLine -Indent "" -Text "Next:" -Kind "muted"

    $cdCommand = "cd " + $context.TargetDisplay
    $switchCommand = "git switch -c <branch-name>"

    Write-Host ("  " + (Format-Command -Text $cdCommand))
    Write-Host ("  " + (Format-Command -Text $switchCommand))

    Write-Blank
    Write-WrappedLine -Indent "" -Text "Refreshing worktree metadata..." -Kind "muted"
    $null = Invoke-WorktreePruneSafely -LogCommand

    Write-Blank
    Write-WrappedLine -Indent "" -Text "Reading worktrees..." -Kind "muted"
    $worktrees = @(Get-Worktrees -LogCommand)

    Write-WorktreeList -Worktrees $worktrees
}

function Open-Doc {
    $docPath = Join-Path $SCRIPT:ScriptFolderPath $SCRIPT:DOC_FILE_NAME

    if (-not (Test-Path -LiteralPath $docPath)) {
        throw "Reference file was not found: " + $docPath
    }

    Write-CommandHeader -CommandLine $SCRIPT:InvocationLine
    Write-Blank

    Write-Field -Name "Reference" -Value $docPath -Kind "muted"

    Write-Section "Commands"

    if ($IsWindows) {
        $commandLine = ConvertTo-CommandLine -Executable "Start-Process" -Arguments @($docPath)
        Write-CommandLog -CommandLine $commandLine
        Start-Process -FilePath $docPath
    }
    elseif ($IsLinux) {
        $xdgOpen = Get-Command "xdg-open" -ErrorAction SilentlyContinue

        if (-not $xdgOpen) {
            throw "xdg-open was not found. Open this file manually: " + $docPath
        }

        $commandLine = ConvertTo-CommandLine -Executable "xdg-open" -Arguments @($docPath)
        Write-CommandLog -CommandLine $commandLine

        & xdg-open $docPath | Out-Null
    }
    elseif ($IsMacOS) {
        $commandLine = ConvertTo-CommandLine -Executable "open" -Arguments @($docPath)
        Write-CommandLog -CommandLine $commandLine

        & open $docPath | Out-Null
    }
    else {
        throw "Unsupported platform. Open this file manually: " + $docPath
    }

    Write-Blank
    Write-Field -Name "Opened" -Value $docPath -Kind "ok"
}

function Write-UnknownCommand {
    param([string]$Name)

    Write-CommandHeader -CommandLine $SCRIPT:InvocationLine
    Write-Blank

    $separator = "=" * 80
    $separatorText = Format-Error -Text $separator
    $messageText = Format-Error -Text ("Unknown command: " + $Name)

    Write-Host $separatorText
    Write-Host $messageText
    Write-Host $separatorText
    Write-Blank

    Write-Help
}

try {
    if ($Command) {
        $normalizedCommand = $Command.Trim().ToLowerInvariant()
    }
    else {
        $normalizedCommand = $SCRIPT:COMMAND_HELP
    }

    if ($normalizedCommand -eq "") {
        $SCRIPT:InvocationLine = $SCRIPT:COMMAND_NAME
        Write-Help
    }
    elseif ($normalizedCommand -eq $SCRIPT:COMMAND_HELP) {
        $SCRIPT:InvocationLine = $SCRIPT:COMMAND_NAME + " " + $SCRIPT:COMMAND_HELP
        Write-Help
    }
    elseif ($normalizedCommand -eq $SCRIPT:COMMAND_NEW) {
        $SCRIPT:InvocationLine = $SCRIPT:COMMAND_NAME + " " + $SCRIPT:COMMAND_NEW
        Assert-GitAvailable
        New-Worktree
    }
    elseif ($normalizedCommand -eq $SCRIPT:COMMAND_LIST) {
        $SCRIPT:InvocationLine = $SCRIPT:COMMAND_NAME + " " + $SCRIPT:COMMAND_LIST
        Assert-GitAvailable
        Write-List
    }
    elseif ($normalizedCommand -eq $SCRIPT:COMMAND_DOC) {
        $SCRIPT:InvocationLine = $SCRIPT:COMMAND_NAME + " " + $SCRIPT:COMMAND_DOC
        Open-Doc
    }
    else {
        $SCRIPT:InvocationLine = $SCRIPT:COMMAND_NAME + " " + $Command
        Write-UnknownCommand -Name $Command
        exit 1
    }
}
catch {
    $errorTitle = Format-Error -Text "Error"

    Write-Host $errorTitle
    Write-Blank

    Write-WrappedLine -Indent "  " -Text $_.Exception.Message -Kind "error"
    exit 1
}