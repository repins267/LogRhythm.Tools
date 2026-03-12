<#
.SYNOPSIS
    Perform a health check on LogRhythm System Monitor agents and log sources.
.DESCRIPTION
    Invoke-AgentHealthCheck audits the health status of all accepted agents,
    their log sources, and pending agents/log sources. It identifies agents
    with zero log sources, agents that may have connectivity issues, and
    pending items that have been waiting longer than expected.

    Designed for SIEM administrators to run as a daily health check or
    integrate into scheduled monitoring workflows.
.PARAMETER PendingThresholdHours
    Number of hours after which a pending agent or log source is flagged
    as overdue. Default is 24.
.PARAMETER OutputCsv
    Optional file path to export the health report to CSV format.
.PARAMETER Entity
    Optional entity name or ID to scope the health check to a specific entity.
.EXAMPLE
    PS C:\> .\Invoke-AgentHealthCheck.ps1

    Runs a full agent health check with default 24-hour pending threshold.
.EXAMPLE
    PS C:\> .\Invoke-AgentHealthCheck.ps1 -PendingThresholdHours 8 -OutputCsv "C:\Reports\agent-health.csv"

    Runs a health check with an 8-hour threshold and exports results to CSV.
.EXAMPLE
    PS C:\> .\Invoke-AgentHealthCheck.ps1 -Entity "Primary Site"

    Scopes the health check to agents in the Primary Site entity.
.LINK
    https://github.com/LogRhythm-Tools/LogRhythm.Tools
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $false, Position = 0)]
    [ValidateRange(1, 720)]
    [int] $PendingThresholdHours = 24,

    [Parameter(Mandatory = $false)]
    [string] $OutputCsv,

    [Parameter(Mandatory = $false)]
    [object] $Entity
)

$ReportTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$PendingCutoff = (Get-Date).AddHours(-$PendingThresholdHours)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Agent Health Check" -ForegroundColor Cyan
Write-Host "  $ReportTimestamp" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# --- Step 1: Get accepted agents ---
Write-Host "[1/4] Retrieving accepted agents..." -ForegroundColor Cyan

$AgentParams = @{}
if ($Entity) {
    $AgentParams.Add("Entity", $Entity)
}

try {
    $AcceptedAgents = @(Get-LrAgentsAccepted @AgentParams)
} catch {
    Write-Host "ERROR: Failed to retrieve accepted agents. $_" -ForegroundColor Red
    return
}

Write-Host "  Accepted agents found: $($AcceptedAgents.Count)" -ForegroundColor White

# --- Step 2: Check each agent's log sources ---
Write-Host "[2/4] Checking agent log sources..." -ForegroundColor Cyan

$AgentReport = [System.Collections.Generic.List[PSCustomObject]]::new()
$AgentsOk = 0
$AgentsWarning = 0
$AgentsCritical = 0

foreach ($Agent in $AcceptedAgents) {
    $AgentName = $Agent.name
    $AgentId = $Agent.id
    $AgentStatus = "OK"
    $Issues = [System.Collections.Generic.List[string]]::new()

    # Get log sources for this agent
    $LogSourceCount = 0
    try {
        $LogSources = @(Get-LrAgentLogSources -Id $AgentId)
        $LogSourceCount = $LogSources.Count
    } catch {
        $Issues.Add("Failed to retrieve log sources")
        $AgentStatus = "Critical"
    }

    # Flag agents with zero log sources
    if ($LogSourceCount -eq 0 -and $AgentStatus -ne "Critical") {
        $Issues.Add("No log sources configured")
        $AgentStatus = "Warning"
    }

    # Check agent record status
    if ($Agent.recordStatusName -eq "Retired") {
        $Issues.Add("Agent is retired")
        $AgentStatus = "Warning"
    }

    # Check agent OS type and version
    $AgentOs = if ($Agent.os) { $Agent.os } else { "Unknown" }
    $AgentVersion = if ($Agent.version) { $Agent.version } else { "Unknown" }

    # Tally status
    switch ($AgentStatus) {
        "OK"       { $AgentsOk++ }
        "Warning"  { $AgentsWarning++ }
        "Critical" { $AgentsCritical++ }
    }

    $AgentRecord = [PSCustomObject]@{
        AgentId        = $AgentId
        AgentName      = $AgentName
        EntityName     = $Agent.entity.name
        OS             = $AgentOs
        Version        = $AgentVersion
        LogSources     = $LogSourceCount
        RecordStatus   = $Agent.recordStatusName
        HealthStatus   = $AgentStatus
        Issues         = ($Issues -join "; ")
    }
    $AgentReport.Add($AgentRecord)
}

# Display agent issues
$ProblematicAgents = $AgentReport | Where-Object { $_.HealthStatus -ne "OK" }
if ($ProblematicAgents) {
    Write-Host ""
    Write-Host "  Agents with issues:" -ForegroundColor Yellow
    foreach ($ProbAgent in $ProblematicAgents) {
        $StatusColor = if ($ProbAgent.HealthStatus -eq "Critical") { "Red" } else { "Yellow" }
        Write-Host "    [$($ProbAgent.HealthStatus)] $($ProbAgent.AgentName) - $($ProbAgent.Issues)" -ForegroundColor $StatusColor
    }
} else {
    Write-Host "  All agents healthy." -ForegroundColor Green
}

# --- Step 3: Check pending agents ---
Write-Host ""
Write-Host "[3/4] Checking pending agents..." -ForegroundColor Cyan

$PendingAgentsOverdue = @()
try {
    $PendingAgents = @(Get-LrAgentsPending)
    Write-Host "  Pending agents: $($PendingAgents.Count)" -ForegroundColor White

    if ($PendingAgents.Count -gt 0) {
        $PendingAgentsOverdue = @($PendingAgents | Where-Object {
            $_.dateUpdated -and ([datetime]$_.dateUpdated -lt $PendingCutoff)
        })

        if ($PendingAgentsOverdue.Count -gt 0) {
            Write-Host "  Overdue pending agents (> ${PendingThresholdHours}h):" -ForegroundColor Yellow
            foreach ($PendAgent in $PendingAgentsOverdue) {
                $WaitingHours = [math]::Round(
                    ((Get-Date) - [datetime]$PendAgent.dateUpdated).TotalHours, 1
                )
                Write-Host "    $($PendAgent.name) - waiting $WaitingHours hours" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  No overdue pending agents." -ForegroundColor Green
        }
    }
} catch {
    Write-Host "WARNING: Could not retrieve pending agents. $_" -ForegroundColor Yellow
}

# --- Step 4: Check pending log sources ---
Write-Host ""
Write-Host "[4/4] Checking pending log sources..." -ForegroundColor Cyan

$PendingLogSourcesOverdue = @()
try {
    $PendingLogSources = @(Get-LrLogSourcesPending)
    Write-Host "  Pending log sources: $($PendingLogSources.Count)" -ForegroundColor White

    if ($PendingLogSources.Count -gt 0) {
        $PendingLogSourcesOverdue = @($PendingLogSources | Where-Object {
            $_.dateUpdated -and ([datetime]$_.dateUpdated -lt $PendingCutoff)
        })

        if ($PendingLogSourcesOverdue.Count -gt 0) {
            Write-Host "  Overdue pending log sources (> ${PendingThresholdHours}h):" -ForegroundColor Yellow
            foreach ($PendLs in $PendingLogSourcesOverdue | Select-Object -First 20) {
                $WaitingHours = [math]::Round(
                    ((Get-Date) - [datetime]$PendLs.dateUpdated).TotalHours, 1
                )
                Write-Host "    $($PendLs.name) - waiting $WaitingHours hours" -ForegroundColor Yellow
            }
            if ($PendingLogSourcesOverdue.Count -gt 20) {
                Write-Host "    ... and $($PendingLogSourcesOverdue.Count - 20) more" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  No overdue pending log sources." -ForegroundColor Green
        }
    }
} catch {
    Write-Host "WARNING: Could not retrieve pending log sources. $_" -ForegroundColor Yellow
}

# --- Health Report Summary ---
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Health Check Summary" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Accepted Agents      : $($AcceptedAgents.Count)" -ForegroundColor White
Write-Host "    OK                 : $AgentsOk" -ForegroundColor Green
Write-Host "    Warning            : $AgentsWarning" -ForegroundColor $(if ($AgentsWarning -gt 0) { "Yellow" } else { "White" })
Write-Host "    Critical           : $AgentsCritical" -ForegroundColor $(if ($AgentsCritical -gt 0) { "Red" } else { "White" })
Write-Host "  Pending Agents       : $($PendingAgents.Count)" -ForegroundColor White
Write-Host "    Overdue            : $($PendingAgentsOverdue.Count)" -ForegroundColor $(if ($PendingAgentsOverdue.Count -gt 0) { "Yellow" } else { "White" })
Write-Host "  Pending Log Sources  : $($PendingLogSources.Count)" -ForegroundColor White
Write-Host "    Overdue            : $($PendingLogSourcesOverdue.Count)" -ForegroundColor $(if ($PendingLogSourcesOverdue.Count -gt 0) { "Yellow" } else { "White" })
Write-Host "========================================" -ForegroundColor Green

# --- Export to CSV ---
if ($OutputCsv) {
    Write-Host ""
    Write-Host "Exporting agent report to: $OutputCsv" -ForegroundColor Cyan
    try {
        $AgentReport | Export-Csv -Path $OutputCsv -NoTypeInformation -Force
        Write-Host "  CSV export complete." -ForegroundColor Green
    } catch {
        Write-Host "ERROR: Failed to export CSV. $_" -ForegroundColor Red
    }
}

# Return the report object for pipeline use
$AgentReport
