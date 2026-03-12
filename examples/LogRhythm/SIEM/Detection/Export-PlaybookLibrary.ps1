<#
.SYNOPSIS
    Export all LogRhythm playbooks with procedures for backup or migration.
.DESCRIPTION
    Export-PlaybookLibrary retrieves all playbooks from the LogRhythm Case API,
    enriches each with its procedure steps, and exports the complete library to
    a JSON file (machine-readable for import) and a Markdown summary
    (human-readable for documentation).

    Use this for environment migrations, DR backup, or detection team reviews.
.PARAMETER OutputDirectory
    Directory where export files will be written. Defaults to current directory.
.PARAMETER NameFilter
    Optional wildcard filter to export only matching playbook names.
.PARAMETER TagFilter
    Optional tag name to filter playbooks by tag.
.PARAMETER Credential
    PSCredential containing an API Token. Defaults to $LrtConfig.LogRhythm.ApiKey.
.EXAMPLE
    PS C:\> .\Export-PlaybookLibrary.ps1 -OutputDirectory "C:\Backups\Playbooks"

    Exports all playbooks to JSON and Markdown in the specified directory.
.EXAMPLE
    PS C:\> .\Export-PlaybookLibrary.ps1 -NameFilter "*Ransomware*"

    Exports only playbooks with "Ransomware" in the name.
.LINK
    https://github.com/LogRhythm-Tools/LogRhythm.Tools
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $false, Position = 0)]
    [string] $OutputDirectory = (Get-Location).Path,

    [Parameter(Mandatory = $false, Position = 1)]
    [string] $NameFilter,

    [Parameter(Mandatory = $false, Position = 2)]
    [string] $TagFilter,

    [Parameter(Mandatory = $false, Position = 3)]
    [ValidateNotNull()]
    [pscredential] $Credential = $LrtConfig.LogRhythm.ApiKey
)

# Ensure output directory exists
if (-not (Test-Path -Path $OutputDirectory)) {
    New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null
    Write-Verbose "Created output directory: $OutputDirectory"
}

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$JsonPath = Join-Path $OutputDirectory "PlaybookLibrary_$Timestamp.json"
$MarkdownPath = Join-Path $OutputDirectory "PlaybookLibrary_$Timestamp.md"

# Retrieve all playbooks
Write-Host "Retrieving playbooks from LogRhythm..."
$Playbooks = Get-LrPlaybooks -Credential $Credential

if (-not $Playbooks) {
    Write-Host "No playbooks found." -ForegroundColor Yellow
    return
}

# Apply filters
if ($NameFilter) {
    $Playbooks = $Playbooks | Where-Object { $_.name -like $NameFilter }
    Write-Host "Filtered by name '$NameFilter': $(@($Playbooks).Count) playbooks"
}
if ($TagFilter) {
    $Playbooks = $Playbooks | Where-Object { $_.tags.text -contains $TagFilter }
    Write-Host "Filtered by tag '$TagFilter': $(@($Playbooks).Count) playbooks"
}

Write-Host "Processing $(@($Playbooks).Count) playbooks..."

$ExportLibrary = [System.Collections.Generic.List[PSCustomObject]]::new()
$MarkdownLines = [System.Collections.Generic.List[string]]::new()
$MarkdownLines.Add("# LogRhythm Playbook Library Export")
$MarkdownLines.Add("")
$MarkdownLines.Add("Exported: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
$MarkdownLines.Add("")
$MarkdownLines.Add("Total Playbooks: $(@($Playbooks).Count)")
$MarkdownLines.Add("")
$MarkdownLines.Add("---")
$MarkdownLines.Add("")

$PlaybookIndex = 0
foreach ($Playbook in $Playbooks) {
    $PlaybookIndex++
    Write-Verbose "  [$PlaybookIndex/$(@($Playbooks).Count)] $($Playbook.name)"

    # Get procedures for this playbook
    $Procedures = $null
    try {
        $Procedures = Get-LrPlaybookProcedures -Id $Playbook.id -Credential $Credential
    } catch {
        Write-Verbose "  Could not retrieve procedures for '$($Playbook.name)': $_"
    }

    # Try full export for import-ready data
    $ExportData = $null
    try {
        $ExportData = Export-LrPlaybook -Id $Playbook.id -Credential $Credential
    } catch {
        Write-Verbose "  Could not export playbook '$($Playbook.name)': $_"
    }

    # Build structured object
    $PlaybookEntry = [PSCustomObject]@{
        Id            = $Playbook.id
        Name          = $Playbook.name
        Description   = $Playbook.description
        Tags          = $Playbook.tags
        DateCreated   = $Playbook.dateCreated
        DateUpdated   = $Playbook.dateUpdated
        Procedures    = $Procedures
        ExportData    = $ExportData
    }
    $ExportLibrary.Add($PlaybookEntry)

    # Build Markdown section
    $TagList = if ($Playbook.tags) { ($Playbook.tags | ForEach-Object { $_.text }) -join ", " } else { "None" }
    $MarkdownLines.Add("## $PlaybookIndex. $($Playbook.name)")
    $MarkdownLines.Add("")
    $MarkdownLines.Add("- **ID:** $($Playbook.id)")
    $MarkdownLines.Add("- **Tags:** $TagList")
    $MarkdownLines.Add("- **Created:** $($Playbook.dateCreated)")
    $MarkdownLines.Add("- **Updated:** $($Playbook.dateUpdated)")
    $MarkdownLines.Add("- **Description:** $($Playbook.description)")
    $MarkdownLines.Add("")

    if ($Procedures) {
        $MarkdownLines.Add("### Procedures")
        $MarkdownLines.Add("")
        $StepNum = 0
        foreach ($Proc in $Procedures) {
            $StepNum++
            $MarkdownLines.Add("$StepNum. **$($Proc.name)**")
            if ($Proc.description) {
                $MarkdownLines.Add("   - $($Proc.description)")
            }
        }
        $MarkdownLines.Add("")
    } else {
        $MarkdownLines.Add("*No procedures defined.*")
        $MarkdownLines.Add("")
    }
    $MarkdownLines.Add("---")
    $MarkdownLines.Add("")
}

# Write JSON export
$ExportLibrary | ConvertTo-Json -Depth 10 | Set-Content -Path $JsonPath -Encoding UTF8
Write-Host "JSON export: $JsonPath" -ForegroundColor Green

# Write Markdown summary
$MarkdownLines | Set-Content -Path $MarkdownPath -Encoding UTF8
Write-Host "Markdown summary: $MarkdownPath" -ForegroundColor Green

# Summary
Write-Host "`nExport complete: $(@($ExportLibrary).Count) playbooks exported." -ForegroundColor Cyan
$TotalProcedures = ($ExportLibrary | ForEach-Object { @($_.Procedures).Count } | Measure-Object -Sum).Sum
Write-Host "Total procedures across all playbooks: $TotalProcedures" -ForegroundColor Cyan

$ExportLibrary
