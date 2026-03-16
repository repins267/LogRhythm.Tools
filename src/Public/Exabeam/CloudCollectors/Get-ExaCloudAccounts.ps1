using namespace System
using namespace System.Collections.Generic

Function Get-ExaCloudAccounts {
    <#
    .SYNOPSIS
        Retrieve all Exabeam cloud collector accounts.
    .DESCRIPTION
        Returns the list of cloud collector accounts configured in the Exabeam
        environment. Accounts represent the authentication and connection
        configurations used by cloud collectors.
    .OUTPUTS
        PSCustomObject representing the Exabeam cloud collector accounts.
    .EXAMPLE
        PS C:\> Get-ExaCloudAccounts
        ---
        Returns all cloud collector accounts.
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
        $RequestUrl = $Api.BaseUrl + "cloud-collectors/v1/accounts"
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
