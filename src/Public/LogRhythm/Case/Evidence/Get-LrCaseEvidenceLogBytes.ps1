using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function Get-LrCaseEvidenceLogBytes {
    <#
    .SYNOPSIS
        Retrieve log bytes for an evidence record on a LogRhythm case.
    .DESCRIPTION
        Get-LrCaseEvidenceLogBytes returns the log data associated with a
        specific evidence record.
    .PARAMETER Id
        The case ID or case number.
    .PARAMETER EvidenceId
        The evidence record ID.
    .PARAMETER Credential
        PSCredential containing an API Token in the Password field.
    .OUTPUTS
        The log byte data returned by the API.
    .EXAMPLE
        PS C:\> Get-LrCaseEvidenceLogBytes -Id 1780 -EvidenceId 4
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
        [int32] $EvidenceId,

        [Parameter(Mandatory = $false, Position = 2)]
        [ValidateNotNull()]
        [pscredential] $Credential = $LrtConfig.LogRhythm.ApiKey
    )

    Begin {
        $Me = $MyInvocation.MyCommand.Name
        $BaseUrl = $LrtConfig.LogRhythm.BaseUrl
        $Token = $Credential.GetNetworkCredential().Password
        $Headers = [Dictionary[string,string]]::new()
        $Headers.Add("Authorization", "Bearer $Token")
        $Method = $HttpMethod.Get
        Enable-TrustAllCertsPolicy
    }

    Process {
        $IdStatus = Test-LrCaseIdFormat $Id
        if ($IdStatus.IsValid -eq $true) {
            $CaseNumber = $IdStatus.CaseNumber
        } else {
            return $IdStatus
        }

        $RequestUrl = $BaseUrl + "/lr-case-api/cases/$CaseNumber/evidence/$EvidenceId/logs/"
        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        $Response = Invoke-RestAPIMethod -Uri $RequestUrl -Headers $Headers -Method $Method -Origin $Me
        if (($null -ne $Response.Error) -and ($Response.Error -eq $true)) { return $Response }

        return $Response
    }

    End { }
}
