<#
.SYNOPSIS
    Synchronize external threat feeds into LogRhythm lists and report statistics.
.DESCRIPTION
    Invoke-ListMaintenanceSync performs scheduled threat list hygiene by syncing
    external threat intelligence sources (URL-based or file-based) into LogRhythm
    lists. It calculates diffs, applies changes via Sync-LrListItems, and produces
    a summary report of additions, removals, and unchanged entries.

    Designed to run as a scheduled task for automated list maintenance.
.PARAMETER FeedConfig
    Hashtable mapping LogRhythm list names to source definitions. Each source
    definition is a hashtable with keys: Type (Url or File), Path (URL or file
    path), and optionally ItemType (IP, Domain, etc.).
.PARAMETER ReportPath
    Optional file path to export the sync report as CSV.
.PARAMETER Credential
    PSCredential containing an API Token. Defaults to $LrtConfig.LogRhythm.ApiKey.
.EXAMPLE
    PS C:\> .\Invoke-ListMaintenanceSync.ps1

    Syncs all feeds defined in the default configuration and displays a summary.
.EXAMPLE
    PS C:\> .\Invoke-ListMaintenanceSync.ps1 -ReportPath "C:\Reports\list-sync.csv"

    Syncs all feeds and exports the report to CSV.
.EXAMPLE
    PS C:\> $Feeds = @{
        "LRT: Blocked IPs" = @{ Type = "Url"; Path = "https://feeds.example.com/bad-ips.txt" }
        "LRT: Allowed Domains" = @{ Type = "File"; Path = "C:\Feeds\allowed-domains.txt" }
    }
    .\Invoke-ListMaintenanceSync.ps1 -FeedConfig $Feeds -ReportPath "C:\Reports\sync.csv"
.LINK
    https://github.com/LogRhythm-Tools/LogRhythm.Tools
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $false, Position = 0)]
    [hashtable] $FeedConfig,

    [Parameter(Mandatory = $false, Position = 1)]
    [string] $ReportPath,

    [Parameter(Mandatory = $false, Position = 2)]
    [ValidateNotNull()]
    [pscredential] $Credential = $LrtConfig.LogRhythm.ApiKey
)

# Default feed configuration — customize for your environment
if (-not $FeedConfig) {
    $FeedConfig = @{
        "LRT: Threat IPs" = @{
            Type     = "Url"
            Path     = "https://rules.emergingthreats.net/blockrules/compromised-ips.txt"
            ItemType = "IP"
        }
        "LRT: Abuse.ch Botnet IPs" = @{
            Type     = "Url"
            Path     = "https://feodotracker.abuse.ch/downloads/ipblocklist.txt"
            ItemType = "IP"
        }
        "LRT: Allowed Domains" = @{
            Type     = "File"
            Path     = "C:\LogRhythm\Feeds\allowed-domains.txt"
            ItemType = "Domain"
        }
    }
}

$SyncResults = [System.Collections.Generic.List[PSCustomObject]]::new()
$StartTime = Get-Date

foreach ($ListName in $FeedConfig.Keys) {
    $Source = $FeedConfig[$ListName]
    Write-Host "Processing list: $ListName"
    Write-Verbose "  Source type: $($Source.Type) | Path: $($Source.Path)"

    # Load items from source
    try {
        if ($Source.Type -eq "Url") {
            Write-Verbose "  Downloading from URL: $($Source.Path)"
            $RawContent = (Invoke-WebRequest -Uri $Source.Path -UseBasicParsing).Content
            $NewItems = $RawContent -split "`n" |
                ForEach-Object { $_.Trim() } |
                Where-Object { $_ -and $_ -notmatch '^\s*#' }
        } elseif ($Source.Type -eq "File") {
            if (-not (Test-Path -Path $Source.Path)) {
                Write-Host "  WARNING: File not found: $($Source.Path) - skipping." -ForegroundColor Yellow
                continue
            }
            Write-Verbose "  Reading from file: $($Source.Path)"
            $NewItems = Get-Content -Path $Source.Path |
                ForEach-Object { $_.Trim() } |
                Where-Object { $_ -and $_ -notmatch '^\s*#' }
        } else {
            Write-Host "  WARNING: Unknown source type '$($Source.Type)' - skipping." -ForegroundColor Yellow
            continue
        }
    } catch {
        Write-Host "  ERROR: Failed to load source for '$ListName': $_" -ForegroundColor Red
        $SyncResults.Add([PSCustomObject]@{
            ListName  = $ListName
            Source    = $Source.Path
            Status    = "Error"
            Before    = 0
            After     = 0
            Added     = 0
            Removed   = 0
            Message   = $_.Exception.Message
        })
        continue
    }

    # Get current list item count for reporting
    $ExistingItems = Get-LrListItems -Name $ListName -Credential $Credential
    $BeforeCount = if ($ExistingItems) { @($ExistingItems).Count } else { 0 }

    # Sync items to the list
    Write-Verbose "  Syncing $(@($NewItems).Count) items to '$ListName' (was $BeforeCount)"
    try {
        $SyncResult = Sync-LrListItems -Name $ListName -Value $NewItems -PassThru -Credential $Credential
        $SyncResults.Add([PSCustomObject]@{
            ListName  = $ListName
            Source    = $Source.Path
            Status    = "Success"
            Before    = $SyncResult.Before
            After     = $SyncResult.After
            Added     = $SyncResult.Added
            Removed   = $SyncResult.Removed
            Message   = ""
        })
        Write-Host "  Synced: Before=$($SyncResult.Before) After=$($SyncResult.After) Added=$($SyncResult.Added) Removed=$($SyncResult.Removed)" -ForegroundColor Green
    } catch {
        Write-Host "  ERROR: Sync failed for '$ListName': $_" -ForegroundColor Red
        $SyncResults.Add([PSCustomObject]@{
            ListName  = $ListName
            Source    = $Source.Path
            Status    = "Error"
            Before    = $BeforeCount
            After     = 0
            Added     = 0
            Removed   = 0
            Message   = $_.Exception.Message
        })
    }
}

$Duration = (Get-Date) - $StartTime

# Summary report
Write-Host "`n========== List Maintenance Sync Report ==========" -ForegroundColor Cyan
Write-Host "Run Time:    $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "Duration:    $($Duration.TotalSeconds.ToString('F1')) seconds"
Write-Host "Lists:       $($SyncResults.Count)"
Write-Host "Successful:  $(($SyncResults | Where-Object { $_.Status -eq 'Success' }).Count)"
Write-Host "Errors:      $(($SyncResults | Where-Object { $_.Status -eq 'Error' }).Count)"
Write-Host "Total Added: $(($SyncResults | Measure-Object -Property Added -Sum).Sum)"
Write-Host "Total Removed: $(($SyncResults | Measure-Object -Property Removed -Sum).Sum)"
Write-Host "==================================================" -ForegroundColor Cyan

$SyncResults | Format-Table -AutoSize

# Export report if path provided
if ($ReportPath) {
    $SyncResults | Export-Csv -Path $ReportPath -NoTypeInformation
    Write-Host "Report exported to: $ReportPath" -ForegroundColor Green
}

$SyncResults
