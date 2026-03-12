<#
.SYNOPSIS
    SmartResponse action to isolate a compromised host and document in a case.
.DESCRIPTION
    Invoke-HostIsolationResponse performs automated host containment when a
    high-severity alarm fires. It looks up the host in LogRhythm, creates or
    updates a case with isolation details, retires the host record, and applies
    containment tags for tracking.

    Designed for use as a LogRhythm SmartResponse plugin. Deploy the companion
    actions.xml file to register this script in the SmartResponse framework.

    Supports -WhatIf for dry-run validation before production deployment.
.PARAMETER HostName
    Name or IP address of the host to isolate.
.PARAMETER CaseId
    Optional existing case ID to attach isolation evidence to. If omitted, a
    new case is created.
.PARAMETER AlarmId
    Optional alarm ID that triggered this response. Added as evidence if provided.
.PARAMETER Credential
    PSCredential containing an API Token. Defaults to $LrtConfig.LogRhythm.ApiKey.
.EXAMPLE
    PS C:\> .\Invoke-HostIsolationResponse.ps1 -HostName "WORKSTATION-042"

    Isolates the host, creates a new case, and tags it for tracking.
.EXAMPLE
    PS C:\> .\Invoke-HostIsolationResponse.ps1 -HostName "10.1.5.22" -CaseId 4501 -WhatIf

    Shows what actions would be taken without making changes.
.EXAMPLE
    PS C:\> .\Invoke-HostIsolationResponse.ps1 -HostName "SRV-DC01" -AlarmId 88712 -CaseId 4501
.LINK
    https://github.com/LogRhythm-Tools/LogRhythm.Tools
#>

[CmdletBinding(SupportsShouldProcess)]
Param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string] $HostName,

    [Parameter(Mandatory = $false, Position = 1)]
    [int] $CaseId,

    [Parameter(Mandatory = $false, Position = 2)]
    [int] $AlarmId,

    [Parameter(Mandatory = $false, Position = 3)]
    [ValidateNotNull()]
    [pscredential] $Credential = $LrtConfig.LogRhythm.ApiKey
)

$ActionTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Step 1: Look up the host
Write-Host "Looking up host: $HostName"
$HostRecord = Get-LrHosts -Name $HostName -Exact -Credential $Credential

if (-not $HostRecord) {
    Write-Host "ERROR: Host '$HostName' not found in LogRhythm." -ForegroundColor Red
    return
}

$HostId = $HostRecord.id
$EntityName = $HostRecord.entity.name
Write-Host "  Found host ID $HostId in entity '$EntityName'" -ForegroundColor Green

# Step 2: Create or use existing case
$CaseName = "Host Isolation - $HostName - $ActionTimestamp"
$IsolationNote = @"
AUTOMATED HOST ISOLATION
=========================
Timestamp:  $ActionTimestamp
Host:       $HostName (ID: $HostId)
Entity:     $EntityName
Action:     Host status set to Retired
Alarm ID:   $(if ($AlarmId) { $AlarmId } else { 'N/A' })
Initiated:  SmartResponse - Invoke-HostIsolationResponse
"@

if ($CaseId) {
    Write-Host "Using existing case: $CaseId"
    $Case = Get-LrCaseById -Id $CaseId -Credential $Credential
    if (-not $Case) {
        Write-Host "ERROR: Case $CaseId not found. Creating new case instead." -ForegroundColor Yellow
        $CaseId = 0
    }
}

if (-not $CaseId) {
    if ($PSCmdlet.ShouldProcess($CaseName, "Create new case")) {
        Write-Host "Creating case: $CaseName"
        $Case = New-LrCase -Name $CaseName -Priority 1 -Summary $IsolationNote -Credential $Credential
        $CaseId = $Case.number
        Write-Host "  Created case #$CaseId" -ForegroundColor Green
    }
}

# Step 3: Add isolation note to case
if ($CaseId -and $PSCmdlet.ShouldProcess("Case #$CaseId", "Add isolation note")) {
    Add-LrNoteToCase -Id $CaseId -Text $IsolationNote -Credential $Credential
    Write-Host "  Added isolation note to case #$CaseId"
}

# Step 4: Attach alarm evidence if provided
if ($AlarmId -and $CaseId) {
    if ($PSCmdlet.ShouldProcess("Alarm $AlarmId", "Add to case #$CaseId")) {
        try {
            Add-LrAlarmToCase -Id $CaseId -AlarmNumbers $AlarmId -Credential $Credential
            Write-Host "  Attached alarm $AlarmId to case #$CaseId"
        } catch {
            Write-Host "  WARNING: Could not attach alarm: $_" -ForegroundColor Yellow
        }
    }
}

# Step 5: Retire the host (isolation action)
if ($PSCmdlet.ShouldProcess("Host '$HostName' (ID: $HostId)", "Set status to Retired")) {
    Write-Host "Retiring host: $HostName (ID: $HostId)"
    try {
        Update-LrHostStatus -HostId $HostId -Status "Retired" -PassThru -Credential $Credential
        Write-Host "  Host retired successfully." -ForegroundColor Green
    } catch {
        Write-Host "  ERROR: Failed to retire host: $_" -ForegroundColor Red
        if ($CaseId) {
            Add-LrNoteToCase -Id $CaseId -Text "ERROR: Host retirement failed - $_" -Credential $Credential
        }
    }
}

# Step 6: Add containment tags
$Tags = @("isolated", "containment", "automated-response")
if ($CaseId -and $PSCmdlet.ShouldProcess("Case #$CaseId", "Add tags: $($Tags -join ', ')")) {
    try {
        Add-LrCaseTags -Id $CaseId -Tags $Tags -Credential $Credential
        Write-Host "  Tags added: $($Tags -join ', ')" -ForegroundColor Green
    } catch {
        Write-Host "  WARNING: Could not add tags: $_" -ForegroundColor Yellow
    }
}

# Summary
Write-Host "`n========== Isolation Summary ==========" -ForegroundColor Cyan
Write-Host "Host:     $HostName (ID: $HostId)"
Write-Host "Entity:   $EntityName"
Write-Host "Case:     #$CaseId"
Write-Host "Status:   Retired (Isolated)"
Write-Host "Tags:     $($Tags -join ', ')"
Write-Host "Time:     $ActionTimestamp"
Write-Host "========================================" -ForegroundColor Cyan
