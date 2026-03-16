using namespace System
using namespace System.Collections.Generic

Function Get-ExaRoles {
    <#
    .SYNOPSIS
        Retrieve Exabeam platform roles.
    .DESCRIPTION
        Returns the list of roles configured in the Exabeam platform. Includes
        role details such as name, permissions, and assignment information.
    .OUTPUTS
        PSCustomObject representing the Exabeam platform roles.
    .EXAMPLE
        PS C:\> Get-ExaRoles
        ---
        Returns all roles from the Exabeam platform.
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
        $RequestUrl = $Api.BaseUrl + "platform/v1/roles"
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
