using namespace System
using namespace System.Collections.Generic

Function Get-ExaCorrelationRuleCount {
    <#
    .SYNOPSIS
        Retrieve the Exabeam correlation rule count.
    .DESCRIPTION
        Returns the total number of correlation rules configured in the Exabeam
        environment from the health-consumption API endpoint.
    .OUTPUTS
        PSCustomObject representing the correlation rule count.
    .EXAMPLE
        PS C:\> Get-ExaCorrelationRuleCount
        ---
        Returns the correlation rule count object.
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
        $RequestUrl = $Api.BaseUrl + "health-consumption/v1/consumption/correlationRule"
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
