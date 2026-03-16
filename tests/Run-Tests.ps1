#Requires -Version 5.1
<#
.SYNOPSIS
    Pester 5.x test runner for the LogRhythm.Tools PowerShell module.
.DESCRIPTION
    Discovers and runs Pester tests under the tests/ directory, with support for
    tag filtering, NUnit XML output for CI pipelines, and configurable verbosity.

    Pester v5+ is required and will be auto-installed from PSGallery (CurrentUser
    scope) if not already present.
.PARAMETER Path
    Root path to search for *.Tests.ps1 files. Defaults to the tests/ directory
    relative to this script.
.PARAMETER Tag
    One or more Pester tags to include. Defaults to @('Unit').
.PARAMETER OutputFile
    Optional path for NUnit XML test results (used by CI systems).
.PARAMETER Detailed
    Use Detailed verbosity instead of Normal.
.EXAMPLE
    PS C:\> .\tests\Run-Tests.ps1                                    # Unit tests only
.EXAMPLE
    PS C:\> .\tests\Run-Tests.ps1 -Tag Unit,Integration -Detailed   # Multiple tags
.EXAMPLE
    PS C:\> .\tests\Run-Tests.ps1 -Path .\tests\Admin\Agents\ -Detailed
.EXAMPLE
    PS C:\> .\tests\Run-Tests.ps1 -OutputFile .\results.xml         # CI output
.LINK
    https://github.com/repins267/LogRhythm.Tools/tree/v1.5.0-update
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $false, Position = 0)]
    [string] $Path,

    [Parameter(Mandatory = $false)]
    [string[]] $Tag = @('Unit'),

    [Parameter(Mandatory = $false)]
    [string] $OutputFile,

    [Parameter(Mandatory = $false)]
    [switch] $Detailed
)

# ============================================================================
# Setup
# ============================================================================
$ErrorActionPreference = "Stop"
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot   = Split-Path -Parent $ScriptRoot
$Psm1Path   = Join-Path $RepoRoot "src" "LogRhythm.Tools.psm1"

if (-not $Path) {
    $Path = $ScriptRoot
}

# ============================================================================
# Banner
# ============================================================================
Write-Host ""
Write-Host "================================================================"
Write-Host " SIEM.Tools Pester Test Runner"
Write-Host "================================================================"
Write-Host ""

# ============================================================================
# Ensure Pester v5+
# ============================================================================
$pester = Get-Module -Name Pester -ListAvailable | Where-Object { $_.Version.Major -ge 5 } | Sort-Object Version -Descending | Select-Object -First 1

if (-not $pester) {
    Write-Host "[*] Pester 5+ not found. Installing from PSGallery (CurrentUser)..." -ForegroundColor Yellow
    Install-Module -Name Pester -MinimumVersion 5.0.0 -Scope CurrentUser -Force -SkipPublisherCheck
    $pester = Get-Module -Name Pester -ListAvailable | Where-Object { $_.Version.Major -ge 5 } | Sort-Object Version -Descending | Select-Object -First 1
    if (-not $pester) {
        Write-Host "[!] Failed to install Pester 5+. Exiting." -ForegroundColor Red
        exit 1
    }
}

Import-Module -Name Pester -MinimumVersion 5.0.0 -Force
Write-Host "[+] Pester v$((Get-Module Pester).Version) loaded" -ForegroundColor Green

# ============================================================================
# Load Module
# ============================================================================
if (Test-Path $Psm1Path) {
    Write-Host "[+] Importing module: $Psm1Path" -ForegroundColor Green
    Import-Module $Psm1Path -Force
} else {
    Write-Host "[!] Module not found: $Psm1Path" -ForegroundColor Red
    exit 1
}

# ============================================================================
# Build Pester Configuration
# ============================================================================
Write-Host "[*] Test path : $Path"
Write-Host "[*] Tags      : $($Tag -join ', ')"
Write-Host "[*] Verbosity : $(if ($Detailed) { 'Detailed' } else { 'Normal' })"
if ($OutputFile) {
    Write-Host "[*] Output    : $OutputFile"
}
Write-Host ""

$config = New-PesterConfiguration

$config.Run.Path                = $Path
$config.Run.Exit                = $false
$config.Run.PassThru            = $true

$config.Filter.Tag              = $Tag

$config.Output.Verbosity        = if ($Detailed) { 'Detailed' } else { 'Normal' }

if ($OutputFile) {
    $config.TestResult.Enabled      = $true
    $config.TestResult.OutputFormat  = 'NUnitXml'
    $config.TestResult.OutputPath    = $OutputFile
}

# ============================================================================
# Run Tests
# ============================================================================
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$result = Invoke-Pester -Configuration $config
$stopwatch.Stop()

# ============================================================================
# Summary
# ============================================================================
Write-Host ""
Write-Host "================================================================"
Write-Host " Test Summary"
Write-Host "================================================================"
Write-Host "  Total   : $($result.TotalCount)"
Write-Host "  Passed  : $($result.PassedCount)"  -ForegroundColor Green
Write-Host "  Failed  : $($result.FailedCount)"  -ForegroundColor $(if ($result.FailedCount -gt 0) { 'Red' } else { 'Green' })
Write-Host "  Skipped : $($result.SkippedCount)" -ForegroundColor Yellow
Write-Host "  Duration: $($stopwatch.Elapsed.ToString('hh\:mm\:ss\.fff'))"
Write-Host "================================================================"
Write-Host ""

if ($OutputFile -and (Test-Path $OutputFile)) {
    Write-Host "[+] Results written to: $OutputFile" -ForegroundColor Green
}

# Return exit code: 0 = pass, 1 = failures
if ($result.FailedCount -gt 0) {
    exit 1
}
exit 0
