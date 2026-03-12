<#
.SYNOPSIS
    Generate a daily SOC metrics report from LogRhythm case and alarm data.
.DESCRIPTION
    Get-DailySOCMetrics produces a daily operations dashboard for SOC managers,
    including case volume by priority and status, alarm counts, mean time to
    mitigate (MTTM), and optionally log volume statistics.

    Outputs a formatted console report and optionally saves an HTML report.
.PARAMETER Date
    The date to report on. Defaults to yesterday. The report covers the full
    24-hour period from midnight to midnight of the specified date.
.PARAMETER OutputPath
    Optional file path to save the report as an HTML file.
.PARAMETER Credential
    PSCredential containing an API Token. Defaults to $LrtConfig.LogRhythm.ApiKey.
.EXAMPLE
    PS C:\> .\Get-DailySOCMetrics.ps1

    Generates a metrics report for yesterday and displays it in the console.
.EXAMPLE
    PS C:\> .\Get-DailySOCMetrics.ps1 -Date "2026-03-10" -OutputPath "C:\Reports\soc-daily.html"

    Generates a report for March 10 and saves it as HTML.
.LINK
    https://github.com/LogRhythm-Tools/LogRhythm.Tools
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $false, Position = 0)]
    [datetime] $Date = (Get-Date).AddDays(-1).Date,

    [Parameter(Mandatory = $false, Position = 1)]
    [string] $OutputPath,

    [Parameter(Mandatory = $false, Position = 2)]
    [ValidateNotNull()]
    [pscredential] $Credential = $LrtConfig.LogRhythm.ApiKey
)

$ReportDate = $Date.Date
$PeriodStart = $ReportDate
$PeriodEnd = $ReportDate.AddDays(1)

Write-Host "Generating SOC metrics for: $($ReportDate.ToString('yyyy-MM-dd'))" -ForegroundColor Cyan

# Retrieve cases updated during the reporting period
Write-Host "Retrieving cases..."
$UpdatedCases = Get-LrCases -UpdatedAfter $PeriodStart -UpdatedBefore $PeriodEnd -Count 500 -Credential $Credential
$AllUpdated = if ($UpdatedCases) { @($UpdatedCases) } else { @() }

# Cases created during the period
$CreatedCases = $AllUpdated | Where-Object {
    $Created = [datetime]$_.dateCreated
    $Created -ge $PeriodStart -and $Created -lt $PeriodEnd
}
$NewCaseCount = @($CreatedCases).Count

# Cases closed/resolved during the period (status 4 = Resolved, 5 = Completed)
$ClosedCases = $AllUpdated | Where-Object {
    $_.status.number -ge 4 -and $_.dateClosed -and
    ([datetime]$_.dateClosed) -ge $PeriodStart -and
    ([datetime]$_.dateClosed) -lt $PeriodEnd
}
$ClosedCaseCount = @($ClosedCases).Count

# Cases by priority
$PriorityNames = @{ 1 = "Critical"; 2 = "High"; 3 = "Medium"; 4 = "Low"; 5 = "Informational" }
$ByPriority = @{}
foreach ($P in 1..5) {
    $ByPriority[$P] = @($AllUpdated | Where-Object { $_.priority -eq $P }).Count
}

# Cases by status
$StatusNames = @{ 1 = "Created"; 2 = "Completed"; 3 = "Incident"; 4 = "Mitigated"; 5 = "Resolved" }
$ByStatus = @{}
foreach ($S in $StatusNames.Keys) {
    $ByStatus[$S] = @($AllUpdated | Where-Object { $_.status.number -eq $S }).Count
}

# Mean Time to Mitigate (MTTM) for cases mitigated today
$MitigatedCases = $AllUpdated | Where-Object { $_.status.number -ge 4 }
$MttmValues = [System.Collections.Generic.List[double]]::new()

foreach ($MCase in $MitigatedCases) {
    try {
        $Metrics = Get-LrCaseMetrics -Id $MCase.number -Credential $Credential
        if ($Metrics.created -and $Metrics.mitigated) {
            $CreatedTime = [datetime]$Metrics.created
            $MitigatedTime = [datetime]$Metrics.mitigated
            $DiffHours = ($MitigatedTime - $CreatedTime).TotalHours
            if ($DiffHours -gt 0) {
                $MttmValues.Add($DiffHours)
            }
        }
    } catch {
        Write-Verbose "Could not retrieve metrics for case $($MCase.number): $_"
    }
}

$AvgMttm = if ($MttmValues.Count -gt 0) {
    ($MttmValues | Measure-Object -Average).Average
} else { 0 }

# Retrieve alarms for the period
Write-Host "Retrieving alarms..."
$Alarms = $null
try {
    $Alarms = Get-LrAlarms -Credential $Credential
} catch {
    Write-Verbose "Could not retrieve alarms: $_"
}
$AlarmCount = if ($Alarms) { @($Alarms).Count } else { "N/A" }

# Build the report
$ReportLines = [System.Collections.Generic.List[string]]::new()
$Separator = "=" * 55

$ReportLines.Add($Separator)
$ReportLines.Add("  SOC DAILY METRICS REPORT")
$ReportLines.Add("  Date: $($ReportDate.ToString('yyyy-MM-dd'))")
$ReportLines.Add("  Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
$ReportLines.Add($Separator)
$ReportLines.Add("")
$ReportLines.Add("  CASE SUMMARY")
$ReportLines.Add("  " + ("-" * 40))
$ReportLines.Add("  Cases updated today:       $($AllUpdated.Count)")
$ReportLines.Add("  New cases created:         $NewCaseCount")
$ReportLines.Add("  Cases closed/resolved:     $ClosedCaseCount")
$ReportLines.Add("")
$ReportLines.Add("  CASES BY PRIORITY")
$ReportLines.Add("  " + ("-" * 40))
foreach ($P in 1..5) {
    $ReportLines.Add("  P$P ($($PriorityNames[$P])): $(' ' * (15 - $PriorityNames[$P].Length))$($ByPriority[$P])")
}
$ReportLines.Add("")
$ReportLines.Add("  CASES BY STATUS")
$ReportLines.Add("  " + ("-" * 40))
foreach ($S in ($StatusNames.Keys | Sort-Object)) {
    $ReportLines.Add("  $($StatusNames[$S]): $(' ' * (15 - $StatusNames[$S].Length))$($ByStatus[$S])")
}
$ReportLines.Add("")
$ReportLines.Add("  PERFORMANCE METRICS")
$ReportLines.Add("  " + ("-" * 40))
$MttmDisplay = if ($MttmValues.Count -gt 0) { "$($AvgMttm.ToString('F1')) hours (n=$($MttmValues.Count))" } else { "No data" }
$ReportLines.Add("  Mean Time to Mitigate:     $MttmDisplay")
$ReportLines.Add("  Alarm count (period):      $AlarmCount")
$ReportLines.Add("")
$ReportLines.Add($Separator)

# Display console report
foreach ($Line in $ReportLines) {
    Write-Host $Line
}

# Export HTML report if requested
if ($OutputPath) {
    $HtmlBody = "<html><head><style>"
    $HtmlBody += "body { font-family: Consolas, monospace; margin: 20px; background: #1a1a2e; color: #e0e0e0; }"
    $HtmlBody += "h1 { color: #00d4ff; } h2 { color: #0099cc; border-bottom: 1px solid #333; padding-bottom: 5px; }"
    $HtmlBody += "table { border-collapse: collapse; margin: 10px 0; } td, th { padding: 6px 16px; border: 1px solid #333; }"
    $HtmlBody += "th { background: #0099cc; color: white; } .metric { font-size: 1.4em; font-weight: bold; color: #00d4ff; }"
    $HtmlBody += "</style></head><body>"
    $HtmlBody += "<h1>SOC Daily Metrics Report</h1>"
    $HtmlBody += "<p>Date: $($ReportDate.ToString('yyyy-MM-dd')) | Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>"

    $HtmlBody += "<h2>Case Summary</h2><table>"
    $HtmlBody += "<tr><td>Cases updated</td><td class='metric'>$($AllUpdated.Count)</td></tr>"
    $HtmlBody += "<tr><td>New cases</td><td class='metric'>$NewCaseCount</td></tr>"
    $HtmlBody += "<tr><td>Closed/resolved</td><td class='metric'>$ClosedCaseCount</td></tr>"
    $HtmlBody += "</table>"

    $HtmlBody += "<h2>By Priority</h2><table><tr><th>Priority</th><th>Count</th></tr>"
    foreach ($P in 1..5) {
        $HtmlBody += "<tr><td>P$P - $($PriorityNames[$P])</td><td>$($ByPriority[$P])</td></tr>"
    }
    $HtmlBody += "</table>"

    $HtmlBody += "<h2>By Status</h2><table><tr><th>Status</th><th>Count</th></tr>"
    foreach ($S in ($StatusNames.Keys | Sort-Object)) {
        $HtmlBody += "<tr><td>$($StatusNames[$S])</td><td>$($ByStatus[$S])</td></tr>"
    }
    $HtmlBody += "</table>"

    $HtmlBody += "<h2>Performance</h2><table>"
    $HtmlBody += "<tr><td>Mean Time to Mitigate</td><td class='metric'>$MttmDisplay</td></tr>"
    $HtmlBody += "<tr><td>Alarm count</td><td class='metric'>$AlarmCount</td></tr>"
    $HtmlBody += "</table>"

    $HtmlBody += "</body></html>"

    $HtmlBody | Set-Content -Path $OutputPath -Encoding UTF8
    Write-Host "HTML report saved to: $OutputPath" -ForegroundColor Green
}
