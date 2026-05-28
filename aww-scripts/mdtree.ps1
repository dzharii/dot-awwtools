param (
    [string]$Path = ".",
    [string]$FilterPath = "",
    [string]$FilterName = "",
    [string]$Include = "",
    [string]$Output = "output.md",
    [string]$ExcludeDirs = "",
    [string]$ExcludeFiles = "",
    [int]$MaxFileSizeKB = 1024
)

$ErrorActionPreference = "Stop"

Add-Type -TypeDefinition @"
using System.Text.RegularExpressions;

public class RegexFileFilter
{
    private Regex _regex;

    public RegexFileFilter(string pattern)
    {
        _regex = string.IsNullOrWhiteSpace(pattern) ? null : new Regex(pattern, RegexOptions.IgnoreCase);
    }

    public bool ShouldKeepFile(string fileFullName)
    {
        return _regex == null ? true : _regex.IsMatch(fileFullName);
    }
}
"@

$pathFilterRegexp = New-Object RegexFileFilter($FilterPath)
$nameFilterRegexp = New-Object RegexFileFilter($FilterName)

$ThisScriptFolderPath = Split-Path -Parent $MyInvocation.MyCommand.Definition

function Format-MarkdownCodeBlock($content, $type) {
    $result = "``````$type`n"
    $result += $content
    $result += "`n``````"
    return $result
}

function Normalize-Extension($value) {
    $value = $value.Trim()

    if ($value -eq "") {
        return ""
    }

    if ($value.StartsWith("*.")) {
        return $value.Substring(1).ToLowerInvariant()
    }

    if ($value.StartsWith(".")) {
        return $value.ToLowerInvariant()
    }

    return ".$($value.ToLowerInvariant())"
}

function Get-CodeBlockLanguage($file) {
    $extension = $file.Extension.TrimStart(".").ToLowerInvariant()
    $name = $file.Name.ToLowerInvariant()

    switch ($name) {
        "dockerfile" { return "dockerfile" }
        "makefile" { return "makefile" }
        "cmakelists.txt" { return "cmake" }
    }

    switch ($extension) {
        "mjs" { return "js" }
        "cjs" { return "js" }
        "mts" { return "ts" }
        "cts" { return "ts" }
        "tsx" { return "tsx" }
        "jsx" { return "jsx" }
        "yml" { return "yaml" }
        "yaml" { return "yaml" }
        "scss" { return "scss" }
        "sass" { return "sass" }
        "less" { return "less" }
        "gql" { return "graphql" }
        "mdx" { return "mdx" }
        "psm1" { return "powershell" }
        "psd1" { return "powershell" }
        "ps1" { return "powershell" }
        "sh" { return "bash" }
        "bash" { return "bash" }
        "zsh" { return "zsh" }
        "py" { return "python" }
        "rb" { return "ruby" }
        "rs" { return "rust" }
        "go" { return "go" }
        "java" { return "java" }
        "kt" { return "kotlin" }
        "kts" { return "kotlin" }
        "cs" { return "csharp" }
        "fs" { return "fsharp" }
        "fsx" { return "fsharp" }
        "cpp" { return "cpp" }
        "cxx" { return "cpp" }
        "cc" { return "cpp" }
        "hpp" { return "cpp" }
        "hxx" { return "cpp" }
        "h" { return "c" }
        default { return $extension }
    }
}

$defaultExtensions = @(
    ".js",
    ".jsx",
    ".mjs",
    ".cjs",
    ".ts",
    ".tsx",
    ".mts",
    ".cts",
    ".html",
    ".htm",
    ".css",
    ".scss",
    ".sass",
    ".less",
    ".vue",
    ".svelte",
    ".astro",
    ".json",
    ".jsonc",
    ".yaml",
    ".yml",
    ".toml",
    ".xml",
    ".ini",
    ".conf",
    ".config",
    ".md",
    ".mdx",
    ".txt",
    ".sh",
    ".bash",
    ".zsh",
    ".ps1",
    ".psm1",
    ".psd1",
    ".py",
    ".rb",
    ".go",
    ".rs",
    ".java",
    ".kt",
    ".kts",
    ".scala",
    ".cs",
    ".fs",
    ".fsx",
    ".c",
    ".h",
    ".cpp",
    ".cc",
    ".cxx",
    ".hpp",
    ".hxx",
    ".sql",
    ".graphql",
    ".gql",
    ".proto",
    ".dockerfile",
    ".rplc",
    ".rpli"
)

$extensionSet = New-Object "System.Collections.Generic.HashSet[string]"

if ($Include -ne "") {
    $Include.Split(",") |
        ForEach-Object { Normalize-Extension $_ } |
        Where-Object { $_ -ne "" } |
        ForEach-Object { [void]$extensionSet.Add($_) }
} else {
    $defaultExtensions | ForEach-Object { [void]$extensionSet.Add($_) }
}

$defaultExcludedDirs = @(
    ".git",
    ".svn",
    ".hg",
    ".idea",
    ".vscode",
    "node_modules",
    "bower_components",
    "jspm_packages",
    ".pnpm-store",
    ".yarn",
    ".turbo",
    ".next",
    ".nuxt",
    ".svelte-kit",
    ".astro",
    ".cache",
    ".parcel-cache",
    ".vite",
    "dist",
    "build",
    "out",
    "coverage",
    ".nyc_output",
    "target",
    ".cargo",
    "bin",
    "obj",
    "vendor",
    ".venv",
    "venv",
    "__pycache__",
    ".pytest_cache",
    ".mypy_cache",
    ".ruff_cache",
    ".gradle",
    ".mvn",
    ".terraform",
    ".serverless"
)

$defaultExcludedFiles = @(
    "package-lock.json",
    "npm-shrinkwrap.json",
    "yarn.lock",
    "pnpm-lock.yaml",
    "bun.lockb",
    "Cargo.lock",
    "Pipfile.lock",
    "poetry.lock",
    "composer.lock",
    "Gemfile.lock",
    "go.sum",
    ".DS_Store",
    "Thumbs.db",
    ".env",
    ".env.local",
    ".env.development",
    ".env.production",
    ".env.test"
)

$excludedDirSet = New-Object "System.Collections.Generic.HashSet[string]" ([System.StringComparer]::OrdinalIgnoreCase)
$defaultExcludedDirs | ForEach-Object { [void]$excludedDirSet.Add($_) }

if ($ExcludeDirs -ne "") {
    $ExcludeDirs.Split(",") |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne "" } |
        ForEach-Object { [void]$excludedDirSet.Add($_) }
}

$excludedFileSet = New-Object "System.Collections.Generic.HashSet[string]" ([System.StringComparer]::OrdinalIgnoreCase)
$defaultExcludedFiles | ForEach-Object { [void]$excludedFileSet.Add($_) }

if ($ExcludeFiles -ne "") {
    $ExcludeFiles.Split(",") |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne "" } |
        ForEach-Object { [void]$excludedFileSet.Add($_) }
}

$resolvedPath = (Resolve-Path $Path).Path
$maxFileSizeBytes = $MaxFileSizeKB * 1024

$files = Get-ChildItem -Path $resolvedPath -Recurse -File -Force |
    Where-Object {
        $file = $_

        $relativePath = $file.FullName.Substring($resolvedPath.Length).TrimStart("\", "/")
        $pathParts = $relativePath -split "[\\/]"
        $directoryParts = if ($pathParts.Count -gt 1) { $pathParts[0..($pathParts.Count - 2)] } else { @() }

        foreach ($part in $directoryParts) {
            if ($excludedDirSet.Contains($part)) {
                Write-Host "Skipping excluded directory:`n - $($file.FullName)"
                return $false
            }
        }

        if ($excludedFileSet.Contains($file.Name)) {
            Write-Host "Skipping excluded file:`n - $($file.FullName)"
            return $false
        }

        if ($file.Length -gt $maxFileSizeBytes) {
            Write-Host "Skipping large file ($([Math]::Round($file.Length / 1KB, 2)) KB):`n - $($file.FullName)"
            return $false
        }

        $normalizedExtension = Normalize-Extension $file.Extension

        if ($file.Name -ieq "Dockerfile") {
            $normalizedExtension = ".dockerfile"
        }

        if ($file.Name -ieq "Makefile") {
            $normalizedExtension = ".makefile"
        }

        if ($file.Name -ieq "CMakeLists.txt") {
            $normalizedExtension = ".cmake"
        }

        return $extensionSet.Contains($normalizedExtension)
    } |
    Sort-Object FullName

$markdown = ""
$markdown += "# MDTREE (``$($Output)``)`n"
$markdown += "`n`n"
$markdown += "- `$Path = ``$($Path)```n"
$markdown += "- `$FilterPath = ``$($FilterPath)```n"
$markdown += "- `$FilterName = ``$($FilterName)```n"
$markdown += "- `$Include = ``$($Include)```n"
$markdown += "- `$ExcludeDirs = ``$($ExcludeDirs)```n"
$markdown += "- `$ExcludeFiles = ``$($ExcludeFiles)```n"
$markdown += "- `$MaxFileSizeKB = ``$($MaxFileSizeKB)```n"
$markdown += "- `$Output = ``$($Output)```n"
$markdown += "`n`n"
$markdown += "Generated on ``$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))``"
$markdown += "`n`n"
$markdown += "[TOC]"
$markdown += "`n`n"

foreach ($file in $files) {
    if (-not $pathFilterRegexp.ShouldKeepFile($file.FullName)) {
        Write-Host "Skipping pathFilterRegexp:`n - $($file.FullName)"
        continue
    }

    if (-not $nameFilterRegexp.ShouldKeepFile($file.Name)) {
        Write-Host "Skipping nameFilterRegexp:`n - $($file.FullName)"
        continue
    }

    Write-Host "Processing:`n - $($file.FullName)"

    $fileContent = Get-Content $file.FullName -Raw
    $codeBlockLanguage = Get-CodeBlockLanguage $file
    $relativePath = $file.FullName.Substring($resolvedPath.Length).TrimStart("\", "/")

    $markdown += "## File content ``$($relativePath)``:`n`n"

    if ($file.Extension -ieq ".md") {
        $markdown += $fileContent
    } else {
        $markdown += Format-MarkdownCodeBlock $fileContent $codeBlockLanguage
    }

    $markdown += "`n`n"
}

$markdown | Out-File $Output -Encoding utf8