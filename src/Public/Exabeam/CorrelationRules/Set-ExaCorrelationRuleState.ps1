using namespace System
using namespace System.Collections.Generic

Function Set-ExaCorrelationRuleState {
    <#
    .SYNOPSIS
        Enable or disable an Exabeam correlation rule.
    .DESCRIPTION
        Sets the enabled/disabled state of a correlation rule by ID.
    .PARAMETER Id
        The correlation rule ID (UUID).
    .PARAMETER Enabled
        Set to $true to enable the rule, $false to disable.
    .PARAMETER PassThru
        Return the API response object.
    .OUTPUTS
        PSCustomObject representing the state change result when PassThru is specified.
    .EXAMPLE
        PS C:\> Set-ExaCorrelationRuleState -Id "cbfa855a-..." -Enabled $true
        ---
        Enables the specified correlation rule.
    .EXAMPLE
        PS C:\> Get-ExaCorrelationRules -Name "*Brute*" | Set-ExaCorrelationRuleState -Enabled $false
        ---
        Disables all correlation rules matching the name filter.
    .NOTES
        Exabeam-API
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding(SupportsShouldProcess = $true)]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Id,

        [Parameter(Mandatory = $true)]
        [bool] $Enabled,

        [Parameter(Mandatory = $false)]
        [switch] $PassThru
    )

    Begin {
        $Me = $MyInvocation.MyCommand.Name
        $Api = Initialize-ExaApiRequest

        # Define HTTP Method
        $Method = $HttpMethod.Post
    }

    Process {
        # Status is set via URL path: /rules/{id}/enabled or /rules/{id}/disabled
        $Status = if ($Enabled) { "enable" } else { "disable" }
        $RequestUrl = $Api.BaseUrl + "correlation-rules/v2/rules/$Id/$Status"
        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        $StateText = if ($Enabled) { "Enable" } else { "Disable" }
        if ($PSCmdlet.ShouldProcess($Id, "$StateText Exabeam correlation rule")) {
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
