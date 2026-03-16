using namespace System
using namespace System.Collections.Generic

Function Get-ExaUsers {
    <#
    .SYNOPSIS
        Retrieve Exabeam platform users.
    .DESCRIPTION
        Returns the list of users configured in the Exabeam platform. Includes
        user details such as name, email, role assignments, and account status.
    .OUTPUTS
        PSCustomObject representing the Exabeam platform users.
    .EXAMPLE
        PS C:\> Get-ExaUsers
        ---
        Returns all users from the Exabeam platform.
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
        $RequestUrl = $Api.BaseUrl + "platform/v1/users"
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
