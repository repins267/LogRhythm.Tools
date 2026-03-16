using namespace System
using namespace System.Collections.Generic

Function Get-ExaUseCases {
    <#
    .SYNOPSIS
        Retrieve Exabeam use cases.
    .DESCRIPTION
        Returns the list of use cases configured in the Exabeam environment.
        Use cases represent detection scenarios and analytics workflows.
    .OUTPUTS
        PSCustomObject representing the Exabeam use cases.
    .EXAMPLE
        PS C:\> Get-ExaUseCases
        ---
        Returns all use cases from the Exabeam environment.
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
        $RequestUrl = $Api.BaseUrl + "use-cases/v1/use-cases"
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
