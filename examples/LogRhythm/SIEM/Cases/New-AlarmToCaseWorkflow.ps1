<#
.SYNOPSIS
    Automate case creation from a LogRhythm alarm with context enrichment.
.DESCRIPTION
    New-AlarmToCaseWorkflow retrieves alarm details and associated events,
    creates a new LogRhythm case, attaches the alarm, adds contextual notes,
    and applies tags based on alarm rule name pattern matching.

    Designed for SOC analyst automation workflows where alarms should be
    promoted to cases with enriched context for faster triage.
.PARAMETER AlarmId
    The numeric identifier of the LogRhythm alarm to promote to a case.
.PARAMETER Priority
    Case priority from 1 (highest) to 5 (lowest). Default is 3.
.PARAMETER DueDateHours
    Number of hours from now to set the case due date. Default is 24.
.EXAMPLE
    PS C:\> .\New-AlarmToCaseWorkflow.ps1 -AlarmId 1842

    Creates a case from alarm 1842 with default priority 3 and 24-hour due date.
.EXAMPLE
    PS C:\> .\New-AlarmToCaseWorkflow.ps1 -AlarmId 1842 -Priority 1 -DueDateHours 4

    Creates a high-priority case from alarm 1842 with a 4-hour SLA.
.LINK
    https://github.com/LogRhythm-Tools/LogRhythm.Tools
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateRange(1, [int]::MaxValue)]
    [int] $AlarmId,

    [Parameter(Mandatory = $false, Position = 1)]
    [ValidateRange(1, 5)]
    [int] $Priority = 3,

    [Parameter(Mandatory = $false, Position = 2)]
    [ValidateRange(1, 720)]
    [int] $DueDateHours = 24
)

# Tag mapping: alarm rule name patterns to case tags
$TagPatterns = @{
    "malware"           = @("Malware", "Endpoint")
    "ransomware"        = @("Malware", "Ransomware", "Critical")
    "authentication"    = @("Authentication", "Identity")
    "brute.?force"      = @("Authentication", "Brute-Force")
    "login.?fail"       = @("Authentication", "Failed-Login")
    "exfiltration"      = @("Data-Exfiltration", "DLP")
    "lateral.?movement" = @("Lateral-Movement", "Compromise")
    "c2|command.?and.?control|beacon" = @("C2", "Compromise")
    "phish"             = @("Phishing", "Email")
    "privilege.?escal"  = @("Privilege-Escalation", "Identity")
    "suspicious"        = @("Suspicious")
}

# --- Step 1: Retrieve alarm details ---
Write-Host "[1/6] Retrieving alarm details for Alarm ID: $AlarmId" -ForegroundColor Cyan
try {
    $AlarmDetails = Get-LrAlarm -AlarmId $AlarmId -ResultsOnly
} catch {
    Write-Host "ERROR: Failed to retrieve alarm $AlarmId. $_" -ForegroundColor Red
    return
}

if (-not $AlarmDetails) {
    Write-Host "ERROR: Alarm $AlarmId not found or returned empty." -ForegroundColor Red
    return
}

$AlarmRuleName = $AlarmDetails.alarmRuleName
$AlarmDate = $AlarmDetails.alarmDate
$AlarmRbpMax = $AlarmDetails.rbpMax
Write-Host "  Alarm Rule: $AlarmRuleName" -ForegroundColor White
Write-Host "  Alarm Date: $AlarmDate  |  RBP Max: $AlarmRbpMax" -ForegroundColor White

# --- Step 2: Retrieve alarm events ---
Write-Host "[2/6] Retrieving alarm events..." -ForegroundColor Cyan
try {
    $AlarmEvents = Get-LrAlarmEvents -AlarmId $AlarmId -ResultsOnly
} catch {
    Write-Host "WARNING: Could not retrieve alarm events. $_" -ForegroundColor Yellow
    $AlarmEvents = @()
}

$EventCount = 0
if ($AlarmEvents) {
    $EventCount = @($AlarmEvents).Count
}
Write-Host "  Events retrieved: $EventCount" -ForegroundColor White

# --- Step 3: Create the case ---
Write-Host "[3/6] Creating case..." -ForegroundColor Cyan
$DateStamp = (Get-Date).ToString("yyyy-MM-dd HH:mm")
$CaseName = "Alarm: $AlarmRuleName - $DateStamp"
# Truncate to 250 chars (API limit)
if ($CaseName.Length -gt 250) {
    $CaseName = $CaseName.Substring(0, 247) + "..."
}

$DueDate = (Get-Date).AddHours($DueDateHours)
$CaseSummary = "Auto-created from Alarm $AlarmId. " +
    "Rule: $AlarmRuleName. " +
    "RBP: $AlarmRbpMax. " +
    "Event count: $EventCount."

try {
    $NewCase = New-LrCase -Name $CaseName -Priority $Priority `
        -DueDate $DueDate -Summary $CaseSummary
} catch {
    Write-Host "ERROR: Failed to create case. $_" -ForegroundColor Red
    return
}

$CaseNumber = $NewCase.number
$CaseId = $NewCase.id
Write-Host "  Case created: #$CaseNumber ($CaseId)" -ForegroundColor Green

# --- Step 4: Attach alarm to case ---
Write-Host "[4/6] Attaching alarm to case..." -ForegroundColor Cyan
try {
    Add-LrAlarmToCase -Id $CaseNumber -AlarmNumbers $AlarmId | Out-Null
    Write-Host "  Alarm $AlarmId attached to Case #$CaseNumber" -ForegroundColor Green
} catch {
    Write-Host "WARNING: Failed to attach alarm to case. $_" -ForegroundColor Yellow
}

# --- Step 5: Add event summary note ---
Write-Host "[5/6] Adding event summary note..." -ForegroundColor Cyan
$NoteLines = [System.Collections.Generic.List[string]]::new()
$NoteLines.Add("=== Alarm Event Summary ===")
$NoteLines.Add("Alarm ID: $AlarmId")
$NoteLines.Add("Alarm Rule: $AlarmRuleName")
$NoteLines.Add("Event Count: $EventCount")
$NoteLines.Add("")

if ($AlarmEvents) {
    foreach ($Event in @($AlarmEvents)) {
        $NoteLines.Add("--- Event ---")
        if ($Event.commonEventName) {
            $NoteLines.Add("  Common Event: $($Event.commonEventName)")
        }
        if ($Event.classificationName) {
            $NoteLines.Add("  Classification: $($Event.classificationName)")
        }
        if ($Event.originHostName) {
            $NoteLines.Add("  Origin Host: $($Event.originHostName)")
        }
        if ($Event.impactedHostName) {
            $NoteLines.Add("  Impacted Host: $($Event.impactedHostName)")
        }
        if ($Event.originIP) {
            $NoteLines.Add("  Origin IP: $($Event.originIP)")
        }
        if ($Event.impactedIP) {
            $NoteLines.Add("  Impacted IP: $($Event.impactedIP)")
        }
        if ($Event.account) {
            $NoteLines.Add("  Account: $($Event.account)")
        }
        $NoteLines.Add("")
    }

    # If alarm involves known hosts, add host detail notes
    $HostNames = @($AlarmEvents |
        Where-Object { $_.impactedHostName } |
        Select-Object -ExpandProperty impactedHostName -Unique)

    foreach ($HostName in $HostNames) {
        try {
            $HostInfo = Get-LrHosts -Name $HostName -Exact
            if ($HostInfo) {
                $NoteLines.Add("=== Host Detail: $HostName ===")
                $NoteLines.Add("  Host ID: $($HostInfo.id)")
                $NoteLines.Add("  Entity: $($HostInfo.entity.name)")
                $NoteLines.Add("  OS: $($HostInfo.os)")
                $NoteLines.Add("  Risk Level: $($HostInfo.riskLevel)")
                $NoteLines.Add("  Status: $($HostInfo.recordStatusName)")
                $NoteLines.Add("")
            }
        } catch {
            Write-Verbose "Could not retrieve host details for $HostName."
        }
    }
}

$NoteText = $NoteLines -join "`n"
try {
    Add-LrNoteToCase -Id $CaseNumber -Text $NoteText -PassThru | Out-Null
    Write-Host "  Event summary note added." -ForegroundColor Green
} catch {
    Write-Host "WARNING: Failed to add note. $_" -ForegroundColor Yellow
}

# --- Step 6: Apply tags based on alarm rule name ---
Write-Host "[6/6] Applying tags based on alarm rule pattern..." -ForegroundColor Cyan
$MatchedTags = [System.Collections.Generic.List[string]]::new()

foreach ($Pattern in $TagPatterns.Keys) {
    if ($AlarmRuleName -match $Pattern) {
        foreach ($Tag in $TagPatterns[$Pattern]) {
            if (-not $MatchedTags.Contains($Tag)) {
                $MatchedTags.Add($Tag)
            }
        }
    }
}

# Add RBP-based tag
if ($AlarmRbpMax -ge 80) {
    $MatchedTags.Add("High-RBP")
} elseif ($AlarmRbpMax -ge 50) {
    $MatchedTags.Add("Medium-RBP")
}

if ($MatchedTags.Count -gt 0) {
    try {
        Add-LrCaseTags -Id $CaseNumber -Tags $MatchedTags -Force -PassThru | Out-Null
        Write-Host "  Tags applied: $($MatchedTags -join ', ')" -ForegroundColor Green
    } catch {
        Write-Host "WARNING: Failed to apply tags. $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "  No matching tag patterns found for rule name." -ForegroundColor Gray
}

# --- Output summary ---
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Case Created Successfully" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Case Number : #$CaseNumber" -ForegroundColor White
Write-Host "  Case ID     : $CaseId" -ForegroundColor White
Write-Host "  Case Name   : $CaseName" -ForegroundColor White
Write-Host "  Priority    : $Priority" -ForegroundColor White
Write-Host "  Due Date    : $DueDate" -ForegroundColor White
Write-Host "  Tags        : $($MatchedTags -join ', ')" -ForegroundColor White
Write-Host "  Events      : $EventCount" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Green

# Return the case object for pipeline use
$NewCase
