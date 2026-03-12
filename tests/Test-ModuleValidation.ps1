#Requires -Version 5.0
<#
.SYNOPSIS
    Validate LogRhythm.Tools module integrity without requiring API access.
.DESCRIPTION
    This script performs offline validation of the LogRhythm.Tools module:

    Phase 1 - Module Load: Import the module and verify it loads cleanly
    Phase 2 - Cmdlet Discovery: Verify all expected cmdlets are exported
    Phase 3 - Parameter Validation: Check mandatory params, PassThru, CmdletBinding
    Phase 4 - Help Completeness: Verify comment-based help on all cmdlets
    Phase 5 - Code Standards: Check for Write-Output, $Me, Enable-TrustAllCertsPolicy
    Phase 6 - Config Cmdlets: Test configuration cmdlets (no API needed)
    Phase 7 - Connectivity (Optional): Test configured services with -TestConnectivity

    No API keys or external services are required for Phases 1-6.
.PARAMETER ModulePath
    Path to the module source. Defaults to the src/ directory relative to this script.
.PARAMETER TestConnectivity
    When specified, runs Phase 7 to test API connectivity for configured services.
.PARAMETER Detailed
    Show per-cmdlet results instead of just summary counts.
.EXAMPLE
    PS C:\> .\Test-ModuleValidation.ps1
    Runs all offline validation checks.
.EXAMPLE
    PS C:\> .\Test-ModuleValidation.ps1 -TestConnectivity
    Runs all checks including API connectivity tests.
.EXAMPLE
    PS C:\> .\Test-ModuleValidation.ps1 -Detailed
    Shows per-cmdlet pass/fail details.
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $false)]
    [string] $ModulePath,

    [Parameter(Mandatory = $false)]
    [switch] $TestConnectivity,

    [Parameter(Mandatory = $false)]
    [switch] $Detailed
)

# ============================================================================
# Setup
# ============================================================================
$ErrorActionPreference = "Continue"
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptRoot

if (-not $ModulePath) {
    $ModulePath = Join-Path $RepoRoot "src"
}
$Psm1Path = Join-Path $ModulePath "LogRhythm.Tools.psm1"
$PublicPath = Join-Path $ModulePath "Public"
$LrPublicPath = Join-Path $PublicPath "LogRhythm"

$TotalPass = 0
$TotalFail = 0
$TotalWarn = 0
$Failures = [System.Collections.Generic.List[string]]::new()

function Write-Result {
    param([string]$Test, [string]$Status, [string]$Detail)
    switch ($Status) {
        "PASS" {
            $script:TotalPass++
            if ($Detailed) { Write-Host "  [PASS] $Test" -ForegroundColor Green }
        }
        "FAIL" {
            $script:TotalFail++
            $script:Failures.Add("$Test : $Detail")
            Write-Host "  [FAIL] $Test - $Detail" -ForegroundColor Red
        }
        "WARN" {
            $script:TotalWarn++
            if ($Detailed) { Write-Host "  [WARN] $Test - $Detail" -ForegroundColor Yellow }
        }
        "SKIP" {
            if ($Detailed) { Write-Host "  [SKIP] $Test - $Detail" -ForegroundColor DarkGray }
        }
    }
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host " LogRhythm.Tools Module Validation" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================================
# Phase 1: Module Load
# ============================================================================
Write-Host "[Phase 1] Module Load" -ForegroundColor Yellow
Write-Host "  Source: $Psm1Path"

$ModuleLoaded = $false
try {
    # Remove if already loaded
    if (Get-Module -Name "LogRhythm.Tools" -ErrorAction SilentlyContinue) {
        Remove-Module -Name "LogRhythm.Tools" -Force -ErrorAction SilentlyContinue
    }
    Import-Module $Psm1Path -Force -ErrorAction Stop -WarningAction SilentlyContinue
    $Module = Get-Module -Name "LogRhythm.Tools"
    if ($Module) {
        $ModuleLoaded = $true
        Write-Result "Module imports successfully" "PASS"
        $ExportedCmds = $Module.ExportedFunctions.Keys
        Write-Result "Exported cmdlets: $($ExportedCmds.Count)" "PASS"
    } else {
        Write-Result "Module import" "FAIL" "Module not found after import"
    }
} catch {
    Write-Result "Module import" "FAIL" $_.Exception.Message
    Write-Host ""
    Write-Host "  Module failed to load. Remaining tests will use file-based checks only." -ForegroundColor Yellow
}
Write-Host ""

# ============================================================================
# Phase 2: Cmdlet Discovery
# ============================================================================
Write-Host "[Phase 2] Cmdlet Discovery" -ForegroundColor Yellow

# Collect all .ps1 files and extract function names
$AllPs1Files = Get-ChildItem -Recurse -Include *.ps1 -Path $PublicPath -ErrorAction SilentlyContinue
$FunctionMap = @{}
foreach ($File in $AllPs1Files) {
    $Content = Get-Content -Path $File.FullName -Raw
    if ($Content -match '(?mi)^Function\s+([^\s{(]+)') {
        $FuncName = $Matches[1]
        $FunctionMap[$FuncName] = $File.FullName
    }
}
Write-Host "  Found $($FunctionMap.Count) functions in $($AllPs1Files.Count) files"

# Check filename matches function name
$NameMismatches = 0
foreach ($Entry in $FunctionMap.GetEnumerator()) {
    $FileName = [System.IO.Path]::GetFileNameWithoutExtension($Entry.Value)
    if ($FileName -cne $Entry.Key) {
        Write-Result "Filename match: $FileName" "FAIL" "File=$FileName, Function=$($Entry.Key)"
        $NameMismatches++
    }
}
if ($NameMismatches -eq 0) {
    Write-Result "All filenames match function names ($($FunctionMap.Count) checked)" "PASS"
}

# Check exported vs discovered (if module loaded)
if ($ModuleLoaded) {
    $MissingExports = 0
    foreach ($FuncName in $FunctionMap.Keys) {
        # Only check Public functions, not Private
        $FilePath = $FunctionMap[$FuncName]
        if ($FilePath -like "*\Public\*") {
            if ($ExportedCmds -notcontains $FuncName) {
                Write-Result "Export: $FuncName" "WARN" "Function exists but not exported"
                $MissingExports++
            }
        }
    }
    if ($MissingExports -eq 0) {
        Write-Result "All public functions are exported" "PASS"
    }
}
Write-Host ""

# ============================================================================
# Phase 3: Parameter Validation
# ============================================================================
Write-Host "[Phase 3] Parameter Validation" -ForegroundColor Yellow

# Check CmdletBinding on all functions
$NoCmdletBinding = 0
foreach ($File in $AllPs1Files) {
    $Content = Get-Content -Path $File.FullName -Raw
    if ($Content -match '(?mi)^Function\s+') {
        if ($Content -notmatch '\[CmdletBinding') {
            Write-Result "CmdletBinding: $($File.BaseName)" "WARN" "Missing [CmdletBinding()]"
            $NoCmdletBinding++
        }
    }
}
if ($NoCmdletBinding -eq 0) {
    Write-Result "All functions have [CmdletBinding()]" "PASS"
}

# Check -PassThru on mutating cmdlets (LR API cmdlets only)
$MutatingVerbs = @("New-", "Add-", "Update-", "Remove-", "Set-", "Import-", "Invoke-",
                    "Send-", "Copy-", "Approve-", "Deny-", "Join-", "Restart-", "Sync-")
$ExcludePatterns = @("Test-", "Format-", "ConvertTo-", "ConvertFrom-", "Show-")
$LrApiFiles = Get-ChildItem -Recurse -Include *.ps1 -Path $LrPublicPath -ErrorAction SilentlyContinue

$MissingPassThru = 0
foreach ($File in $LrApiFiles) {
    $BaseName = $File.BaseName
    $IsMutating = $false
    foreach ($Verb in $MutatingVerbs) {
        if ($BaseName.StartsWith($Verb)) { $IsMutating = $true; break }
    }
    $IsExcluded = $false
    foreach ($Pat in $ExcludePatterns) {
        if ($BaseName.StartsWith($Pat)) { $IsExcluded = $true; break }
    }

    if ($IsMutating -and -not $IsExcluded) {
        $Content = Get-Content -Path $File.FullName -Raw
        # Skip non-API helpers (no Invoke-RestAPIMethod call)
        if ($Content -match 'Invoke-RestAPIMethod') {
            if ($Content -notmatch '\[switch\]\s*\$PassThru') {
                Write-Result "PassThru: $BaseName" "FAIL" "Mutating API cmdlet missing -PassThru"
                $MissingPassThru++
            }
        }
    }
}
if ($MissingPassThru -eq 0) {
    Write-Result "All mutating API cmdlets have -PassThru" "PASS"
}
Write-Host ""

# ============================================================================
# Phase 4: Help Completeness
# ============================================================================
Write-Host "[Phase 4] Help Completeness" -ForegroundColor Yellow

$RequiredHelpTags = @(".SYNOPSIS", ".DESCRIPTION", ".EXAMPLE", ".LINK")
$HelpIssues = 0

foreach ($File in $LrApiFiles) {
    $Content = Get-Content -Path $File.FullName -Raw
    # Only check files with functions that call the API
    if ($Content -notmatch 'Invoke-RestAPIMethod') { continue }

    foreach ($Tag in $RequiredHelpTags) {
        if ($Content -notmatch [regex]::Escape($Tag)) {
            Write-Result "Help ($Tag): $($File.BaseName)" "FAIL" "Missing $Tag"
            $HelpIssues++
        }
    }
}
if ($HelpIssues -eq 0) {
    Write-Result "All API cmdlets have complete help (SYNOPSIS, DESCRIPTION, EXAMPLE, LINK)" "PASS"
}
Write-Host ""

# ============================================================================
# Phase 5: Code Standards
# ============================================================================
Write-Host "[Phase 5] Code Standards" -ForegroundColor Yellow

$StandardsIssues = 0

foreach ($File in $LrApiFiles) {
    $Content = Get-Content -Path $File.FullName -Raw
    if ($Content -notmatch 'Invoke-RestAPIMethod') { continue }

    # Check for Write-Output (forbidden)
    if ($Content -match '(?m)^\s*Write-Output\b') {
        Write-Result "No Write-Output: $($File.BaseName)" "FAIL" "Contains Write-Output"
        $StandardsIssues++
    }

    # Check for $Me = $MyInvocation.MyCommand.Name
    if ($Content -notmatch '\$Me\s*=\s*\$MyInvocation\.MyCommand\.Name') {
        Write-Result '$Me assignment: ' + $File.BaseName "FAIL" 'Missing $Me = $MyInvocation.MyCommand.Name'
        $StandardsIssues++
    }

    # Check for Enable-TrustAllCertsPolicy
    if ($Content -notmatch 'Enable-TrustAllCertsPolicy') {
        Write-Result "Enable-TrustAllCertsPolicy: $($File.BaseName)" "FAIL" "Missing in Begin block"
        $StandardsIssues++
    }

    # Check for -Origin $Me on Invoke-RestAPIMethod calls
    if ($Content -match 'Invoke-RestAPIMethod' -and $Content -notmatch 'Invoke-RestAPIMethod.*-Origin') {
        Write-Result "-Origin `$Me: $($File.BaseName)" "FAIL" "Missing -Origin on API call"
        $StandardsIssues++
    }

    # Check for raw Invoke-RestMethod (forbidden)
    if ($Content -match '(?m)^\s*Invoke-RestMethod\b') {
        Write-Result "No Invoke-RestMethod: $($File.BaseName)" "FAIL" "Uses raw Invoke-RestMethod"
        $StandardsIssues++
    }
}

if ($StandardsIssues -eq 0) {
    Write-Result "All API cmdlets pass code standards checks" "PASS"
}
Write-Host ""

# ============================================================================
# Phase 6: Config Cmdlets
# ============================================================================
Write-Host "[Phase 6] Configuration Cmdlets" -ForegroundColor Yellow

$ConfigCmdlets = @(
    "Get-LrtConfiguration",
    "Set-LrtConfiguration",
    "Test-LrtConfiguration",
    "Initialize-LrtConfiguration"
)

foreach ($CmdletName in $ConfigCmdlets) {
    $FilePath = Join-Path $PublicPath "General\$CmdletName.ps1"
    if (Test-Path $FilePath) {
        Write-Result "$CmdletName file exists" "PASS"
    } else {
        Write-Result "$CmdletName file exists" "FAIL" "File not found: $FilePath"
    }

    if ($ModuleLoaded -and ($ExportedCmds -contains $CmdletName)) {
        Write-Result "$CmdletName is exported" "PASS"
    } elseif ($ModuleLoaded) {
        Write-Result "$CmdletName is exported" "FAIL" "Not in exported functions"
    }
}

# Test Get-LrtConfiguration if module loaded
if ($ModuleLoaded) {
    try {
        $Config = Get-LrtConfiguration -ErrorAction Stop
        if ($null -ne $Config) {
            Write-Result "Get-LrtConfiguration returns config" "PASS"
        } else {
            Write-Result "Get-LrtConfiguration returns config" "WARN" "Returned null"
        }
    } catch {
        Write-Result "Get-LrtConfiguration" "FAIL" $_.Exception.Message
    }

    # Test service filter
    try {
        $LrConfig = Get-LrtConfiguration -Service LogRhythm -ErrorAction Stop
        if ($null -ne $LrConfig) {
            Write-Result "Get-LrtConfiguration -Service LogRhythm" "PASS"
        }
    } catch {
        Write-Result "Get-LrtConfiguration -Service filter" "FAIL" $_.Exception.Message
    }
}
Write-Host ""

# ============================================================================
# Phase 7: Connectivity (Optional)
# ============================================================================
if ($TestConnectivity) {
    Write-Host "[Phase 7] API Connectivity" -ForegroundColor Yellow

    if ($ModuleLoaded) {
        try {
            $Results = Test-LrtConfiguration -TestConnectivity -ErrorAction Stop
            foreach ($Result in $Results) {
                switch ($Result.Status) {
                    "Passed"        { Write-Result "Connectivity: $($Result.Service)" "PASS" }
                    "Failed"        { Write-Result "Connectivity: $($Result.Service)" "FAIL" $Result.Message }
                    "Warning"       { Write-Result "Connectivity: $($Result.Service)" "WARN" $Result.Message }
                    "NotConfigured" { Write-Result "Connectivity: $($Result.Service)" "SKIP" "Not configured" }
                    default         { Write-Result "Connectivity: $($Result.Service)" "WARN" $Result.Message }
                }
            }
        } catch {
            Write-Result "Test-LrtConfiguration" "FAIL" $_.Exception.Message
        }
    } else {
        Write-Host "  Skipped - module not loaded" -ForegroundColor DarkGray
    }
    Write-Host ""
}

# ============================================================================
# Summary
# ============================================================================
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host " Results Summary" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Passed:   $TotalPass" -ForegroundColor Green
Write-Host "  Failed:   $TotalFail" -ForegroundColor $(if ($TotalFail -gt 0) { "Red" } else { "Green" })
Write-Host "  Warnings: $TotalWarn" -ForegroundColor $(if ($TotalWarn -gt 0) { "Yellow" } else { "Green" })
Write-Host ""

if ($Failures.Count -gt 0) {
    Write-Host "  Failures:" -ForegroundColor Red
    foreach ($F in $Failures) {
        Write-Host "    - $F" -ForegroundColor Red
    }
    Write-Host ""
}

if ($TotalFail -eq 0) {
    Write-Host "  All checks passed!" -ForegroundColor Green
} else {
    Write-Host "  $TotalFail issue(s) need attention." -ForegroundColor Red
}
Write-Host ""

# Return exit code for CI usage
if ($TotalFail -gt 0) { exit 1 } else { exit 0 }
