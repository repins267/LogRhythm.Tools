using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function Update-LrCaseMetrics {
    <#
    .SYNOPSIS
        Update metrics for a LogRhythm case.
    .DESCRIPTION
        Update-LrCaseMetrics performs a PUT update on the metrics associated
        with a specific case.
    .PARAMETER Id
        The case ID or case number.
    .PARAMETER Metrics
        The metrics object to set on the case.
    .PARAMETER PassThru
        Switch parameter that will enable the return of the output object from the cmdlet.
    .PARAMETER Credential
        PSCredential containing an API Token in the Password field.
    .OUTPUTS
        Success: No Output.
        PassThru: PSCustomObject representing the updated case metrics.
    .EXAMPLE
        PS C:\> Update-LrCaseMetrics -Id 1780 -Metrics $metricsObj -PassThru
    .NOTES
        LogRhythm-API
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [ValidateNotNull()]
        [object] $Id,

        [Parameter(Mandatory = $true, Position = 1)]
        [object] $Metrics,

        [Parameter(Mandatory = $false, Position = 2)]
        [switch] $PassThru,

        [Parameter(Mandatory = $false, Position = 3)]
        [ValidateNotNull()]
        [pscredential] $Credential = $LrtConfig.LogRhythm.ApiKey
    )

    Begin {
        $Me = $MyInvocation.MyCommand.Name
        $BaseUrl = $LrtConfig.LogRhythm.BaseUrl
        $Token = $Credential.GetNetworkCredential().Password
        $Headers = [Dictionary[string,string]]::new()
        $Headers.Add("Authorization", "Bearer $Token")
        $Method = $HttpMethod.Put
        Enable-TrustAllCertsPolicy
    }

    Process {
        $IdStatus = Test-LrCaseIdFormat $Id
        if ($IdStatus.IsValid -eq $true) {
            $CaseNumber = $IdStatus.CaseNumber
        } else {
            return $IdStatus
        }

        $RequestUrl = $BaseUrl + "/lr-case-api/cases/$CaseNumber/metrics/"
        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        $Body = $Metrics | ConvertTo-Json -Depth 5
        Write-Verbose "[$Me]: Request Body:`n$Body"

        $Response = Invoke-RestAPIMethod -Uri $RequestUrl -Headers $Headers -Method $Method -Body $Body -Origin $Me
        if (($null -ne $Response.Error) -and ($Response.Error -eq $true)) { return $Response }

        if ($PassThru) { return $Response }
    }

    End { }
}
