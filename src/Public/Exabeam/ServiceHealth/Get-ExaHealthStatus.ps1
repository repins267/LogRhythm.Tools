using namespace System
using namespace System.Collections.Generic

Function Get-ExaHealthStatus {
    <#
    .SYNOPSIS
        Retrieve the Exabeam application health status.
    .DESCRIPTION
        Returns the current health status of the Exabeam application by querying the
        health-consumption API endpoint. Provides overall application availability and
        component status information.
    .OUTPUTS
        PSCustomObject representing the Exabeam application health status.
    .EXAMPLE
        PS C:\> Get-ExaHealthStatus
        ---
        Returns the current Exabeam application health status object.
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
        $RequestUrl = $Api.BaseUrl + "health-consumption/v1/health/appStatus"
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
