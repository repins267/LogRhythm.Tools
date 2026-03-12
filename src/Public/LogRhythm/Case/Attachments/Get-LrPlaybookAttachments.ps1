using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function Get-LrPlaybookAttachments {
    <#
    .SYNOPSIS
        Retrieve attachments for a playbook from the LogRhythm Case API.
    .DESCRIPTION
        Get-LrPlaybookAttachments returns all attachment records associated
        with a playbook.
    .PARAMETER Id
        The playbook ID (GUID).
    .PARAMETER Credential
        PSCredential containing an API Token in the Password field.
    .OUTPUTS
        PSCustomObject representing playbook attachment records.
    .EXAMPLE
        PS C:\> Get-LrPlaybookAttachments -Id "F47AC10B-58CC-4372-A567-0E02B2C3D479"
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

        [Parameter(Mandatory = $false, Position = 1)]
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
        $RequestUrl = $BaseUrl + "/lr-case-api/playbooks/" + $Id + "/attachments/"
        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        $Response = Invoke-RestAPIMethod -Uri $RequestUrl -Headers $Headers -Method $Method -Origin $Me
        if (($null -ne $Response.Error) -and ($Response.Error -eq $true)) { return $Response }

        return $Response
    }

    End { }
}
