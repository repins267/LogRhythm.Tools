using namespace System
using namespace System.Collections.Generic

Function Get-ExaCloudAccount {
    <#
    .SYNOPSIS
        Retrieve a specific Exabeam cloud collector account by ID.
    .DESCRIPTION
        Returns the cloud collector account details for the specified account ID
        from the Exabeam environment. Provides authentication and connection
        configuration for a single cloud collector account.
    .PARAMETER Id
        The unique identifier of the cloud collector account to retrieve.
    .OUTPUTS
        PSCustomObject representing the specified cloud collector account.
    .EXAMPLE
        PS C:\> Get-ExaCloudAccount -Id "abc123-def456"
        ---
        Returns the cloud collector account for the specified ID.
    .NOTES
        Exabeam-API
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Alias('AccountId')]
        [string] $Id
    )

    Begin {
        $Me = $MyInvocation.MyCommand.Name
        $Api = Initialize-ExaApiRequest

        # Define HTTP Method
        $Method = $HttpMethod.Get
    }

    Process {
        # Define HTTP URI
        $RequestUrl = $Api.BaseUrl + "cloud-collectors/v1/accounts/$Id"

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
