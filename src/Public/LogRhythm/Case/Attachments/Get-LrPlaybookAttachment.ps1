using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function Get-LrPlaybookAttachment {
    <#
    .SYNOPSIS
        Retrieve a specific attachment from a playbook via the LogRhythm Case API.
    .DESCRIPTION
        Get-LrPlaybookAttachment returns a single attachment record by playbook
        ID and attachment ID.
    .PARAMETER Id
        The playbook ID (GUID).
    .PARAMETER AttachmentId
        The attachment ID (GUID).
    .PARAMETER Credential
        PSCredential containing an API Token in the Password field.
    .OUTPUTS
        PSCustomObject representing the playbook attachment record.
    .EXAMPLE
        PS C:\> Get-LrPlaybookAttachment -Id "F47AC10B-58CC-4372-A567-0E02B2C3D479" -AttachmentId "A1B2C3D4"
    .NOTES
        LogRhythm-API
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Id,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string] $AttachmentId,

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
        $RequestUrl = $BaseUrl + "/lr-case-api/playbooks/" + $Id + "/attachments/" + $AttachmentId + "/"
        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        $Response = Invoke-RestAPIMethod -Uri $RequestUrl -Headers $Headers -Method $Method -Origin $Me
        if (($null -ne $Response.Error) -and ($Response.Error -eq $true)) { return $Response }

        return $Response
    }

    End { }
}
