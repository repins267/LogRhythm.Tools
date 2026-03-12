using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function Add-LrPlaybookAttachment {
    <#
    .SYNOPSIS
        Add or update an attachment on a playbook via the LogRhythm Case API.
    .DESCRIPTION
        Add-LrPlaybookAttachment performs a PUT to set an attachment on a
        playbook by playbook ID and attachment ID.
    .PARAMETER Id
        The playbook ID (GUID).
    .PARAMETER AttachmentId
        The attachment ID (GUID).
    .PARAMETER Attachment
        The attachment object to set.
    .PARAMETER PassThru
        Switch parameter that will enable the return of the output object from the cmdlet.
    .PARAMETER Credential
        PSCredential containing an API Token in the Password field.
    .OUTPUTS
        Success: No Output.
        PassThru: PSCustomObject representing the attachment record.
    .EXAMPLE
        PS C:\> Add-LrPlaybookAttachment -Id "F47AC10B" -AttachmentId "A1B2C3D4" -Attachment $attObj -PassThru
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

        [Parameter(Mandatory = $true, Position = 2)]
        [object] $Attachment,

        [Parameter(Mandatory = $false, Position = 3)]
        [switch] $PassThru,

        [Parameter(Mandatory = $false, Position = 4)]
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
        $RequestUrl = $BaseUrl + "/lr-case-api/playbooks/" + $Id + "/attachments/" + $AttachmentId + "/"
        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        $Body = $Attachment | ConvertTo-Json -Depth 5
        Write-Verbose "[$Me]: Request Body:`n$Body"

        $Response = Invoke-RestAPIMethod -Uri $RequestUrl -Headers $Headers -Method $Method -Body $Body -Origin $Me
        if (($null -ne $Response.Error) -and ($Response.Error -eq $true)) { return $Response }

        if ($PassThru) { return $Response }
    }

    End { }
}
