using namespace System
using namespace System.Collections.Generic

Function Get-ExaCloudCollector {
    <#
    .SYNOPSIS
        Retrieve a specific Exabeam cloud collector configuration by ID.
    .DESCRIPTION
        Returns the cloud collector configuration for the specified collector ID
        from the Exabeam environment. Provides detailed configuration and status
        information for a single cloud collector.
    .PARAMETER Id
        The unique identifier of the cloud collector to retrieve.
    .OUTPUTS
        PSCustomObject representing the specified cloud collector configuration.
    .EXAMPLE
        PS C:\> Get-ExaCloudCollector -Id "abc123-def456"
        ---
        Returns the cloud collector configuration for the specified ID.
    .NOTES
        Exabeam-API
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Alias('CollectorId')]
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
        $RequestUrl = $Api.BaseUrl + "cloud-collectors/v1/configs/$Id"

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
