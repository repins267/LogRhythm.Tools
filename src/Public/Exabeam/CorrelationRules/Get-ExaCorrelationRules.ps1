using namespace System
using namespace System.Collections.Generic

Function Get-ExaCorrelationRules {
    <#
    .SYNOPSIS
        Retrieve all Exabeam correlation rules.
    .DESCRIPTION
        Returns the list of correlation rules configured in the Exabeam
        environment. Includes rule details such as name, severity, enabled
        status, schedule, and trigger counts.
    .PARAMETER Name
        Filter results by rule name. Supports wildcards.
    .PARAMETER Severity
        Filter results by severity level.
    .PARAMETER Enabled
        Filter results by enabled status.
    .OUTPUTS
        PSCustomObject representing the Exabeam correlation rules.
    .EXAMPLE
        PS C:\> Get-ExaCorrelationRules
        ---
        Returns all correlation rules from the Exabeam environment.
    .EXAMPLE
        PS C:\> Get-ExaCorrelationRules -Name "*After-Hours*"
        ---
        Returns correlation rules matching the name filter.
    .EXAMPLE
        PS C:\> Get-ExaCorrelationRules -Severity high -Enabled $true
        ---
        Returns enabled high-severity correlation rules.
    .NOTES
        Exabeam-API
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false, Position = 0)]
        [string] $Name,

        [Parameter(Mandatory = $false)]
        [ValidateSet("none", "low", "medium", "high", "critical")]
        [string] $Severity,

        [Parameter(Mandatory = $false)]
        [bool] $Enabled
    )

    Begin {
        $Me = $MyInvocation.MyCommand.Name
        $Api = Initialize-ExaApiRequest

        # Define HTTP Method
        $Method = $HttpMethod.Get

        # Define HTTP URI
        $RequestUrl = $Api.BaseUrl + "correlation-rules/v2/rules"
    }

    Process {
        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        # Send Request
        $Response = Invoke-RestAPIMethod -Uri $RequestUrl -Headers $Api.Headers -Method $Method -Origin $Me
        if (($null -ne $Response.Error) -and ($Response.Error -eq $true)) {
            return $Response
        }

        # Apply client-side filters
        if ($Name) {
            $Response = $Response | Where-Object { $_.name -like $Name }
        }
        if ($Severity) {
            $Response = $Response | Where-Object { $_.severity -eq $Severity }
        }
        if ($PSBoundParameters.ContainsKey('Enabled')) {
            $Response = $Response | Where-Object { $_.enabled -eq $Enabled }
        }

        return $Response
    }

    End { }
}
