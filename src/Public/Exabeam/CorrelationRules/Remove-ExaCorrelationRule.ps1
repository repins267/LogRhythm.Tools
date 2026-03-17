using namespace System
using namespace System.Collections.Generic

Function Remove-ExaCorrelationRule {
    <#
    .SYNOPSIS
        Delete an Exabeam correlation rule by ID.
    .DESCRIPTION
        Deletes the specified correlation rule from the Exabeam environment.
    .PARAMETER Id
        The correlation rule ID (UUID) to delete.
    .PARAMETER PassThru
        Return the API response object.
    .OUTPUTS
        PSCustomObject representing the delete result when PassThru is specified.
    .EXAMPLE
        PS C:\> Remove-ExaCorrelationRule -Id "cbfa855a-f549-4cbd-8197-f3b82dddcd63"
        ---
        Deletes the specified correlation rule.
    .NOTES
        Exabeam-API
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Id,

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
        $RequestUrl = $Api.BaseUrl + "correlation-rules/v2/rules/$Id"
        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        if ($PSCmdlet.ShouldProcess($Id, "Delete Exabeam correlation rule")) {
            # Send Request
            $Response = Invoke-RestAPIMethod -Uri $RequestUrl -Headers $Api.Headers -Method $Method -Origin $Me
            if (($null -ne $Response.Error) -and ($Response.Error -eq $true)) {
                return $Response
            }

            if ($PassThru) { return $Response }
        }
    }

    End { }
}
