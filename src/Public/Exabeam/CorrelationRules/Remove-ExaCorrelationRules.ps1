using namespace System
using namespace System.Collections.Generic

Function Remove-ExaCorrelationRules {
    <#
    .SYNOPSIS
        Delete a list of Exabeam correlation rules.
    .DESCRIPTION
        Deletes multiple correlation rules from the Exabeam environment in a single
        API call. Accepts an array of rule IDs.
    .PARAMETER Id
        Array of correlation rule IDs (UUIDs) to delete.
    .PARAMETER PassThru
        Return the API response object.
    .OUTPUTS
        PSCustomObject representing the delete result when PassThru is specified.
    .EXAMPLE
        PS C:\> Remove-ExaCorrelationRules -Id "rule-001", "rule-002"
        ---
        Deletes the specified correlation rules.
    .NOTES
        Exabeam-API
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    Param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string[]] $Id,

        [Parameter(Mandatory = $false)]
        [switch] $PassThru
    )

    Begin {
        $Me = $MyInvocation.MyCommand.Name
        $Api = Initialize-ExaApiRequest

        # Define HTTP Method
        $Method = $HttpMethod.Post

        # Define HTTP URI
        $RequestUrl = $Api.BaseUrl + "correlation-rules/v2/rules/delete"
    }

    Process {
        Write-Verbose "[$Me]: Request URL: $RequestUrl"
        Write-Verbose "[$Me]: Deleting $($Id.Count) rule(s)"

        $Body = @{
            ruleIds = @($Id)
        } | ConvertTo-Json -Depth 5 -Compress

        if ($PSCmdlet.ShouldProcess("$($Id.Count) rules", "Delete Exabeam correlation rules")) {
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
