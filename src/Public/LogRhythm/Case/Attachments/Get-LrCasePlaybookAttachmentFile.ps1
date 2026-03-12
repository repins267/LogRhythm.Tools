using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function Get-LrCasePlaybookAttachmentFile {
    <#
    .SYNOPSIS
        Download a playbook attachment file within a case via the LogRhythm Case API.
    .DESCRIPTION
        Get-LrCasePlaybookAttachmentFile retrieves the file content of a
        playbook attachment within a specific case.
    .PARAMETER CaseId
        The case ID or case number.
    .PARAMETER PlaybookId
        The playbook ID (GUID).
    .PARAMETER AttachmentId
        The attachment ID (GUID).
    .PARAMETER Credential
        PSCredential containing an API Token in the Password field.
    .OUTPUTS
        The attachment file content returned by the API.
    .EXAMPLE
        PS C:\> Get-LrCasePlaybookAttachmentFile -CaseId 1780 -PlaybookId "F47AC10B" -AttachmentId "A1B2C3D4"
    .NOTES
        LogRhythm-API
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [ValidateNotNull()]
        [object] $CaseId,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string] $PlaybookId,

        [Parameter(Mandatory = $true, Position = 2)]
        [ValidateNotNullOrEmpty()]
        [string] $AttachmentId,

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
        $Method = $HttpMethod.Get
        Enable-TrustAllCertsPolicy
    }

    Process {
        $IdStatus = Test-LrCaseIdFormat $CaseId
        if ($IdStatus.IsValid -eq $true) {
            $CaseNumber = $IdStatus.CaseNumber
        } else {
            return $IdStatus
        }

        $RequestUrl = $BaseUrl + "/lr-case-api/cases/$CaseNumber/playbooks/" + $PlaybookId + "/attachments/" + $AttachmentId + "/download/"
        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        $Response = Invoke-RestAPIMethod -Uri $RequestUrl -Headers $Headers -Method $Method -Origin $Me
        if (($null -ne $Response.Error) -and ($Response.Error -eq $true)) { return $Response }

        return $Response
    }

    End { }
}
