using namespace System
using namespace System.Collections.Generic

Function Get-ExaContextTable {
    <#
    .SYNOPSIS
        Retrieve a specific Exabeam context table by ID.
    .DESCRIPTION
        Returns the context table details for the specified table ID from the
        Exabeam context management API. Provides table metadata including name,
        schema, attribute configuration, and record count.
    .PARAMETER Id
        The unique identifier of the context table to retrieve.
    .OUTPUTS
        PSCustomObject representing the specified context table.
    .EXAMPLE
        PS C:\> Get-ExaContextTable -Id "table-abc123"
        ---
        Returns the context table details for the specified ID.
    .NOTES
        Exabeam-API
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Alias('TableId')]
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
        $RequestUrl = $Api.BaseUrl + "context-management/v1/tables/$Id"

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
