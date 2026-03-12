<#
.SYNOPSIS
    Enrich a LogRhythm case with threat intelligence from VirusTotal and Shodan.
.DESCRIPTION
    Invoke-CaseThreatIntelEnrichment extracts indicators of compromise (IOCs)
    from case evidence notes, queries VirusTotal and Shodan for context, and
    adds enrichment results back to the case as notes with updated tags.

    Supports extraction of IPv4 addresses, MD5/SHA1/SHA256 hashes, and domain
    names from evidence text. Gracefully skips services that are not configured.
.PARAMETER CaseId
    The case number or GUID to enrich.
.PARAMETER VtDetectionThreshold
    Number of VirusTotal detections that triggers a "high-risk" tag. Default is 5.
.EXAMPLE
    PS C:\> .\Invoke-CaseThreatIntelEnrichment.ps1 -CaseId 1842

    Extracts IOCs from case 1842 evidence and enriches with available threat intel.
.EXAMPLE
    PS C:\> .\Invoke-CaseThreatIntelEnrichment.ps1 -CaseId 1842 -VtDetectionThreshold 3

    Uses a lower detection threshold for tagging high-risk indicators.
.LINK
    https://github.com/LogRhythm-Tools/LogRhythm.Tools
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true, Position = 0)]
    [object] $CaseId,

    [Parameter(Mandatory = $false, Position = 1)]
    [ValidateRange(1, 100)]
    [int] $VtDetectionThreshold = 5
)

# --- Check available integrations ---
$VtAvailable = $false
$ShodanAvailable = $false

if ($LrtConfig.VirusTotal -and $LrtConfig.VirusTotal.VtApiToken) {
    $VtAvailable = $true
    Write-Host "[Config] VirusTotal API: Available" -ForegroundColor Green
} else {
    Write-Host "[Config] VirusTotal API: Not configured - hash/domain lookups will be skipped" -ForegroundColor Yellow
}

if ($LrtConfig.Shodan -and $LrtConfig.Shodan.ApiKey) {
    $ShodanAvailable = $true
    Write-Host "[Config] Shodan API: Available" -ForegroundColor Green
} else {
    Write-Host "[Config] Shodan API: Not configured - IP lookups will be skipped" -ForegroundColor Yellow
}

if (-not $VtAvailable -and -not $ShodanAvailable) {
    Write-Host "WARNING: No threat intel APIs configured. Configure VirusTotal or Shodan to use this script." -ForegroundColor Yellow
    return
}

# --- Step 1: Retrieve case evidence ---
Write-Host ""
Write-Host "[1/4] Retrieving case evidence for Case: $CaseId" -ForegroundColor Cyan
try {
    $Evidence = Get-LrCaseEvidence -Id $CaseId
} catch {
    Write-Host "ERROR: Failed to retrieve case evidence. $_" -ForegroundColor Red
    return
}

if (-not $Evidence) {
    Write-Host "WARNING: No evidence found for case $CaseId." -ForegroundColor Yellow
    return
}

$EvidenceNotes = @($Evidence | Where-Object { $_.type -eq "note" })
Write-Host "  Evidence items retrieved: $(@($Evidence).Count)" -ForegroundColor White
Write-Host "  Notes to analyze: $($EvidenceNotes.Count)" -ForegroundColor White

# --- Step 2: Extract IOCs from evidence text ---
Write-Host "[2/4] Extracting IOCs from evidence..." -ForegroundColor Cyan

$AllText = ($EvidenceNotes | ForEach-Object { $_.text }) -join "`n"

# IPv4 addresses (exclude RFC1918 and loopback)
$IpPattern = '\b(?:(?:25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)\.){3}(?:25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)\b'
$RawIPs = [regex]::Matches($AllText, $IpPattern) |
    ForEach-Object { $_.Value } |
    Sort-Object -Unique
$PublicIPs = $RawIPs | Where-Object {
    $_ -notmatch '^(10\.|172\.(1[6-9]|2\d|3[01])\.|192\.168\.|127\.)'
}

# File hashes (MD5, SHA1, SHA256)
$Md5Pattern = '\b[a-fA-F0-9]{32}\b'
$Sha1Pattern = '\b[a-fA-F0-9]{40}\b'
$Sha256Pattern = '\b[a-fA-F0-9]{64}\b'

$Hashes = [System.Collections.Generic.List[string]]::new()
[regex]::Matches($AllText, $Sha256Pattern) |
    ForEach-Object { $Hashes.Add($_.Value) }
[regex]::Matches($AllText, $Sha1Pattern) |
    Where-Object { $_.Value.Length -eq 40 } |
    ForEach-Object { $Hashes.Add($_.Value) }
[regex]::Matches($AllText, $Md5Pattern) |
    Where-Object { $_.Value.Length -eq 32 } |
    ForEach-Object { $Hashes.Add($_.Value) }
$Hashes = $Hashes | Sort-Object -Unique

# Domains (basic extraction, exclude common false positives)
$DomainPattern = '\b(?:[a-zA-Z0-9](?:[a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+(?:com|net|org|io|info|biz|co|ru|cn|de|uk|xyz|top|cc|pw|tk)\b'
$Domains = [regex]::Matches($AllText, $DomainPattern) |
    ForEach-Object { $_.Value.ToLower() } |
    Where-Object { $_ -notmatch '(microsoft\.com|windows\.com|logrhythm\.com)$' } |
    Sort-Object -Unique

Write-Host "  Public IPs found : $(@($PublicIPs).Count)" -ForegroundColor White
Write-Host "  Hashes found     : $($Hashes.Count)" -ForegroundColor White
Write-Host "  Domains found    : $(@($Domains).Count)" -ForegroundColor White

if (@($PublicIPs).Count -eq 0 -and $Hashes.Count -eq 0 -and @($Domains).Count -eq 0) {
    Write-Host "No IOCs extracted from evidence. Nothing to enrich." -ForegroundColor Yellow
    return
}

# --- Step 3: Enrich IOCs ---
Write-Host "[3/4] Enriching IOCs with threat intelligence..." -ForegroundColor Cyan

$EnrichmentLines = [System.Collections.Generic.List[string]]::new()
$EnrichmentLines.Add("=== Threat Intelligence Enrichment Report ===")
$EnrichmentLines.Add("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC' -AsUTC)")
$EnrichmentLines.Add("")

$HighRiskDetected = $false

# Enrich IPs with Shodan
if ($ShodanAvailable -and @($PublicIPs).Count -gt 0) {
    $EnrichmentLines.Add("--- IP Address Enrichment (Shodan) ---")
    foreach ($Ip in $PublicIPs) {
        Write-Host "  Querying Shodan for $Ip..." -ForegroundColor Gray
        try {
            $ShodanResult = Get-ShodanHostIp -IPAddress $Ip
            if ($ShodanResult) {
                $OpenPorts = @()
                if ($ShodanResult.data) {
                    $OpenPorts = @($ShodanResult.data | ForEach-Object { $_.port }) |
                        Sort-Object -Unique
                }
                $EnrichmentLines.Add("IP: $Ip")
                $EnrichmentLines.Add("  Organization: $($ShodanResult.org)")
                $EnrichmentLines.Add("  Country: $($ShodanResult.country_code)")
                $EnrichmentLines.Add("  Hostnames: $(($ShodanResult.hostnames | Select-Object -First 3) -join ', ')")
                $EnrichmentLines.Add("  Open Ports: $($OpenPorts -join ', ')")
                $EnrichmentLines.Add("  Tags: $(($ShodanResult.tags) -join ', ')")
                $EnrichmentLines.Add("")
            }
        } catch {
            $EnrichmentLines.Add("IP: $Ip - Lookup failed: $_")
            $EnrichmentLines.Add("")
        }
        # Rate limit courtesy delay
        Start-Sleep -Milliseconds 500
    }
}

# Enrich hashes with VirusTotal
if ($VtAvailable -and $Hashes.Count -gt 0) {
    $EnrichmentLines.Add("--- Hash Enrichment (VirusTotal) ---")
    foreach ($Hash in $Hashes) {
        Write-Host "  Querying VirusTotal for $($Hash.Substring(0,12))..." -ForegroundColor Gray
        try {
            $VtResult = Get-VTHashReport -Hash $Hash
            if ($VtResult -and $VtResult.response_code -eq 1) {
                $Detections = $VtResult.positives
                $Total = $VtResult.total
                $ScanDate = $VtResult.scan_date
                $EnrichmentLines.Add("Hash: $Hash")
                $EnrichmentLines.Add("  Detections: $Detections / $Total")
                $EnrichmentLines.Add("  Scan Date: $ScanDate")
                $EnrichmentLines.Add("  Permalink: $($VtResult.permalink)")
                if ($Detections -ge $VtDetectionThreshold) {
                    $EnrichmentLines.Add("  ** HIGH RISK - Exceeds detection threshold **")
                    $HighRiskDetected = $true
                }
                $EnrichmentLines.Add("")
            } else {
                $EnrichmentLines.Add("Hash: $Hash - Not found in VirusTotal")
                $EnrichmentLines.Add("")
            }
        } catch {
            $EnrichmentLines.Add("Hash: $Hash - Lookup failed: $_")
            $EnrichmentLines.Add("")
        }
        # VT API rate limit (4 requests/min on free tier)
        Start-Sleep -Seconds 16
    }
}

# Enrich domains with VirusTotal
if ($VtAvailable -and @($Domains).Count -gt 0) {
    $EnrichmentLines.Add("--- Domain Enrichment (VirusTotal) ---")
    foreach ($Domain in $Domains) {
        Write-Host "  Querying VirusTotal for $Domain..." -ForegroundColor Gray
        try {
            $VtDomainResult = Get-VTDomainReport -Domain $Domain
            if ($VtDomainResult) {
                $DetectedUrls = @()
                if ($VtDomainResult.detected_urls) {
                    $DetectedUrls = @($VtDomainResult.detected_urls)
                }
                $MaxPositives = 0
                if ($DetectedUrls.Count -gt 0) {
                    $MaxPositives = ($DetectedUrls |
                        Measure-Object -Property positives -Maximum).Maximum
                }
                $EnrichmentLines.Add("Domain: $Domain")
                $EnrichmentLines.Add("  Detected URLs: $($DetectedUrls.Count)")
                $EnrichmentLines.Add("  Max Detections: $MaxPositives")
                if ($MaxPositives -ge $VtDetectionThreshold) {
                    $EnrichmentLines.Add("  ** HIGH RISK - Exceeds detection threshold **")
                    $HighRiskDetected = $true
                }
                $EnrichmentLines.Add("")
            }
        } catch {
            $EnrichmentLines.Add("Domain: $Domain - Lookup failed: $_")
            $EnrichmentLines.Add("")
        }
        Start-Sleep -Seconds 16
    }
}

# --- Step 4: Update the case ---
Write-Host "[4/4] Updating case with enrichment results..." -ForegroundColor Cyan

$EnrichmentText = $EnrichmentLines -join "`n"
try {
    Add-LrNoteToCase -Id $CaseId -Text $EnrichmentText -PassThru | Out-Null
    Write-Host "  Enrichment note added to case." -ForegroundColor Green
} catch {
    Write-Host "ERROR: Failed to add enrichment note. $_" -ForegroundColor Red
}

# Apply risk-based tags
$TagsToApply = [System.Collections.Generic.List[string]]::new()
$TagsToApply.Add("TI-Enriched")

if ($HighRiskDetected) {
    $TagsToApply.Add("High-Risk")
    Write-Host "  High-risk indicators detected!" -ForegroundColor Red
}

try {
    Add-LrCaseTags -Id $CaseId -Tags $TagsToApply -Force -PassThru | Out-Null
    Write-Host "  Tags applied: $($TagsToApply -join ', ')" -ForegroundColor Green
} catch {
    Write-Host "WARNING: Failed to apply tags. $_" -ForegroundColor Yellow
}

# --- Summary ---
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Enrichment Complete" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Case          : $CaseId" -ForegroundColor White
Write-Host "  IPs Checked   : $(@($PublicIPs).Count)" -ForegroundColor White
Write-Host "  Hashes Checked: $($Hashes.Count)" -ForegroundColor White
Write-Host "  Domains Checked: $(@($Domains).Count)" -ForegroundColor White
Write-Host "  High Risk     : $HighRiskDetected" -ForegroundColor $(if ($HighRiskDetected) { "Red" } else { "White" })
Write-Host "  Tags Applied  : $($TagsToApply -join ', ')" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Green
