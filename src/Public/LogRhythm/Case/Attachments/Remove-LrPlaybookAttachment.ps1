using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function Remove-LrPlaybookAttachment {
    <#
    .SYNOPSIS
        Remove an attachment from a playbook via the LogRhythm Case API.
    .DESCRIPTION
        Remove-LrPlaybookAttachment deletes a specific attachment from a
        playbook.
    .PARAMETER Id
        The playbook ID (GUID).
    .PARAMETER AttachmentId
        The attachment ID (GUID) to remove.
    .PARAMETER PassThru
        Switch parameter that will enable the return of the output object from the cmdlet.
    .PARAMETER Credential
        PSCredential containing an API Token in the Password field.
    .OUTPUTS
        Success: No Output.
        PassThru: PSCustomObject representing the API response.
    .EXAMPLE
        PS C:\> Remove-LrPlaybookAttachment -Id "F47AC10B" -AttachmentId "A1B2C3D4"
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
        $Method = $HttpMethod.Delete
        Enable-TrustAllCertsPolicy
    }

    Process {
        $RequestUrl = $BaseUrl + "/lr-case-api/playbooks/" + $Id + "/attachments/" + $AttachmentId + "/"
        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        $Response = Invoke-RestAPIMethod -Uri $RequestUrl -Headers $Headers -Method $Method -Origin $Me
        if (($null -ne $Response.Error) -and ($Response.Error -eq $true)) { return $Response }

        if ($PassThru) { return $Response }
    }

    End { }
}
