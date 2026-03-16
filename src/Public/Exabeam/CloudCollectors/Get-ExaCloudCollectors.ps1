using namespace System
using namespace System.Collections.Generic

Function Get-ExaCloudCollectors {
    <#
    .SYNOPSIS
        Retrieve all Exabeam cloud collector configurations.
    .DESCRIPTION
        Returns the list of cloud collector configurations from the Exabeam
        environment. Includes collector details such as name, type, status,
        and configuration settings.
    .OUTPUTS
        PSCustomObject representing the Exabeam cloud collector configurations.
    .EXAMPLE
        PS C:\> Get-ExaCloudCollectors
        ---
        Returns all cloud collector configurations.
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
        $RequestUrl = $Api.BaseUrl + "cloud-collectors/v1/configs"
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
