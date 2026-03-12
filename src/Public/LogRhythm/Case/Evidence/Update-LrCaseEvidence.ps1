using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function Update-LrCaseEvidence {
    <#
    .SYNOPSIS
        Update an evidence record on a LogRhythm case.
    .DESCRIPTION
        Update-LrCaseEvidence performs a PUT update on a specific evidence
        record within a case.
    .PARAMETER Id
        The case ID or case number.
    .PARAMETER EvidenceId
        The evidence record ID to update.
    .PARAMETER Text
        Updated text content for the evidence.
    .PARAMETER Pinned
        Set whether the evidence is pinned.
    .PARAMETER PassThru
        Switch parameter that will enable the return of the output object from the cmdlet.
    .PARAMETER Credential
        PSCredential containing an API Token in the Password field.
    .OUTPUTS
        Success: No Output.
        PassThru: PSCustomObject representing the updated evidence record.
    .EXAMPLE
        PS C:\> Update-LrCaseEvidence -Id 1780 -EvidenceId 4 -Text "Updated note" -PassThru
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
        [string] $Text,

        [Parameter(Mandatory = $false, Position = 3)]
        [bool] $Pinned,

        [Parameter(Mandatory = $false, Position = 4)]
        [switch] $PassThru,

        [Parameter(Mandatory = $false, Position = 5)]
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

        $RequestUrl = $BaseUrl + "/lr-case-api/cases/$CaseNumber/evidence/$EvidenceId/"
        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        $Body = [PSCustomObject]@{}
        if ($PSBoundParameters.ContainsKey('Text')) {
            $Body | Add-Member -NotePropertyName text -NotePropertyValue $Text
        }
        if ($PSBoundParameters.ContainsKey('Pinned')) {
            $Body | Add-Member -NotePropertyName pinned -NotePropertyValue $Pinned
        }

        Write-Verbose "[$Me]: Request Body:`n$($Body | ConvertTo-Json)"

        $Response = Invoke-RestAPIMethod -Uri $RequestUrl -Headers $Headers -Method $Method -Body $($Body | ConvertTo-Json) -Origin $Me
        if (($null -ne $Response.Error) -and ($Response.Error -eq $true)) { return $Response }

        if ($PassThru) { return $Response }
    }

    End { }
}
