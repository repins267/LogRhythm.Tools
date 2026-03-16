using namespace System
using namespace System.Collections.Generic

Function Get-ExaApiKeys {
    <#
    .SYNOPSIS
        Retrieve Exabeam platform API keys.
    .DESCRIPTION
        Returns the list of API keys configured in the Exabeam platform. Includes
        key metadata such as name, creation date, and associated user information.
    .OUTPUTS
        PSCustomObject representing the Exabeam platform API keys.
    .EXAMPLE
        PS C:\> Get-ExaApiKeys
        ---
        Returns all API keys from the Exabeam platform.
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
        $RequestUrl = $Api.BaseUrl + "platform/v1/api-keys"
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
