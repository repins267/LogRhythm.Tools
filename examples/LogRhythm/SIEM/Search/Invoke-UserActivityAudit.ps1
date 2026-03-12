<#
.SYNOPSIS
    Audit all activity for a user account across LogRhythm log sources.
.DESCRIPTION
    Invoke-UserActivityAudit searches the LogRhythm SIEM for all events
    associated with a given username within a specified time window. Results
    are grouped by source entity, log source, and classification to provide
    a summary view of user activity.

    Useful for incident response when investigating compromised accounts,
    insider threats, or user activity audits requested by management.

    Optionally creates a case with the audit findings attached.
.PARAMETER Username
    The username or account name to search for across log sources.
.PARAMETER StartDate
    Beginning of the search window. Default is 24 hours ago.
.PARAMETER EndDate
    End of the search window. Default is the current time.
.PARAMETER MaxResults
    Maximum number of log messages to query. Default is 10000.
.PARAMETER TimeoutSeconds
    Maximum seconds to wait for search results. Default is 300 (5 minutes).
.PARAMETER CreateCase
    Switch to automatically create a case with the audit findings.
.PARAMETER CasePriority
    Priority for the auto-created case (1-5). Default is 4.
.EXAMPLE
    PS C:\> .\Invoke-UserActivityAudit.ps1 -Username "jsmith"

    Searches for all activity by jsmith in the last 24 hours.
.EXAMPLE
    PS C:\> .\Invoke-UserActivityAudit.ps1 -Username "admin.svc" -StartDate "2026-03-01" -EndDate "2026-03-10" -CreateCase

    Audits the admin.svc account over a 9-day window and creates a case.
.LINK
    https://github.com/LogRhythm-Tools/LogRhythm.Tools
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string] $Username,

    [Parameter(Mandatory = $false, Position = 1)]
    [datetime] $StartDate = (Get-Date).AddHours(-24),

    [Parameter(Mandatory = $false, Position = 2)]
    [datetime] $EndDate = (Get-Date),

    [Parameter(Mandatory = $false)]
    [ValidateRange(100, 100000)]
    [int] $MaxResults = 10000,

    [Parameter(Mandatory = $false)]
    [ValidateRange(30, 900)]
    [int] $TimeoutSeconds = 300,

    [Parameter(Mandatory = $false)]
    [switch] $CreateCase,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 5)]
    [int] $CasePriority = 4
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  User Activity Audit" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Username  : $Username" -ForegroundColor White
Write-Host "  Start Date: $($StartDate.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
Write-Host "  End Date  : $($EndDate.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
Write-Host ""

# --- Step 1: Submit search ---
Write-Host "[1/4] Submitting search for user: $Username" -ForegroundColor Cyan

try {
    $SearchResult = New-LrSearch `
        -Param1MetaField "Login" `
        -Param1Value $Username `
        -Param1Operator "value" `
        -Param1MatchType "exact" `
        -Param1FilterType "value" `
        -DateMin $StartDate.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") `
        -DateMax $EndDate.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") `
        -MaxMsgsToQuery $MaxResults
} catch {
    Write-Host "ERROR: Failed to submit search. $_" -ForegroundColor Red
    return
}

if (-not $SearchResult -or -not $SearchResult.TaskId) {
    Write-Host "ERROR: Search submission did not return a valid TaskId." -ForegroundColor Red
    return
}

$TaskId = $SearchResult.TaskId
Write-Host "  Search submitted. TaskId: $TaskId" -ForegroundColor Green

# --- Step 2: Poll for results ---
Write-Host "[2/4] Waiting for search results (timeout: ${TimeoutSeconds}s)..." -ForegroundColor Cyan

$StopWatch = [System.Diagnostics.Stopwatch]::StartNew()
$PollInterval = 5
$SearchComplete = $false
$Results = $null

while ($StopWatch.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
    try {
        $Results = Get-LrSearchResults -TaskId $TaskId
    } catch {
        Write-Verbose "Poll attempt returned error: $_"
    }

    if ($Results -and $Results.TaskStatus -eq "Completed") {
        $SearchComplete = $true
        break
    }

    $Elapsed = [math]::Round($StopWatch.Elapsed.TotalSeconds)
    Write-Host "  Searching... ($Elapsed s elapsed)" -ForegroundColor Gray
    Start-Sleep -Seconds $PollInterval
}

$StopWatch.Stop()

if (-not $SearchComplete) {
    Write-Host "WARNING: Search did not complete within $TimeoutSeconds seconds." -ForegroundColor Yellow
    Write-Host "  TaskId $TaskId may still be running. Use Get-LrSearchResults -TaskId '$TaskId' to check." -ForegroundColor Yellow
    return
}

# Extract log data from results
$LogData = @()
if ($Results.Results) {
    $LogData = @($Results.Results)
}

Write-Host "  Search complete. Events found: $($LogData.Count)" -ForegroundColor Green

if ($LogData.Count -eq 0) {
    Write-Host "No events found for user '$Username' in the specified time window." -ForegroundColor Yellow
    return
}

# --- Step 3: Analyze and summarize ---
Write-Host "[3/4] Analyzing results..." -ForegroundColor Cyan

# Group by entity
$EntityGroups = $LogData | Group-Object -Property { $_.entityName } |
    Sort-Object Count -Descending
$EntityCount = $EntityGroups.Count

# Group by log source
$LogSourceGroups = $LogData | Group-Object -Property { $_.logSourceName } |
    Sort-Object Count -Descending
$LogSourceCount = $LogSourceGroups.Count

# Group by classification
$ClassGroups = $LogData | Group-Object -Property { $_.classificationName } |
    Sort-Object Count -Descending

# Build summary report
$ReportLines = [System.Collections.Generic.List[string]]::new()
$ReportLines.Add("=== User Activity Audit Report ===")
$ReportLines.Add("Username    : $Username")
$ReportLines.Add("Time Window : $($StartDate.ToString('yyyy-MM-dd HH:mm')) to $($EndDate.ToString('yyyy-MM-dd HH:mm'))")
$ReportLines.Add("Total Events: $($LogData.Count)")
$ReportLines.Add("Entities    : $EntityCount")
$ReportLines.Add("Log Sources : $LogSourceCount")
$ReportLines.Add("")

$ReportLines.Add("--- Activity by Entity ---")
foreach ($Group in $EntityGroups) {
    $ReportLines.Add("  $($Group.Name): $($Group.Count) events")
}
$ReportLines.Add("")

$ReportLines.Add("--- Activity by Log Source ---")
foreach ($Group in $LogSourceGroups | Select-Object -First 20) {
    $ReportLines.Add("  $($Group.Name): $($Group.Count) events")
}
if ($LogSourceGroups.Count -gt 20) {
    $ReportLines.Add("  ... and $($LogSourceGroups.Count - 20) more log sources")
}
$ReportLines.Add("")

$ReportLines.Add("--- Activity by Classification ---")
foreach ($Group in $ClassGroups) {
    $ReportLines.Add("  $($Group.Name): $($Group.Count) events")
}
$ReportLines.Add("")

# Display summary to console
Write-Host ""
Write-Host "  Summary: User '$Username' had $($LogData.Count) events across" -ForegroundColor White -NoNewline
Write-Host " $LogSourceCount log sources from $EntityCount entities." -ForegroundColor White
Write-Host ""

Write-Host "  Top Entities:" -ForegroundColor White
foreach ($Group in $EntityGroups | Select-Object -First 5) {
    Write-Host "    $($Group.Name): $($Group.Count) events" -ForegroundColor Gray
}

Write-Host ""
Write-Host "  Top Log Sources:" -ForegroundColor White
foreach ($Group in $LogSourceGroups | Select-Object -First 5) {
    Write-Host "    $($Group.Name): $($Group.Count) events" -ForegroundColor Gray
}

Write-Host ""
Write-Host "  Classifications:" -ForegroundColor White
foreach ($Group in $ClassGroups | Select-Object -First 10) {
    Write-Host "    $($Group.Name): $($Group.Count) events" -ForegroundColor Gray
}

# --- Step 4: Optionally create case ---
if ($CreateCase) {
    Write-Host ""
    Write-Host "[4/4] Creating case with audit findings..." -ForegroundColor Cyan

    $CaseName = "User Activity Audit: $Username - $(Get-Date -Format 'yyyy-MM-dd')"
    $CaseSummary = "Audit of user '$Username' activity from " +
        "$($StartDate.ToString('yyyy-MM-dd HH:mm')) to " +
        "$($EndDate.ToString('yyyy-MM-dd HH:mm')). " +
        "Found $($LogData.Count) events across $LogSourceCount log sources " +
        "from $EntityCount entities."

    try {
        $NewCase = New-LrCase -Name $CaseName -Priority $CasePriority `
            -Summary $CaseSummary
        $CaseNumber = $NewCase.number
        Write-Host "  Case created: #$CaseNumber" -ForegroundColor Green

        # Add the full report as a case note
        $NoteText = $ReportLines -join "`n"
        Add-LrNoteToCase -Id $CaseNumber -Text $NoteText -PassThru | Out-Null
        Write-Host "  Audit report added as case note." -ForegroundColor Green

        # Tag the case
        $AuditTags = @("User-Audit", "Investigation")
        Add-LrCaseTags -Id $CaseNumber -Tags $AuditTags -Force -PassThru | Out-Null
        Write-Host "  Tags applied: $($AuditTags -join ', ')" -ForegroundColor Green
    } catch {
        Write-Host "ERROR: Failed to create case. $_" -ForegroundColor Red
    }
} else {
    Write-Host ""
    Write-Host "[4/4] Skipping case creation (use -CreateCase to enable)." -ForegroundColor Gray
}

# --- Final output ---
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Audit Complete" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
