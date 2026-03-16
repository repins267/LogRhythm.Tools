using namespace System
using namespace System.Collections.Generic

Function Get-ExaAnalyticsRules {
    <#
    .SYNOPSIS
        Retrieve all Exabeam analytics rules.
    .DESCRIPTION
        Returns the list of analytics (detection) rules configured in the Exabeam
        environment. Includes rule details such as name, type, severity, MITRE
        mappings, and enabled status.
    .OUTPUTS
        PSCustomObject representing the Exabeam analytics rules.
    .EXAMPLE
        PS C:\> Get-ExaAnalyticsRules
        ---
        Returns all analytics rules from the Exabeam environment.
    .NOTES
        Exabeam-API
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding()]
    Param()

    Begin {
        $Me = $MyInvocation.MyCommand.Name
        $Api = Initialize-ExaApiRequest

        # Define HTTP Method
        $Method = $HttpMethod.Get

        # Define HTTP URI
        $RequestUrl = $Api.BaseUrl + "detection-management/v1/rules"
    }

    Process {
        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        # Send Request
        $Response = Invoke-RestAPIMethod -Uri $RequestUrl -Headers $Api.Headers -Method $Method -Origin $Me
        if (($null -ne $Response.Error) -and ($Response.Error -eq $true)) {
            return $Response
        }

        return $Response
    }

    End { }
}
