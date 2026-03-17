#Requires -Version 5.0
<#
.SYNOPSIS
    Live API test harness for SIEM.Tools (LogRhythm + Exabeam) cmdlets.
.DESCRIPTION
    Runs cmdlets against live LogRhythm 7.23 XM and/or Exabeam NewScale environments,
    tracks pass/fail/skip status, measures response timing, and saves structured JSON
    results to tests/results/.

    Phase 1 - Discovery: Parameterless list cmdlets populate a cache
    Phase 2 - Id-Dependent: Cmdlets that need an Id resolved from the discovery cache
    Phase 3 - Complex: Cmdlets requiring constructed parameters (date ranges, etc.)
    Phase 4 - Mutating: Create/Update/Delete lifecycle tests (requires -IncludeMutating)
.PARAMETER Platform
    Which SIEM platform(s) to test: LogRhythm, Exabeam, or Both. Default: Both.
.PARAMETER Category
    Filter LogRhythm tests by subcategory. Default: All.
.PARAMETER IncludeMutating
    Include New/Update/Remove lifecycle tests (creates temporary test objects, then cleans up).
.PARAMETER SkipSlow
    Skip cmdlets marked as slow (e.g., Get-LrMpeRule).
.PARAMETER Detailed
    Show per-cmdlet verbose output during execution.
.EXAMPLE
    PS C:\> .\Test-LiveApiEndpoints.ps1 -Platform Exabeam
    ---
    Run only Exabeam endpoint tests.
.EXAMPLE
    PS C:\> .\Test-LiveApiEndpoints.ps1 -Platform LogRhythm -Category Admin
    ---
    Run only LogRhythm Admin category tests.
.EXAMPLE
    PS C:\> .\Test-LiveApiEndpoints.ps1 -Platform Both
    ---
    Run all tests across both platforms.
.EXAMPLE
    PS C:\> .\Test-LiveApiEndpoints.ps1 -Platform Exabeam -IncludeMutating
    ---
    Run Exabeam tests including create/update/delete lifecycle.
.LINK
    https://github.com/LogRhythm-Tools/LogRhythm.Tools
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $false, Position = 0)]
    [ValidateSet("LogRhythm", "Exabeam", "Both")]
    [string] $Platform = "Both",

    [Parameter(Mandatory = $false, Position = 1)]
    [ValidateSet("Admin", "Case", "Alarm", "Metrics", "AIE", "All")]
    [string] $Category = "All",

    [Parameter(Mandatory = $false)]
    [switch] $IncludeMutating,

    [Parameter(Mandatory = $false)]
    [switch] $SkipSlow,

    [Parameter(Mandatory = $false)]
    [switch] $Detailed
)

# ============================================================================
# Setup
# ============================================================================
$RunLr = $Platform -eq "LogRhythm" -or $Platform -eq "Both"
$RunExa = $Platform -eq "Exabeam" -or $Platform -eq "Both"
$ErrorActionPreference = "Continue"
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptRoot
$ResultsDir = Join-Path $ScriptRoot "results"
$Psm1Path = Join-Path (Join-Path $RepoRoot "src") "LogRhythm.Tools.psm1"

if (-not (Test-Path $ResultsDir)) {
    New-Item -Path $ResultsDir -ItemType Directory -Force | Out-Null
}

# Counters
$TotalPass = 0
$TotalFail = 0
$TotalSkip = 0
$TotalWarn = 0

# Discovery cache: key -> first result object
$DiscoveryCache = @{}

# Test results collection
$TestResults = [System.Collections.Generic.List[object]]::new()

# Run metadata
$RunId = [guid]::NewGuid().ToString()
$RunStart = Get-Date

# ============================================================================
# Helper Functions
# ============================================================================

function Write-TestResult {
    param(
        [string] $Cmdlet,
        [string] $Status,
        [string] $Detail,
        [int] $ElapsedMs = 0,
        [int] $ResultCount = -1
    )
    $Pad = 42
    $CmdletDisplay = $Cmdlet.PadRight($Pad)
    $TimingDisplay = if ($ElapsedMs -gt 0) { "${ElapsedMs}ms".PadLeft(8) } else { "  --    " }
    $CountDisplay = if ($ResultCount -ge 0) { "  ($ResultCount results)" } else { "" }

    switch ($Status) {
        "PASS" {
            $script:TotalPass++
            Write-Host "  [PASS] $CmdletDisplay $TimingDisplay$CountDisplay" -ForegroundColor Green
        }
        "FAIL" {
            $script:TotalFail++
            Write-Host "  [FAIL] $CmdletDisplay $TimingDisplay  $Detail" -ForegroundColor Red
        }
        "SKIP" {
            $script:TotalSkip++
            if ($Detailed) {
                Write-Host "  [SKIP] $CmdletDisplay   --     ($Detail)" -ForegroundColor DarkGray
            }
        }
        "WARN" {
            $script:TotalWarn++
            Write-Host "  [WARN] $CmdletDisplay $TimingDisplay$CountDisplay  $Detail" -ForegroundColor Yellow
        }
    }
}

function Resolve-Placeholder {
    param([string] $Placeholder)
    # Format: '{CacheKey.property}'
    if ($Placeholder -match "^\{(.+)\.(.+)\}$") {
        $CacheKey = $Matches[1]
        $Property = $Matches[2]
        if ($DiscoveryCache.ContainsKey($CacheKey)) {
            $Obj = $DiscoveryCache[$CacheKey]
            if ($null -ne $Obj.$Property) {
                return $Obj.$Property
            }
        }
        return $null
    }
    return $Placeholder
}

function Invoke-LiveTest {
    param(
        [hashtable] $TestDef
    )

    $CmdletName = $TestDef.Cmdlet

    # Build parameters
    $Params = @{}
    $ParamDisplay = ""
    if ($TestDef.Parameters -and $TestDef.Parameters.Count -gt 0) {
        foreach ($Key in $TestDef.Parameters.Keys) {
            $Val = $TestDef.Parameters[$Key]

            # ScriptBlock: evaluate at runtime
            if ($Val -is [scriptblock]) {
                $Val = & $Val
            }
            # String placeholder: resolve from cache
            elseif ($Val -is [string] -and $Val -match "^\{.+\..+\}$") {
                $Resolved = Resolve-Placeholder $Val
                if ($null -eq $Resolved) {
                    return @{
                        Status       = "SKIP"
                        Detail       = "$($TestDef.DependsOn) empty or missing"
                        ElapsedMs    = 0
                        ResultCount  = 0
                        RetryCount   = 0
                        HttpCode     = $null
                        ErrorDetail  = $null
                    }
                }
                $Val = $Resolved
            }

            $Params[$Key] = $Val
            $ParamDisplay += " -$Key $Val"
        }
    }

    # Execute with timing
    $RetryCount = 0
    $Warnings = @()
    $ElapsedMs = 0
    $Response = $null
    $ErrorDetail = $null
    $HttpCode = $null
    $Status = "PASS"

    try {
        $Timer = [System.Diagnostics.Stopwatch]::StartNew()
        if ($Params.Count -gt 0) {
            $Response = & $CmdletName @Params -WarningVariable Warnings -ErrorAction Stop
        } else {
            $Response = & $CmdletName -WarningVariable Warnings -ErrorAction Stop
        }
        $Timer.Stop()
        $ElapsedMs = [int]$Timer.ElapsedMilliseconds
    } catch {
        if ($Timer -and $Timer.IsRunning) { $Timer.Stop() }
        $ElapsedMs = if ($Timer) { [int]$Timer.ElapsedMilliseconds } else { 0 }
        $Status = "FAIL"
        $ErrorDetail = $_.Exception.Message
        if ($_.Exception.Response) {
            $HttpCode = $_.Exception.Response.StatusCode.value__
        }
    }

    # Check for ErrorObject pattern
    if ($null -ne $Response -and $Response -is [PSCustomObject]) {
        if (($null -ne $Response.PSObject.Properties['Error']) -and ($Response.Error -eq $true)) {
            $Status = "FAIL"
            $HttpCode = $Response.Code
            $ErrorDetail = $Response.Note
            if ($Response.Type) { $ErrorDetail = "[$($Response.Type)] $ErrorDetail" }
        }
    }

    # Detect retries from verbose/warning messages
    if ($Warnings) {
        foreach ($w in $Warnings) {
            if ($w -match 'HTTP\s+\d+.*C:(\d+)\s+M:') {
                $c = [int]$Matches[1]
                if ($c -gt $RetryCount) { $RetryCount = $c }
            }
        }
    }

    # Infer HTTP 200 for successful responses (Invoke-RestMethod doesn't expose status code on success)
    if ($Status -eq "PASS" -and $null -eq $HttpCode) {
        $HttpCode = 200
    }

    # Count results
    $ResultCount = 0
    if ($Status -eq "PASS" -or $Status -eq "WARN") {
        if ($null -eq $Response) {
            $ResultCount = 0
            $Status = "WARN"
            if ($null -eq $HttpCode) { $HttpCode = 200 }
        } elseif ($Response -is [array]) {
            $ResultCount = $Response.Count
        } else {
            $ResultCount = 1
        }
    }

    # Warn on zero results for discovery cmdlets
    if ($Status -eq "PASS" -and $ResultCount -eq 0 -and $TestDef.IsDiscovery) {
        $Status = "WARN"
    }

    # Cache discovery results
    if ($TestDef.IsDiscovery -and $TestDef.DiscoveryKey -and $ResultCount -gt 0) {
        $FirstItem = if ($Response -is [array]) { $Response[0] } else { $Response }
        $DiscoveryCache[$TestDef.DiscoveryKey] = $FirstItem
    }

    return @{
        Status       = $Status
        Detail       = $ErrorDetail
        ElapsedMs    = $ElapsedMs
        ResultCount  = $ResultCount
        RetryCount   = $RetryCount
        HttpCode     = $HttpCode
        ErrorDetail  = $ErrorDetail
        ParamDisplay = $ParamDisplay
    }
}

# ============================================================================
# Test Definition Table — LogRhythm Only
# ============================================================================

$AllTests = @(
    # ===========================================================
    # Admin Discovery (Phase 1)
    # ===========================================================
    @{ Cmdlet = "Get-LrAgentsAccepted";     Category = "Admin"; Subcategory = "Agents";        Phase = 1; IsSlow = $false; IsDiscovery = $true;  DiscoveryKey = "LrAgents";                IdProperty = "id";         Parameters = @{}; DependsOn = $null }
    @{ Cmdlet = "Get-LrAgentsPending";      Category = "Admin"; Subcategory = "Agents";        Phase = 1; IsSlow = $false; IsDiscovery = $true;  DiscoveryKey = "LrAgentsPending";         IdProperty = "id";         Parameters = @{}; DependsOn = $null }
    @{ Cmdlet = "Get-LrBeats";              Category = "Admin"; Subcategory = "Beats";         Phase = 1; IsSlow = $false; IsDiscovery = $true;  DiscoveryKey = "LrBeats";                 IdProperty = "id";         Parameters = @{}; DependsOn = $null }
    @{ Cmdlet = "Get-LrBeatTypes";          Category = "Admin"; Subcategory = "Beats";         Phase = 1; IsSlow = $false; IsDiscovery = $true;  DiscoveryKey = "LrBeatTypes";             IdProperty = "id";         Parameters = @{}; DependsOn = $null }
    @{ Cmdlet = "Get-LrEntities";           Category = "Admin"; Subcategory = "Entities";      Phase = 1; IsSlow = $false; IsDiscovery = $true;  DiscoveryKey = "LrEntities";              IdProperty = "id";         Parameters = @{}; DependsOn = $null }
    @{ Cmdlet = "Get-LrHosts";              Category = "Admin"; Subcategory = "Hosts";         Phase = 1; IsSlow = $false; IsDiscovery = $true;  DiscoveryKey = "LrHosts";                 IdProperty = "id";         Parameters = @{}; DependsOn = $null }
    @{ Cmdlet = "Get-LrIdentities";         Category = "Admin"; Subcategory = "Identities";    Phase = 1; IsSlow = $false; IsDiscovery = $true;  DiscoveryKey = "LrIdentities";            IdProperty = "identityID"; Parameters = @{}; DependsOn = $null }
    @{ Cmdlet = "Get-LrLists";              Category = "Admin"; Subcategory = "Lists";         Phase = 1; IsSlow = $false; IsDiscovery = $true;  DiscoveryKey = "LrLists";                 IdProperty = "guid";       Parameters = @{}; DependsOn = $null }
    @{ Cmdlet = "Get-LrLogSources";         Category = "Admin"; Subcategory = "LogSources";    Phase = 1; IsSlow = $false; IsDiscovery = $true;  DiscoveryKey = "LrLogSources";            IdProperty = "id";         Parameters = @{}; DependsOn = $null }
    @{ Cmdlet = "Get-LrLogSourceTypes";     Category = "Admin"; Subcategory = "LogSources";    Phase = 1; IsSlow = $false; IsDiscovery = $true;  DiscoveryKey = "LrLogSourceTypes";         IdProperty = "id";         Parameters = @{}; DependsOn = $null }
    @{ Cmdlet = "Get-LrLogSourcesPending";  Category = "Admin"; Subcategory = "LogSources";    Phase = 1; IsSlow = $false; IsDiscovery = $true;  DiscoveryKey = "LrLogSourcesPending";      IdProperty = "id";         Parameters = @{}; DependsOn = $null }
    @{ Cmdlet = "Get-LrLsvTemplates";       Category = "Admin"; Subcategory = "LSV";           Phase = 1; IsSlow = $false; IsDiscovery = $true;  DiscoveryKey = "LrLsvTemplates";           IdProperty = "id";         Parameters = @{}; DependsOn = $null }
    @{ Cmdlet = "Get-LrMpePolicies";        Category = "Admin"; Subcategory = "MPE";           Phase = 1; IsSlow = $false; IsDiscovery = $true;  DiscoveryKey = "LrMpePolicies";            IdProperty = "id";         Parameters = @{}; DependsOn = $null }
    @{ Cmdlet = "Get-LrMpePoliciesSummary"; Category = "Admin"; Subcategory = "MPE";           Phase = 1; IsSlow = $false; IsDiscovery = $true;  DiscoveryKey = "LrMpePoliciesSummary";     IdProperty = "id";         Parameters = @{}; DependsOn = $null }
    @{ Cmdlet = "Get-LrMsgSourceTypes";     Category = "Admin"; Subcategory = "MsgSources";    Phase = 1; IsSlow = $false; IsDiscovery = $true;  DiscoveryKey = "LrMsgSourceTypes";         IdProperty = "id";         Parameters = @{}; DependsOn = $null }
    @{ Cmdlet = "Get-LrNetworks";           Category = "Admin"; Subcategory = "Networks";      Phase = 1; IsSlow = $false; IsDiscovery = $true;  DiscoveryKey = "LrNetworks";               IdProperty = "id";         Parameters = @{}; DependsOn = $null }
    @{ Cmdlet = "Get-LrNotificationGroups"; Category = "Admin"; Subcategory = "Notifications"; Phase = 1; IsSlow = $false; IsDiscovery = $true;  DiscoveryKey = "LrNotificationGroups";     IdProperty = "id";         Parameters = @{}; DependsOn = $null }
    @{ Cmdlet = "Get-LrOpenCollectors";     Category = "Admin"; Subcategory = "OpenCollectors"; Phase = 1; IsSlow = $false; IsDiscovery = $true; DiscoveryKey = "LrOpenCollectors";         IdProperty = "id";         Parameters = @{}; DependsOn = $null }
    @{ Cmdlet = "Get-LrAdminUsers";         Category = "Admin"; Subcategory = "Users";         Phase = 1; IsSlow = $false; IsDiscovery = $true;  DiscoveryKey = "LrAdminUsers";             IdProperty = "id";         Parameters = @{}; DependsOn = $null }
    @{ Cmdlet = "Get-LrUserProfiles";       Category = "Admin"; Subcategory = "Users";         Phase = 1; IsSlow = $false; IsDiscovery = $true;  DiscoveryKey = "LrUserProfiles";           IdProperty = "id";         Parameters = @{}; DependsOn = $null }
    @{ Cmdlet = "Get-LrUserProfilesSummary"; Category = "Admin"; Subcategory = "Users";        Phase = 1; IsSlow = $false; IsDiscovery = $true;  DiscoveryKey = "LrUserProfilesSummary";    IdProperty = "id";         Parameters = @{}; DependsOn = $null }
    @{ Cmdlet = "Get-LrUserLogins";         Category = "Admin"; Subcategory = "Users";         Phase = 1; IsSlow = $false; IsDiscovery = $true;  DiscoveryKey = "LrUserLogins";             IdProperty = "personId";   Parameters = @{}; DependsOn = $null }
    @{ Cmdlet = "Get-LrUserPermissions";    Category = "Admin"; Subcategory = "Users";         Phase = 1; IsSlow = $false; IsDiscovery = $true;  DiscoveryKey = "LrUserPermissions";        IdProperty = "id";         Parameters = @{}; DependsOn = $null }
    @{ Cmdlet = "Get-LrUserPrivileges";     Category = "Admin"; Subcategory = "Users";         Phase = 1; IsSlow = $false; IsDiscovery = $true;  DiscoveryKey = "LrUserPrivileges";         IdProperty = "id";         Parameters = @{}; DependsOn = $null }
    @{ Cmdlet = "Get-LrLicenses";           Category = "Admin"; Subcategory = "Licenses";      Phase = 1; IsSlow = $false; IsDiscovery = $true;  DiscoveryKey = "LrLicenses";               IdProperty = "id";         Parameters = @{}; DependsOn = $null }
    @{ Cmdlet = "Get-LrLicenseEntitlements"; Category = "Admin"; Subcategory = "Licenses";     Phase = 1; IsSlow = $false; IsDiscovery = $true;  DiscoveryKey = "LrLicenseEntitlements";    IdProperty = "id";         Parameters = @{}; DependsOn = $null }
    @{ Cmdlet = "Get-LrLocations";          Category = "Admin"; Subcategory = "Locations";     Phase = 1; IsSlow = $false; IsDiscovery = $true;  DiscoveryKey = "LrLocations";              IdProperty = "id";         Parameters = @{}; DependsOn = $null }

    # ===========================================================
    # Admin Id-Dependent (Phase 2)
    # ===========================================================
    @{ Cmdlet = "Get-LrAgentDetails";           Category = "Admin"; Subcategory = "Agents";        Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ Id = '{LrAgents.id}' };              DependsOn = "LrAgents" }
    @{ Cmdlet = "Get-LrAgentLogSources";        Category = "Admin"; Subcategory = "Agents";        Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ Id = '{LrAgents.id}' };              DependsOn = "LrAgents" }
    @{ Cmdlet = "Get-LrAgentPendingDetails";    Category = "Admin"; Subcategory = "Agents";        Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ Id = '{LrAgentsPending.id}' };       DependsOn = "LrAgentsPending" }
    @{ Cmdlet = "Get-LrBeat";                   Category = "Admin"; Subcategory = "Beats";         Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ Id = '{LrBeats.id}' };               DependsOn = "LrBeats" }
    @{ Cmdlet = "Get-LrBeatTemplate";           Category = "Admin"; Subcategory = "Beats";         Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ Id = '{LrBeats.id}' };               DependsOn = "LrBeats" }
    @{ Cmdlet = "Get-LrEntityDetails";          Category = "Admin"; Subcategory = "Entities";      Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ Id = '{LrEntities.id}' };            DependsOn = "LrEntities" }
    @{ Cmdlet = "Get-LrHostDetails";            Category = "Admin"; Subcategory = "Hosts";         Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ Id = '{LrHosts.id}' };               DependsOn = "LrHosts" }
    @{ Cmdlet = "Get-LrHostIdentifiers";        Category = "Admin"; Subcategory = "Hosts";         Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ Id = '{LrHosts.id}' };               DependsOn = "LrHosts" }
    @{ Cmdlet = "Get-LrIdentityById";           Category = "Admin"; Subcategory = "Identities";    Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ IdentityId = '{LrIdentities.identityID}' }; DependsOn = "LrIdentities" }
    @{ Cmdlet = "Get-LrList";                   Category = "Admin"; Subcategory = "Lists";         Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ Name = '{LrLists.name}' };           DependsOn = "LrLists" }
    @{ Cmdlet = "Get-LrListItems";              Category = "Admin"; Subcategory = "Lists";         Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ Name = '{LrLists.name}' };           DependsOn = "LrLists" }
    @{ Cmdlet = "Get-LrLogSourceDetails";       Category = "Admin"; Subcategory = "LogSources";    Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ Id = '{LrLogSources.id}' };          DependsOn = "LrLogSources" }
    @{ Cmdlet = "Get-LrLogSourceTypeDetails";   Category = "Admin"; Subcategory = "LogSources";    Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ Id = '{LrLogSourceTypes.id}' };      DependsOn = "LrLogSourceTypes" }
    @{ Cmdlet = "Get-LrLogSourcePendingMatches"; Category = "Admin"; Subcategory = "LogSources";   Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ Id = '{LrLogSourcesPending.id}' };   DependsOn = "LrLogSourcesPending" }
    # Get-LrLsvTemplate skipped: /lsvtemplates/{id}/ endpoint does not exist in 7.23 Swagger (only /lsvtemplates/{id}/items/ exists)
    @{ Cmdlet = "Get-LrLsvTemplateItems";       Category = "Admin"; Subcategory = "LSV";           Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ Id = '{LrLsvTemplates.id}' };        DependsOn = "LrLsvTemplates" }
    @{ Cmdlet = "Get-LrMpePolicy";              Category = "Admin"; Subcategory = "MPE";           Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ Id = '{LrMpePolicies.id}' };         DependsOn = "LrMpePolicies" }
    @{ Cmdlet = "Get-LrMpePolicyRules";         Category = "Admin"; Subcategory = "MPE";           Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ Id = '{LrMpePolicies.id}' };         DependsOn = "LrMpePolicies" }
    @{ Cmdlet = "Get-LrMpeRule";                Category = "Admin"; Subcategory = "MPE";           Phase = 2; IsSlow = $true;  IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ Id = '{LrMpePolicies.id}' };         DependsOn = "LrMpePolicies"; Notes = "Can be very slow" }
    @{ Cmdlet = "Get-LrMsgSourceType";          Category = "Admin"; Subcategory = "MsgSources";    Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ Id = '{LrMsgSourceTypes.id}' };      DependsOn = "LrMsgSourceTypes" }
    @{ Cmdlet = "Get-LrNetworkDetails";         Category = "Admin"; Subcategory = "Networks";      Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ Id = '{LrNetworks.id}' };            DependsOn = "LrNetworks" }
    @{ Cmdlet = "Get-LrNotificationGroupUsers"; Category = "Admin"; Subcategory = "Notifications"; Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ Id = '{LrNotificationGroups.id}' };  DependsOn = "LrNotificationGroups" }
    @{ Cmdlet = "Get-LrOpenCollector";          Category = "Admin"; Subcategory = "OpenCollectors"; Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ Id = '{LrOpenCollectors.id}' };     DependsOn = "LrOpenCollectors" }
    @{ Cmdlet = "Get-LrOpenCollectorBeats";     Category = "Admin"; Subcategory = "OpenCollectors"; Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ Id = '{LrOpenCollectors.id}' };     DependsOn = "LrOpenCollectors" }
    @{ Cmdlet = "Get-LrAdminUser";              Category = "Admin"; Subcategory = "Users";         Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ Id = '{LrAdminUsers.id}' };          DependsOn = "LrAdminUsers" }
    @{ Cmdlet = "Get-LrUserProfile";            Category = "Admin"; Subcategory = "Users";         Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ Id = '{LrUserProfiles.id}' };        DependsOn = "LrUserProfiles" }
    @{ Cmdlet = "Get-LrUserProfileLogSources";  Category = "Admin"; Subcategory = "Users";         Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ Id = '{LrUserProfiles.id}' };        DependsOn = "LrUserProfiles" }
    @{ Cmdlet = "Get-LrUserProfilePrivileges";  Category = "Admin"; Subcategory = "Users";         Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ Id = '{LrUserProfiles.id}' };        DependsOn = "LrUserProfiles" }
    @{ Cmdlet = "Get-LrLocationDetails";        Category = "Admin"; Subcategory = "Locations";     Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ Id = '{LrLocations.id}' };           DependsOn = "LrLocations" }
    @{ Cmdlet = "Get-LrUserLoginsByPerson";     Category = "Admin"; Subcategory = "Users";         Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ Id = '{LrUserLogins.personId}' };    DependsOn = "LrUserLogins" }

    # ===========================================================
    # Case Discovery (Phase 1)
    # ===========================================================
    @{ Cmdlet = "Get-LrCases";             Category = "Case"; Subcategory = "General";   Phase = 1; IsSlow = $false; IsDiscovery = $true;  DiscoveryKey = "LrCases";             IdProperty = "id";     Parameters = @{}; DependsOn = $null }
    @{ Cmdlet = "Get-LrTags";              Category = "Case"; Subcategory = "Tags";      Phase = 1; IsSlow = $false; IsDiscovery = $true;  DiscoveryKey = "LrTags";              IdProperty = "number"; Parameters = @{}; DependsOn = $null }
    @{ Cmdlet = "Get-LrUsers";             Category = "Case"; Subcategory = "Users";     Phase = 1; IsSlow = $false; IsDiscovery = $true;  DiscoveryKey = "LrCaseUsers";         IdProperty = "number"; Parameters = @{}; DependsOn = $null }
    @{ Cmdlet = "Get-LrCollaborators";     Category = "Case"; Subcategory = "General";   Phase = 1; IsSlow = $false; IsDiscovery = $true;  DiscoveryKey = "LrCollaborators";     IdProperty = "number"; Parameters = @{}; DependsOn = $null }
    @{ Cmdlet = "Get-LrPlaybooks";         Category = "Case"; Subcategory = "Playbooks"; Phase = 1; IsSlow = $false; IsDiscovery = $true;  DiscoveryKey = "LrPlaybooks";         IdProperty = "id";     Parameters = @{}; DependsOn = $null }
    @{ Cmdlet = "Get-LrCaseFeatureFlags";  Category = "Case"; Subcategory = "General";   Phase = 1; IsSlow = $false; IsDiscovery = $true;  DiscoveryKey = "LrCaseFeatureFlags";  IdProperty = $null;    Parameters = @{}; DependsOn = $null }
    @{ Cmdlet = "Get-LrCaseLogsIndexes";   Category = "Case"; Subcategory = "General";   Phase = 1; IsSlow = $false; IsDiscovery = $true;  DiscoveryKey = "LrCaseLogsIndexes";   IdProperty = $null;    Parameters = @{}; DependsOn = $null }
    @{ Cmdlet = "Get-LrCaseCapabilities";  Category = "Case"; Subcategory = "General";   Phase = 1; IsSlow = $false; IsDiscovery = $true;  DiscoveryKey = "LrCaseCapabilities";  IdProperty = $null;    Parameters = @{}; DependsOn = $null }
    @{ Cmdlet = "Get-LrCaseGlobalHistory"; Category = "Case"; Subcategory = "History";   Phase = 1; IsSlow = $false; IsDiscovery = $true;  DiscoveryKey = "LrCaseGlobalHistory"; IdProperty = $null;    Parameters = @{}; DependsOn = $null }
    @{ Cmdlet = "Get-LrCaseMetrics";       Category = "Case"; Subcategory = "Metrics";   Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null;                 IdProperty = $null;    Parameters = @{ Id = '{LrCases.id}' }; DependsOn = "LrCases" }
    @{ Cmdlet = "Get-LrCaseStatusTable";   Category = "Case"; Subcategory = "General";   Phase = 1; IsSlow = $false; IsDiscovery = $true;  DiscoveryKey = "LrCaseStatusTable";   IdProperty = $null;    Parameters = @{}; DependsOn = $null }

    # ===========================================================
    # Case Id-Dependent (Phase 2)
    # ===========================================================
    @{ Cmdlet = "Get-LrCaseById";             Category = "Case"; Subcategory = "General";   Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ Id = '{LrCases.id}' };           DependsOn = "LrCases" }
    @{ Cmdlet = "Get-LrCaseHistory";          Category = "Case"; Subcategory = "History";   Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ Id = '{LrCases.id}' };           DependsOn = "LrCases" }
    @{ Cmdlet = "Get-LrCasePlaybooks";        Category = "Case"; Subcategory = "Playbooks"; Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ Id = '{LrCases.id}' };           DependsOn = "LrCases" }
    @{ Cmdlet = "Get-LrCaseEvidence";         Category = "Case"; Subcategory = "Evidence";  Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ Id = '{LrCases.id}' };           DependsOn = "LrCases" }
    @{ Cmdlet = "Get-LrCaseAssociatedCases";  Category = "Case"; Subcategory = "General";   Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ Id = '{LrCases.id}' };           DependsOn = "LrCases" }
    @{ Cmdlet = "Get-LrCaseEarliestEvidence"; Category = "Case"; Subcategory = "Evidence";  Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ Id = '{LrCases.id}' };           DependsOn = "LrCases" }
    @{ Cmdlet = "Get-LrPlaybookById";         Category = "Case"; Subcategory = "Playbooks"; Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ Id = '{LrPlaybooks.id}' };       DependsOn = "LrPlaybooks" }
    @{ Cmdlet = "Get-LrPlaybookProcedures";   Category = "Case"; Subcategory = "Playbooks"; Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ Id = '{LrPlaybooks.id}' };       DependsOn = "LrPlaybooks" }
    @{ Cmdlet = "Get-LrTag";                  Category = "Case"; Subcategory = "Tags";      Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ Number = '{LrTags.number}' };    DependsOn = "LrTags" }
    @{ Cmdlet = "Get-LrUserNumber";           Category = "Case"; Subcategory = "Users";     Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ User = '{LrCaseUsers.number}' }; DependsOn = "LrCaseUsers" }

    # ===========================================================
    # Alarm (Phase 1 + 2)
    # ===========================================================
    @{ Cmdlet = "Get-LrAlarms";       Category = "Alarm"; Subcategory = "Alarms"; Phase = 1; IsSlow = $false; IsDiscovery = $true;  DiscoveryKey = "LrAlarms";       IdProperty = "alarmId"; Parameters = @{}; DependsOn = $null }
    @{ Cmdlet = "Get-LrAlarmSummary"; Category = "Alarm"; Subcategory = "Alarms"; Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null;            IdProperty = $null;    Parameters = @{ AlarmId = '{LrAlarms.alarmId}' }; DependsOn = "LrAlarms" }
    @{ Cmdlet = "Get-LrAlarm";        Category = "Alarm"; Subcategory = "Alarms"; Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ AlarmId = '{LrAlarms.alarmId}' }; DependsOn = "LrAlarms" }
    @{ Cmdlet = "Get-LrAlarmEvents";  Category = "Alarm"; Subcategory = "Alarms"; Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ AlarmId = '{LrAlarms.alarmId}' }; DependsOn = "LrAlarms" }
    @{ Cmdlet = "Get-LrAlarmHistory"; Category = "Alarm"; Subcategory = "Alarms"; Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ AlarmId = '{LrAlarms.alarmId}' }; DependsOn = "LrAlarms" }

    # ===========================================================
    # Metrics (Phase 1 + 3)
    # ===========================================================
    @{ Cmdlet = "Get-LrTtlDetails"; Category = "Metrics"; Subcategory = "Metrics"; Phase = 1; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{}; DependsOn = $null }
    @{ Cmdlet = "Get-LrLogVolume";  Category = "Metrics"; Subcategory = "Metrics"; Phase = 3; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ StartDate = { (Get-Date).AddDays(-7) }; EndDate = { Get-Date } }; DependsOn = $null }

    # ===========================================================
    # Other (Phase 1)
    # ===========================================================
    @{ Cmdlet = "Test-LrtConfiguration"; Category = "Admin"; Subcategory = "Config"; Phase = 1; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{}; DependsOn = $null }
    @{ Cmdlet = "Get-LrAieSummary";      Category = "AIE";   Subcategory = "AIE";    Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null;          IdProperty = $null; Parameters = @{ AlarmId = '{LrAlarms.alarmId}' }; DependsOn = "LrAlarms" }

    # ===========================================================
    # Exabeam Discovery (Phase 1)
    # ===========================================================

    # --- Correlation Rules ---
    @{ Cmdlet = "Get-ExaCorrelationRules";       Category = "Exabeam"; Subcategory = "CorrelationRules";   Phase = 1; IsSlow = $false; IsDiscovery = $true;  DiscoveryKey = "ExaCorrRules";       IdProperty = "id"; Parameters = @{}; DependsOn = $null }

    # --- Detection Management ---
    @{ Cmdlet = "Get-ExaAnalyticsRules";         Category = "Exabeam"; Subcategory = "DetectionMgmt";     Phase = 1; IsSlow = $false; IsDiscovery = $true;  DiscoveryKey = "ExaAnalyticsRules";  IdProperty = "id"; Parameters = @{}; DependsOn = $null }

    # --- Context Tables ---
    @{ Cmdlet = "Get-ExaContextTables";          Category = "Exabeam"; Subcategory = "Context";           Phase = 1; IsSlow = $false; IsDiscovery = $true;  DiscoveryKey = "ExaContextTables";   IdProperty = "id"; Parameters = @{}; DependsOn = $null }

    # --- Cloud Collectors ---
    @{ Cmdlet = "Get-ExaCloudCollectors";        Category = "Exabeam"; Subcategory = "CloudCollectors";   Phase = 1; IsSlow = $false; IsDiscovery = $true;  DiscoveryKey = "ExaCloudCollectors"; IdProperty = "id"; Parameters = @{}; DependsOn = $null }
    @{ Cmdlet = "Get-ExaCloudAccounts";          Category = "Exabeam"; Subcategory = "CloudCollectors";   Phase = 1; IsSlow = $false; IsDiscovery = $true;  DiscoveryKey = "ExaCloudAccounts";   IdProperty = "id"; Parameters = @{}; DependsOn = $null }

    # --- Service Health ---
    @{ Cmdlet = "Get-ExaHealthStatus";           Category = "Exabeam"; Subcategory = "ServiceHealth";     Phase = 1; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null;                IdProperty = $null; Parameters = @{}; DependsOn = $null }
    @{ Cmdlet = "Get-ExaCorrelationRuleCount";   Category = "Exabeam"; Subcategory = "ServiceHealth";     Phase = 1; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null;                IdProperty = $null; Parameters = @{}; DependsOn = $null }
    @{ Cmdlet = "Get-ExaLicenseDetails";         Category = "Exabeam"; Subcategory = "ServiceHealth";     Phase = 1; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null;                IdProperty = $null; Parameters = @{}; DependsOn = $null }
    @{ Cmdlet = "Get-ExaStorageConsumption";     Category = "Exabeam"; Subcategory = "ServiceHealth";     Phase = 1; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null;                IdProperty = $null; Parameters = @{}; DependsOn = $null }

    # --- Platform ---
    @{ Cmdlet = "Get-ExaUsers";                  Category = "Exabeam"; Subcategory = "Platform";          Phase = 1; IsSlow = $false; IsDiscovery = $true;  DiscoveryKey = "ExaUsers";           IdProperty = "id"; Parameters = @{}; DependsOn = $null }
    @{ Cmdlet = "Get-ExaRoles";                  Category = "Exabeam"; Subcategory = "Platform";          Phase = 1; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null;                IdProperty = $null; Parameters = @{}; DependsOn = $null }
    @{ Cmdlet = "Get-ExaApiKeys";                Category = "Exabeam"; Subcategory = "Platform";          Phase = 1; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null;                IdProperty = $null; Parameters = @{}; DependsOn = $null }

    # --- Agents ---
    @{ Cmdlet = "Get-ExaSiteAgents";             Category = "Exabeam"; Subcategory = "Agents";            Phase = 1; IsSlow = $false; IsDiscovery = $true;  DiscoveryKey = "ExaAgents";          IdProperty = "id"; Parameters = @{}; DependsOn = $null }

    # --- Cores ---
    @{ Cmdlet = "Get-ExaSiteCollectors";         Category = "Exabeam"; Subcategory = "Cores";             Phase = 1; IsSlow = $false; IsDiscovery = $true;  DiscoveryKey = "ExaCollectors";      IdProperty = "id"; Parameters = @{}; DependsOn = $null }


    # --- Search (Phase 3 — requires parameters) ---
    @{ Cmdlet = "Get-ExaSearch";                 Category = "Exabeam"; Subcategory = "Search";            Phase = 3; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null;                IdProperty = $null; Parameters = @{
            Filter = { 'activity_type:"app-login"' }
            Fields = { @("user", "activity_type", "outcome") }
        }; DependsOn = $null }

    # --- Audit (Phase 3 — requires parameters) ---
    @{ Cmdlet = "Search-ExaAuditEvents";         Category = "Exabeam"; Subcategory = "Audit";             Phase = 3; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null;                IdProperty = $null; Parameters = @{
            Filter = { '*' }
            StartTime = { (Get-Date).AddDays(-7).ToString("yyyy-MM-ddTHH:mm:ssZ") }
            EndTime = { (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ") }
        }; DependsOn = $null }

    # --- MITRE ---
    @{ Cmdlet = "Get-ExaMitreTechniques";        Category = "Exabeam"; Subcategory = "Mitre";             Phase = 1; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null;                IdProperty = $null; Parameters = @{}; DependsOn = $null }

    # --- Use Cases ---
    @{ Cmdlet = "Get-ExaUseCases";               Category = "Exabeam"; Subcategory = "UseCases";          Phase = 1; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null;                IdProperty = $null; Parameters = @{}; DependsOn = $null }

    # ===========================================================
    # Exabeam Id-Dependent (Phase 2)
    # ===========================================================

    # --- Correlation Rules ---
    @{ Cmdlet = "Get-ExaCorrelationRuleById";    Category = "Exabeam"; Subcategory = "CorrelationRules";   Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ Id = '{ExaCorrRules.id}' };              DependsOn = "ExaCorrRules" }
    @{ Cmdlet = "Export-ExaCorrelationRules";     Category = "Exabeam"; Subcategory = "CorrelationRules";   Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ Id = '{ExaCorrRules.id}' };              DependsOn = "ExaCorrRules" }

    # --- Detection Management ---
    @{ Cmdlet = "Export-ExaAnalyticsRules";       Category = "Exabeam"; Subcategory = "DetectionMgmt";     Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ Id = '{ExaAnalyticsRules.id}' };          DependsOn = "ExaAnalyticsRules" }

    # --- Context Tables ---
    @{ Cmdlet = "Get-ExaContextTable";           Category = "Exabeam"; Subcategory = "Context";           Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ Id = '{ExaContextTables.id}' };           DependsOn = "ExaContextTables" }
    @{ Cmdlet = "Get-ExaContextTableAttributes"; Category = "Exabeam"; Subcategory = "Context";           Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ Id = '{ExaContextTables.id}' };           DependsOn = "ExaContextTables" }
    @{ Cmdlet = "Get-ExaContextAttributes";      Category = "Exabeam"; Subcategory = "Context";           Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ Id = '{ExaContextTables.id}' };           DependsOn = "ExaContextTables" }
    @{ Cmdlet = "Get-ExaContextRecords";         Category = "Exabeam"; Subcategory = "Context";           Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ Id = '{ExaContextTables.id}' };           DependsOn = "ExaContextTables" }

    # --- Cloud Collectors ---
    @{ Cmdlet = "Get-ExaCloudCollector";         Category = "Exabeam"; Subcategory = "CloudCollectors";   Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ Id = '{ExaCloudCollectors.id}' };         DependsOn = "ExaCloudCollectors" }
    @{ Cmdlet = "Get-ExaCloudAccount";           Category = "Exabeam"; Subcategory = "CloudCollectors";   Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ Id = '{ExaCloudAccounts.id}' };           DependsOn = "ExaCloudAccounts" }

    # --- Agents ---
    @{ Cmdlet = "Get-ExaSiteAgentInstallCommand"; Category = "Exabeam"; Subcategory = "Agents";           Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ Type = "windows" };                       DependsOn = $null }

    # --- Cores (Id-Dependent) ---
    @{ Cmdlet = "Get-ExaSiteCollectorCerts";     Category = "Exabeam"; Subcategory = "Cores";             Phase = 2; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; Parameters = @{ CoreID = '{ExaCollectors.id}' };           DependsOn = "ExaCollectors" }

    # ===========================================================
    # Exabeam Mutating Lifecycle (Phase 4 — requires -IncludeMutating)
    # ===========================================================
    @{ Cmdlet = "New-ExaCorrelationRule";        Category = "Exabeam"; Subcategory = "CorrelationRules";   Phase = 4; IsSlow = $false; IsDiscovery = $true; DiscoveryKey = "ExaTestRule"; IdProperty = "id"; IsMutating = $true; Parameters = @{
            Name = "[TEST-HARNESS] Lifecycle Test"
            Description = "Automated test - safe to delete"
            Severity = "low"
            SequencesConfig = { @{ sequences = @(@{ name = "test"; query = 'activity_type:"app-login"'; condition = @{ triggerOnAnyMatch = $true } }) } }
            PassThru = { [switch]::Present }
        }; DependsOn = $null }
    @{ Cmdlet = "Set-ExaCorrelationRuleState";   Category = "Exabeam"; Subcategory = "CorrelationRules";   Phase = 4; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; IsMutating = $true; Parameters = @{
            Id = '{ExaTestRule.id}'
            Enabled = { $true }
            PassThru = { [switch]::Present }
        }; DependsOn = "ExaTestRule" }
    @{ Cmdlet = "Update-ExaCorrelationRule";     Category = "Exabeam"; Subcategory = "CorrelationRules";   Phase = 4; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; IsMutating = $true; Parameters = @{
            Id = '{ExaTestRule.id}'
            Name = "[TEST-HARNESS] Lifecycle Test - Updated"
            Severity = "medium"
            SequencesConfig = { @{ sequences = @(@{ name = "test"; query = 'activity_type:"app-login"'; condition = @{ triggerOnAnyMatch = $true } }) } }
            PassThru = { [switch]::Present }
        }; DependsOn = "ExaTestRule" }
    @{ Cmdlet = "Remove-ExaCorrelationRule";     Category = "Exabeam"; Subcategory = "CorrelationRules";   Phase = 4; IsSlow = $false; IsDiscovery = $false; DiscoveryKey = $null; IdProperty = $null; IsMutating = $true; Parameters = @{
            Id = '{ExaTestRule.id}'
            PassThru = { [switch]::Present }
            Confirm = { $false }
        }; DependsOn = "ExaTestRule" }
)

# ============================================================================
# Filter Tests
# ============================================================================

$FilteredTests = $AllTests | Where-Object {
    $Include = $true
    $IsExabeam = $_.Category -eq "Exabeam"

    # Platform filter
    if ($IsExabeam -and -not $RunExa) { $Include = $false }
    if (-not $IsExabeam -and -not $RunLr) { $Include = $false }

    # Category filter (only applies to LogRhythm tests)
    if (-not $IsExabeam -and $Category -ne "All" -and $_.Category -ne $Category) { $Include = $false }

    # Slow/mutating filters
    if ($SkipSlow -and $_.IsSlow) { $Include = $false }
    if ($_.Phase -eq 4 -and -not $IncludeMutating) { $Include = $false }

    $Include
}

if ($FilteredTests.Count -eq 0) {
    Write-Host "No tests match the specified filters." -ForegroundColor Red
    exit 1
}

# ============================================================================
# Module Load
# ============================================================================

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host " SIEM.Tools Live API Test Harness" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# Load module
try {
    if (Get-Module -Name "LogRhythm.Tools" -ErrorAction SilentlyContinue) {
        Remove-Module -Name "LogRhythm.Tools" -Force -ErrorAction SilentlyContinue
    }
    Import-Module $Psm1Path -Force -ErrorAction Stop -WarningAction SilentlyContinue
    $Module = Get-Module -Name "LogRhythm.Tools"
    Write-Host "[Setup] Module loaded: LogRhythm.Tools v$($Module.Version)" -ForegroundColor White
} catch {
    Write-Host "[Setup] FATAL: Failed to load module - $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Check platform configs
$HasLrConfig = $false
$HasExaConfig = $false

try {
    if ($LrtConfig.LogRhythm.BaseUrl -and $LrtConfig.LogRhythm.BaseUrl -notlike "*NOT_SET*") {
        $HasLrConfig = $true
        if ($RunLr) { Write-Host "[Setup] LogRhythm API: $($LrtConfig.LogRhythm.BaseUrl)" -ForegroundColor White }
    }
} catch { }

try {
    if ($LrtConfig.Exabeam.BaseUrl -and $LrtConfig.Exabeam.BaseUrl -notlike "*NOT_SET*") {
        $HasExaConfig = $true
        if ($RunExa) { Write-Host "[Setup] Exabeam API:   $($LrtConfig.Exabeam.BaseUrl)" -ForegroundColor White }
    }
} catch { }

if ($RunExa -and -not $HasExaConfig) {
    Write-Host "[Setup] FATAL: Exabeam API not configured (BaseUrl = NOT_SET)" -ForegroundColor Red
    exit 1
}
if ($RunLr -and -not $HasLrConfig) {
    Write-Host "[Setup] FATAL: LogRhythm API not configured (BaseUrl = NOT_SET)" -ForegroundColor Red
    exit 1
}

$PlatformLabel = if ($Platform -eq "Both") { "LogRhythm + Exabeam" } else { $Platform }
$CategoryLabel = if ($RunLr -and $Category -ne "All") { " ($Category)" } else { "" }
Write-Host "[Setup] Tests to run: $($FilteredTests.Count) (Platform: $PlatformLabel$CategoryLabel, SkipSlow: $SkipSlow)" -ForegroundColor White
Write-Host ""

# ============================================================================
# Execute Tests by Phase
# ============================================================================

foreach ($Phase in @(1, 2, 3, 4)) {
    $PhaseTests = @($FilteredTests | Where-Object { $_.Phase -eq $Phase })
    if ($PhaseTests.Count -eq 0) { continue }

    $PhaseLabel = switch ($Phase) {
        1 { "Discovery" }
        2 { "Id-Dependent" }
        3 { "Complex Parameters" }
        4 { "Mutating Lifecycle" }
    }

    Write-Host "[Phase $Phase] $PhaseLabel ($($PhaseTests.Count) cmdlets)" -ForegroundColor Yellow

    foreach ($Test in $PhaseTests) {
        $CmdletName = $Test.Cmdlet

        # Check if command exists
        $CmdExists = Get-Command $CmdletName -ErrorAction SilentlyContinue
        if (-not $CmdExists) {
            Write-TestResult $CmdletName "SKIP" "command not found"
            $TestResults.Add([PSCustomObject]@{
                cmdlet         = $CmdletName
                category       = $Test.Category
                subcategory    = $Test.Subcategory
                service        = if ($Test.Category -eq "Exabeam") { "exa-api" } else { "lr-admin-api" }
                status         = "SKIP"
                httpStatusCode = $null
                elapsedMs      = 0
                retryCount     = 0
                resultCount    = 0
                errorDetail    = "Command not found in module"
                timestamp      = (Get-Date -Format "o")
                parameters     = @{}
                notes          = $Test.Notes
            })
            continue
        }

        # Run the test
        $Result = Invoke-LiveTest -TestDef $Test

        # Display
        $DisplayName = $CmdletName
        if ($Result.ParamDisplay) { $DisplayName += $Result.ParamDisplay }
        Write-TestResult $DisplayName $Result.Status $Result.Detail $Result.ElapsedMs $Result.ResultCount

        # Collect
        $ParamSnapshot = @{}
        if ($Test.Parameters) {
            foreach ($Key in $Test.Parameters.Keys) {
                $Val = $Test.Parameters[$Key]
                if ($Val -is [scriptblock]) {
                    $ParamSnapshot[$Key] = "(scriptblock)"
                } else {
                    $ParamSnapshot[$Key] = "$Val"
                }
            }
        }

        $TestResults.Add([PSCustomObject]@{
            cmdlet         = $CmdletName
            category       = $Test.Category
            subcategory    = $Test.Subcategory
            service        = if ($Test.Category -eq "Exabeam") { "exa-api" } else { "lr-admin-api" }
            status         = $Result.Status
            httpStatusCode = $Result.HttpCode
            elapsedMs      = $Result.ElapsedMs
            retryCount     = $Result.RetryCount
            resultCount    = $Result.ResultCount
            errorDetail    = $Result.ErrorDetail
            timestamp      = (Get-Date -Format "o")
            parameters     = $ParamSnapshot
            notes          = $Test.Notes
        })
    }

    Write-Host ""
}

# ============================================================================
# Compute Timing Metrics
# ============================================================================

$RunEnd = Get-Date
$PassedResults = @($TestResults | Where-Object { $_.status -eq "PASS" -or $_.status -eq "WARN" })
$TimedResults = @($PassedResults | Where-Object { $_.elapsedMs -gt 0 })

$TimingMetrics = @{
    avgResponseMs    = 0
    medianResponseMs = 0
    p95ResponseMs    = 0
    fastestCmdlet    = $null
    fastestMs        = 0
    slowestCmdlet    = $null
    slowestMs        = 0
    totalRetries     = 0
    retriedCmdlets   = @()
}

if ($TimedResults.Count -gt 0) {
    $SortedMs = @($TimedResults | Sort-Object elapsedMs)
    $AllMs = @($SortedMs | ForEach-Object { $_.elapsedMs })

    $TimingMetrics.avgResponseMs = [int]($AllMs | Measure-Object -Average).Average
    $MedianIdx = [math]::Floor($AllMs.Count / 2)
    $TimingMetrics.medianResponseMs = $AllMs[$MedianIdx]

    $P95Idx = [math]::Floor($AllMs.Count * 0.95)
    if ($P95Idx -ge $AllMs.Count) { $P95Idx = $AllMs.Count - 1 }
    $TimingMetrics.p95ResponseMs = $AllMs[$P95Idx]

    $TimingMetrics.fastestCmdlet = $SortedMs[0].cmdlet
    $TimingMetrics.fastestMs = $SortedMs[0].elapsedMs
    $TimingMetrics.slowestCmdlet = $SortedMs[-1].cmdlet
    $TimingMetrics.slowestMs = $SortedMs[-1].elapsedMs

    $Retried = @($TestResults | Where-Object { $_.retryCount -gt 0 })
    $TimingMetrics.totalRetries = ($Retried | Measure-Object -Property retryCount -Sum).Sum
    if ($null -eq $TimingMetrics.totalRetries) { $TimingMetrics.totalRetries = 0 }
    $TimingMetrics.retriedCmdlets = @($Retried | ForEach-Object { $_.cmdlet })
}

# ============================================================================
# Write JSON Results
# ============================================================================

$Timestamp = (Get-Date -Format "yyyy-MM-ddTHHmm")
$PlatformTag = $Platform.ToLower()
$CategoryTag = if ($RunLr -and $Category -ne "All") { "_$($Category.ToLower())" } else { "" }
$ResultFileName = "${Timestamp}_${PlatformTag}${CategoryTag}.json"
$ResultFilePath = Join-Path $ResultsDir $ResultFileName

$OutputObject = [ordered]@{
    metadata = [ordered]@{
        runId          = $RunId
        startTime      = $RunStart.ToString("o")
        endTime        = $RunEnd.ToString("o")
        durationSec    = [int]($RunEnd - $RunStart).TotalSeconds
        moduleVersion  = "$($Module.Version)"
        platform       = $Platform
        lrBaseUrl      = if ($RunLr) { "$($LrtConfig.LogRhythm.BaseUrl)" } else { $null }
        exaBaseUrl     = if ($RunExa) { "$($LrtConfig.Exabeam.BaseUrl)" } else { $null }
        category       = $Category
        skipSlow       = [bool]$SkipSlow
        totalTests     = $TestResults.Count
        passed         = @($TestResults | Where-Object { $_.status -eq "PASS" }).Count
        failed         = @($TestResults | Where-Object { $_.status -eq "FAIL" }).Count
        skipped        = @($TestResults | Where-Object { $_.status -eq "SKIP" }).Count
        warned         = @($TestResults | Where-Object { $_.status -eq "WARN" }).Count
        timingMetrics  = $TimingMetrics
    }
    results = @($TestResults)
}

$OutputObject | ConvertTo-Json -Depth 10 | Out-File -FilePath $ResultFilePath -Encoding UTF8

# ============================================================================
# Console Summary
# ============================================================================

Write-Host "================================================================" -ForegroundColor Cyan
$SummaryLine = "  Total: $TotalPass passed, $TotalFail failed, $TotalSkip skipped, $TotalWarn warned"
Write-Host $SummaryLine -ForegroundColor $(if ($TotalFail -gt 0) { "Red" } else { "Green" })

if ($TimedResults.Count -gt 0) {
    $MetricsLine = "  Avg: $($TimingMetrics.avgResponseMs)ms | Median: $($TimingMetrics.medianResponseMs)ms | P95: $($TimingMetrics.p95ResponseMs)ms"
    Write-Host $MetricsLine -ForegroundColor White
    $RangeLine = "  Fastest: $($TimingMetrics.fastestMs)ms ($($TimingMetrics.fastestCmdlet)) | Slowest: $($TimingMetrics.slowestMs)ms ($($TimingMetrics.slowestCmdlet))"
    Write-Host $RangeLine -ForegroundColor White
    if ($TimingMetrics.totalRetries -gt 0) {
        Write-Host "  Retries: $($TimingMetrics.totalRetries) ($($TimingMetrics.retriedCmdlets -join ', '))" -ForegroundColor Yellow
    }
}

Write-Host "  Saved: $ResultFilePath" -ForegroundColor White
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# Exit code
if ($TotalFail -gt 0) { exit 1 } else { exit 0 }
