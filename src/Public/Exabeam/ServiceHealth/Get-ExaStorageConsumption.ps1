using namespace System
using namespace System.Collections.Generic

Function Get-ExaStorageConsumption {
    <#
    .SYNOPSIS
        Retrieve Exabeam long-term storage consumption metrics.
    .DESCRIPTION
        Returns LTS (Long-Term Storage) consumption details including unit of measure,
        total search volume used, and storage allocation information from the
        health-consumption API.
    .OUTPUTS
        PSCustomObject representing LTS consumption with unitOfMeasure,
        totalLTSearchVolumeUsed, and related storage metrics.
    .EXAMPLE
        PS C:\> Get-ExaStorageConsumption
        ---
        Returns the current LTS storage consumption object.
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
        $RequestUrl = $Api.BaseUrl + "health-consumption/v1/consumption/lts"
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
