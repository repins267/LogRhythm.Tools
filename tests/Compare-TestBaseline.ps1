<#
.SYNOPSIS
    Compares a live API test result JSON against a baseline JSON to detect regressions.

.DESCRIPTION
    Loads two test result JSON files (a known-good baseline and a new run) and compares
    each cmdlet result by name. Reports regressions (PASS -> FAIL), fixes (FAIL/SKIP -> PASS),
    new tests, removed tests, other status changes, and timing regressions (>5x slower).

    Returns exit code 0 if no regressions are found, or 1 if any regressions exist.

.PARAMETER BaselinePath
    Path to the known-good baseline JSON file.
    Default: tests/results/baseline.json (relative to the repository root).

.PARAMETER CurrentPath
    Path to the new test result JSON file. If not specified, the most recent file in
    tests/results/ (excluding baseline.json) is used automatically.

.PARAMETER SetBaseline
    Instead of comparing, copies the current result file to the baseline path. This
    establishes a new known-good baseline for future comparisons.

.EXAMPLE
    .\tests\Compare-TestBaseline.ps1 -SetBaseline
    # Sets the most recent test result as the new baseline.

.EXAMPLE
    .\tests\Compare-TestBaseline.ps1
    # Compares the latest test result against the baseline.

.EXAMPLE
    .\tests\Compare-TestBaseline.ps1 -CurrentPath .\tests\results\2026-03-16_all.json
    # Compares a specific result file against the baseline.

.EXAMPLE
    .\tests\Compare-TestBaseline.ps1 -BaselinePath .\tests\results\old_baseline.json -CurrentPath .\tests\results\new_run.json
    # Compares two specific files.
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $false)]
    [string] $BaselinePath,

    [Parameter(Mandatory = $false)]
    [string] $CurrentPath,

    [Parameter(Mandatory = $false)]
    [switch] $SetBaseline
)

#region: Resolve Paths
$RepoRoot = (Get-Item $PSScriptRoot).Parent.FullName
$ResultsDir = Join-Path -Path $RepoRoot -ChildPath "tests\results"

if (-not $BaselinePath) {
    $BaselinePath = Join-Path -Path $ResultsDir -ChildPath "baseline.json"
}

if (-not $CurrentPath) {
    # Find the most recent JSON in tests/results/ excluding baseline.json
    $candidates = Get-ChildItem -Path $ResultsDir -Filter "*.json" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne "baseline.json" } |
        Sort-Object -Property LastWriteTime -Descending
    if ($candidates) {
        $CurrentPath = $candidates[0].FullName
    } else {
        Write-Error "No test result files found in $ResultsDir"
        exit 1
    }
}

# Resolve to absolute paths
if (-not [System.IO.Path]::IsPathRooted($BaselinePath)) {
    $BaselinePath = Join-Path -Path (Get-Location).Path -ChildPath $BaselinePath
}
if (-not [System.IO.Path]::IsPathRooted($CurrentPath)) {
    $CurrentPath = Join-Path -Path (Get-Location).Path -ChildPath $CurrentPath
}
#endregion


#region: SetBaseline Mode
if ($SetBaseline) {
    if (-not (Test-Path $CurrentPath)) {
        Write-Error "Current result file not found: $CurrentPath"
        exit 1
    }
    Copy-Item -Path $CurrentPath -Destination $BaselinePath -Force
    Write-Host "Baseline set from: $CurrentPath" -ForegroundColor Green
    Write-Host "Baseline saved to: $BaselinePath" -ForegroundColor Green
    exit 0
}
#endregion


#region: Load JSON Files
if (-not (Test-Path $BaselinePath)) {
    Write-Error "Baseline file not found: $BaselinePath. Run with -SetBaseline first."
    exit 1
}
if (-not (Test-Path $CurrentPath)) {
    Write-Error "Current result file not found: $CurrentPath"
    exit 1
}

try {
    $baselineJson = Get-Content -Path $BaselinePath -Raw | ConvertFrom-Json
} catch {
    Write-Error "Failed to parse baseline JSON: $_"
    exit 1
}

try {
    $currentJson = Get-Content -Path $CurrentPath -Raw | ConvertFrom-Json
} catch {
    Write-Error "Failed to parse current JSON: $_"
    exit 1
}
#endregion


#region: Build Lookup Tables
$baselineMap = @{}
foreach ($result in $baselineJson.results) {
    $baselineMap[$result.cmdlet] = $result
}

$currentMap = @{}
foreach ($result in $currentJson.results) {
    $currentMap[$result.cmdlet] = $result
}

# Collect all unique cmdlet names
$allCmdlets = @($baselineMap.Keys) + @($currentMap.Keys) | Sort-Object -Unique
#endregion


#region: Compare Results
$regressions   = [System.Collections.Generic.List[object]]::new()
$fixed         = [System.Collections.Generic.List[object]]::new()
$newTests      = [System.Collections.Generic.List[object]]::new()
$removedTests  = [System.Collections.Generic.List[object]]::new()
$statusChanged = [System.Collections.Generic.List[object]]::new()
$timingWarnings = [System.Collections.Generic.List[object]]::new()

foreach ($cmdlet in $allCmdlets) {
    $inBaseline = $baselineMap.ContainsKey($cmdlet)
    $inCurrent  = $currentMap.ContainsKey($cmdlet)

    # New test: exists in current but not in baseline
    if ($inCurrent -and -not $inBaseline) {
        $newTests.Add([PSCustomObject]@{
            Cmdlet = $cmdlet
            Status = $currentMap[$cmdlet].status
        })
        continue
    }

    # Removed test: exists in baseline but not in current
    if ($inBaseline -and -not $inCurrent) {
        $removedTests.Add([PSCustomObject]@{
            Cmdlet = $cmdlet
            Status = $baselineMap[$cmdlet].status
        })
        continue
    }

    # Both exist - compare statuses
    $baseStatus = $baselineMap[$cmdlet].status
    $currStatus = $currentMap[$cmdlet].status

    if ($baseStatus -ne $currStatus) {
        # Regression: was PASS, now FAIL
        if ($baseStatus -eq "PASS" -and $currStatus -eq "FAIL") {
            $regressions.Add([PSCustomObject]@{
                Cmdlet     = $cmdlet
                OldStatus  = $baseStatus
                NewStatus  = $currStatus
                ErrorDetail = $currentMap[$cmdlet].errorDetail
            })
        }
        # Fixed: was FAIL or SKIP, now PASS
        elseif ($currStatus -eq "PASS" -and ($baseStatus -eq "FAIL" -or $baseStatus -eq "SKIP")) {
            $fixed.Add([PSCustomObject]@{
                Cmdlet    = $cmdlet
                OldStatus = $baseStatus
                NewStatus = $currStatus
            })
        }
        # Other status change
        else {
            $statusChanged.Add([PSCustomObject]@{
                Cmdlet    = $cmdlet
                OldStatus = $baseStatus
                NewStatus = $currStatus
            })
        }
    }

    # Timing regression: current >5x slower than baseline (only if both have valid times)
    $baseMs = $baselineMap[$cmdlet].elapsedMs
    $currMs = $currentMap[$cmdlet].elapsedMs
    if ($baseMs -gt 0 -and $currMs -gt ($baseMs * 5)) {
        $timingWarnings.Add([PSCustomObject]@{
            Cmdlet     = $cmdlet
            BaselineMs = $baseMs
            CurrentMs  = $currMs
            Factor     = [math]::Round($currMs / $baseMs, 1)
        })
    }
}
#endregion


#region: Output Results
# Regressions
foreach ($r in $regressions) {
    Write-Host "  REGRESSION  $($r.Cmdlet): $($r.OldStatus) -> $($r.NewStatus)" -ForegroundColor Red
    if ($r.ErrorDetail) {
        Write-Host "              Error: $($r.ErrorDetail)" -ForegroundColor Red
    }
}

# Fixed
foreach ($f in $fixed) {
    Write-Host "  FIXED       $($f.Cmdlet): $($f.OldStatus) -> $($f.NewStatus)" -ForegroundColor Green
}

# New tests
foreach ($n in $newTests) {
    Write-Host "  NEW TEST    $($n.Cmdlet): $($n.Status)" -ForegroundColor Cyan
}

# Removed tests
foreach ($r in $removedTests) {
    Write-Host "  REMOVED     $($r.Cmdlet): $($r.Status)" -ForegroundColor Yellow
}

# Other status changes
foreach ($s in $statusChanged) {
    Write-Host "  CHANGED     $($s.Cmdlet): $($s.OldStatus) -> $($s.NewStatus)" -ForegroundColor White
}

# Timing warnings
foreach ($t in $timingWarnings) {
    Write-Host "  TIMING      $($t.Cmdlet): $($t.BaselineMs)ms -> $($t.CurrentMs)ms ($($t.Factor)x slower)" -ForegroundColor Yellow
}
#endregion


#region: Summary
# Extract dates from metadata if available
$baselineDate = ""
if ($baselineJson.metadata.startTime) {
    try {
        $baselineDate = ([datetime]::Parse($baselineJson.metadata.startTime)).ToString("yyyy-MM-dd")
    } catch {
        $baselineDate = "unknown"
    }
}

$baselineRelative = $BaselinePath
$currentRelative  = $CurrentPath
# Try to make paths relative to repo root for display
if ($BaselinePath.StartsWith($RepoRoot)) {
    $baselineRelative = $BaselinePath.Substring($RepoRoot.Length + 1)
}
if ($CurrentPath.StartsWith($RepoRoot)) {
    $currentRelative = $CurrentPath.Substring($RepoRoot.Length + 1)
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor White
Write-Host " Test Baseline Comparison" -ForegroundColor White
Write-Host "================================================================" -ForegroundColor White
Write-Host "Baseline: $baselineRelative$(if ($baselineDate) { " ($baselineDate)" })"
Write-Host "Current:  $currentRelative"
Write-Host ""
Write-Host "Regressions:      $($regressions.Count)" -ForegroundColor $(if ($regressions.Count -gt 0) { "Red" } else { "Green" })
Write-Host "Fixed:             $($fixed.Count)" -ForegroundColor $(if ($fixed.Count -gt 0) { "Green" } else { "White" })
Write-Host "New tests:         $($newTests.Count)" -ForegroundColor $(if ($newTests.Count -gt 0) { "Cyan" } else { "White" })
Write-Host "Removed:           $($removedTests.Count)" -ForegroundColor $(if ($removedTests.Count -gt 0) { "Yellow" } else { "White" })
Write-Host "Timing warnings:   $($timingWarnings.Count)" -ForegroundColor $(if ($timingWarnings.Count -gt 0) { "Yellow" } else { "White" })
Write-Host "================================================================" -ForegroundColor White
#endregion


#region: Exit Code
if ($regressions.Count -gt 0) {
    exit 1
} else {
    exit 0
}
#endregion
