using namespace System
using namespace System.Collections.Generic

Function Set-ExaCorrelationRuleStateList {
    <#
    .SYNOPSIS
        Enable or disable multiple Exabeam correlation rules.
    .DESCRIPTION
        Sets the enabled/disabled state of multiple correlation rules in a single
        API call. Accepts an array of rule IDs.
    .PARAMETER Id
        Array of correlation rule IDs (UUIDs).
    .PARAMETER Enabled
        Set to $true to enable the rules, $false to disable.
    .PARAMETER PassThru
        Return the API response object.
    .OUTPUTS
        PSCustomObject representing the state change result when PassThru is specified.
    .EXAMPLE
        PS C:\> $ids = (Get-ExaCorrelationRules -Severity low).id
        PS C:\> Set-ExaCorrelationRuleStateList -Id $ids -Enabled $false
        ---
        Disables all low-severity correlation rules.
    .NOTES
        Exabeam-API
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding(SupportsShouldProcess = $true)]
    Param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string[]] $Id,

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

        # Define HTTP URI
        $RequestUrl = $Api.BaseUrl + "correlation-rules/v2/rules/setrulesstate"
    }

    Process {
        Write-Verbose "[$Me]: Request URL: $RequestUrl"
        Write-Verbose "[$Me]: Setting state for $($Id.Count) rule(s)"

        $Body = @{
            ruleIds = @($Id)
            enable  = $Enabled
        } | ConvertTo-Json -Depth 5 -Compress

        $StateText = if ($Enabled) { "Enable" } else { "Disable" }
        if ($PSCmdlet.ShouldProcess("$($Id.Count) rules", "$StateText Exabeam correlation rules")) {
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
