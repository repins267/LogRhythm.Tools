using namespace System
using namespace System.Collections.Generic

Function Get-ExaCorrelationRuleById {
    <#
    .SYNOPSIS
        Retrieve an Exabeam correlation rule by ID.
    .DESCRIPTION
        Returns the full correlation rule definition for the specified rule ID,
        including sequences, conditions, outcomes, schedule, and suppression config.
    .PARAMETER Id
        The correlation rule ID (UUID).
    .OUTPUTS
        PSCustomObject representing the correlation rule definition.
    .EXAMPLE
        PS C:\> Get-ExaCorrelationRuleById -Id "cbfa855a-f549-4cbd-8197-f3b82dddcd63"
        ---
        Returns the full rule definition for the specified correlation rule.
    .EXAMPLE
        PS C:\> Get-ExaCorrelationRules -Name "*After-Hours*" | Get-ExaCorrelationRuleById
        ---
        Pipes rule objects to retrieve the full definition for each.
    .NOTES
        Exabeam-API
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
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
        $RequestUrl = $Api.BaseUrl + "correlation-rules/v2/rules/$Id"
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
