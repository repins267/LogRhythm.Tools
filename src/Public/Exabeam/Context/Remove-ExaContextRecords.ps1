using namespace System
using namespace System.Collections.Generic

Function Remove-ExaContextRecords {
    <#
    .SYNOPSIS
        Remove records from an Exabeam context table.
    .DESCRIPTION
        Deletes the specified records from an Exabeam context table by record IDs.
        Supports ShouldProcess for confirmation prompts when using -WhatIf or
        -Confirm parameters.
    .PARAMETER Id
        The unique identifier of the context table to remove records from.
    .PARAMETER RecordIds
        Array of record IDs to delete from the context table.
    .PARAMETER PassThru
        Switch to return the API response object.
    .OUTPUTS
        PSCustomObject representing the deletion result when PassThru is specified.
    .EXAMPLE
        PS C:\> Remove-ExaContextRecords -Id "table-abc123" -RecordIds "rec-001", "rec-002" -PassThru
        ---
        Removes the specified records from the context table and returns the result.
    .EXAMPLE
        PS C:\> Remove-ExaContextRecords -Id "table-abc123" -RecordIds "rec-001" -WhatIf
        ---
        Shows what would happen if the records were removed without executing the action.
    .NOTES
        Exabeam-API
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding(SupportsShouldProcess = $true)]
    Param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Alias('TableId')]
        [string] $Id,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string[]] $RecordIds,

        [Parameter(Mandatory = $false)]
        [switch] $PassThru
    )

    Begin {
        $Me = $MyInvocation.MyCommand.Name
        $Api = Initialize-ExaApiRequest

        # Define HTTP Method
        $Method = $HttpMethod.Delete
    }

    Process {
        # Define HTTP URI
        $RequestUrl = $Api.BaseUrl + "context-management/v1/tables/$Id/records"

        Write-Verbose "[$Me]: Request URL: $RequestUrl"
        Write-Verbose "[$Me]: Removing $($RecordIds.Count) record(s)"

        if ($PSCmdlet.ShouldProcess("Context Table $Id", "Remove $($RecordIds.Count) record(s)")) {
            # Build request body
            $Body = @{
                ids = @($RecordIds)
            } | ConvertTo-Json -Depth 5 -Compress

            # Send Request
            $Response = Invoke-RestAPIMethod -Uri $RequestUrl -Headers $Api.Headers -Method $Method -Body $Body -Origin $Me
            if (($null -ne $Response.Error) -and ($Response.Error -eq $true)) {
                return $Response
            }

            if ($PassThru) { return $Response }
        }
    }

    End { }
}
