using namespace System
using namespace System.Collections.Generic

Function Search-ExaAuditEvents {
    <#
    .SYNOPSIS
        Search Exabeam audit events within a time range.
    .DESCRIPTION
        Queries the Exabeam audit API to search for audit events matching a filter
        expression within the specified time window. Supports field selection, result
        limiting, and custom ordering.
    .PARAMETER Filter
        Filter expression string to match audit events.
    .PARAMETER Fields
        Array of field names to include in results. Defaults to all fields.
    .PARAMETER StartTime
        Beginning of the search time range.
    .PARAMETER EndTime
        End of the search time range.
    .PARAMETER Limit
        Maximum number of results to return. Defaults to 3000.
    .PARAMETER OrderBy
        Array of field names to order results by.
    .OUTPUTS
        PSCustomObject representing the matching audit events.
    .EXAMPLE
        PS C:\> Search-ExaAuditEvents -Filter "action:login" -StartTime (Get-Date).AddDays(-1) -EndTime (Get-Date)
        ---
        Returns audit events matching the login action filter from the last 24 hours.
    .NOTES
        Exabeam-API
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Filter,

        [Parameter(Mandatory = $false, Position = 1)]
        [ValidateNotNull()]
        [string[]] $Fields = @('*'),

        [Parameter(Mandatory = $true, Position = 2)]
        [datetime] $StartTime,

        [Parameter(Mandatory = $true, Position = 3)]
        [datetime] $EndTime,

        [Parameter(Mandatory = $false, Position = 4)]
        [ValidateRange(1, 100000)]
        [int] $Limit = 3000,

        [Parameter(Mandatory = $false, Position = 5)]
        [string[]] $OrderBy
    )

    Begin {
        $Me = $MyInvocation.MyCommand.Name
        $Api = Initialize-ExaApiRequest

        # Define HTTP Method
        $Method = $HttpMethod.Post

        # Define HTTP URI
        $RequestUrl = $Api.BaseUrl + "audit/v1/search"
    }

    Process {
        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        # Convert datetimes to ISO-8601 UTC format
        $StartTimeIso = $StartTime.ToUniversalTime().ToString('o')
        $EndTimeIso = $EndTime.ToUniversalTime().ToString('o')

        # Build request body
        $BodyObj = @{
            filter    = $Filter
            fields    = $Fields
            startTime = $StartTimeIso
            endTime   = $EndTimeIso
            limit     = $Limit
        }

        if ($OrderBy) {
            $BodyObj.orderBy = $OrderBy
        }

        $Body = $BodyObj | ConvertTo-Json -Depth 5 -Compress

        Write-Verbose "[$Me]: Request Body: $Body"

        # Send Request
        $Response = Invoke-RestAPIMethod -Uri $RequestUrl -Headers $Api.Headers -Method $Method -Body $Body -Origin $Me
        if (($null -ne $Response.Error) -and ($Response.Error -eq $true)) {
            return $Response
        }

        return $Response
    }

    End { }
}
