using namespace System
using namespace System.Collections.Generic

Function Get-ExaLicenseDetails {
    <#
    .SYNOPSIS
        Retrieve Exabeam license details.
    .DESCRIPTION
        Returns detailed license information for the Exabeam environment using the
        v2 health-consumption API endpoint, including entitlements, usage, and
        expiration data.
    .OUTPUTS
        PSCustomObject representing the Exabeam license details.
    .EXAMPLE
        PS C:\> Get-ExaLicenseDetails
        ---
        Returns the Exabeam license details object.
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
        $RequestUrl = $Api.BaseUrl + "health-consumption/v2/consumption/licenseDetails"
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
