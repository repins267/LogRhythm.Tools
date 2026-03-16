using namespace System
using namespace System.Collections.Generic

Function Export-ExaAnalyticsRules {
    <#
    .SYNOPSIS
        Export Exabeam analytics rule definitions by ID.
    .DESCRIPTION
        Exports the full rule definitions for the specified analytics rule IDs from
        the Exabeam detection management API. Accepts up to 50 rule IDs per request
        and returns the complete rule configuration for each.
    .PARAMETER Id
        Array of analytics rule IDs to export. Maximum of 50 IDs per request.
    .OUTPUTS
        PSCustomObject representing the exported analytics rule definitions.
    .EXAMPLE
        PS C:\> Export-ExaAnalyticsRules -Id "rule-001", "rule-002"
        ---
        Exports the full definitions for the specified analytics rules.
    .NOTES
        Exabeam-API
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [ValidateCount(1, 50)]
        [string[]] $Id
    )

    Begin {
        $Me = $MyInvocation.MyCommand.Name
        $Api = Initialize-ExaApiRequest

        # Define HTTP Method
        $Method = $HttpMethod.Post

        # Define HTTP URI
        $RequestUrl = $Api.BaseUrl + "detection-management/v1/rules/export"
    }

    Process {
        Write-Verbose "[$Me]: Request URL: $RequestUrl"
        Write-Verbose "[$Me]: Exporting $($Id.Count) rule(s)"

        # Build request body
        $Body = @{
            ids = @($Id)
        } | ConvertTo-Json -Depth 5 -Compress

        # Send Request
        $Response = Invoke-RestAPIMethod -Uri $RequestUrl -Headers $Api.Headers -Method $Method -Body $Body -Origin $Me
        if (($null -ne $Response.Error) -and ($Response.Error -eq $true)) {
            return $Response
        }

        return $Response
    }

    End { }
}
