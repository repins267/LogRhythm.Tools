using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function Update-LrPlaybookPartial {
    <#
    .SYNOPSIS
        Partially update a playbook in the LogRhythm Case API.
    .DESCRIPTION
        Update-LrPlaybookPartial performs a PATCH update on a playbook,
        allowing selective field updates without requiring the full object.
    .PARAMETER Id
        The playbook ID (GUID) to update.
    .PARAMETER Name
        Updated name for the playbook.
    .PARAMETER Description
        Updated description for the playbook.
    .PARAMETER PassThru
        Switch parameter that will enable the return of the output object from the cmdlet.
    .PARAMETER Credential
        PSCredential containing an API Token in the Password field.
    .OUTPUTS
        Success: No Output.
        PassThru: PSCustomObject representing the updated playbook.
    .EXAMPLE
        PS C:\> Update-LrPlaybookPartial -Id "F47AC10B-58CC-4372-A567-0E02B2C3D479" -Name "Updated Playbook" -PassThru
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
        [string] $Name,

        [Parameter(Mandatory = $false, Position = 2)]
        [string] $Description,

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
        $Method = $HttpMethod.Patch
        Enable-TrustAllCertsPolicy
    }

    Process {
        $RequestUrl = $BaseUrl + "/lr-case-api/playbooks/" + $Id + "/"
        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        $Body = [PSCustomObject]@{}
        if ($PSBoundParameters.ContainsKey('Name')) {
            $Body | Add-Member -NotePropertyName name -NotePropertyValue $Name
        }
        if ($PSBoundParameters.ContainsKey('Description')) {
            $Body | Add-Member -NotePropertyName description -NotePropertyValue $Description
        }

        Write-Verbose "[$Me]: Request Body:`n$($Body | ConvertTo-Json)"

        $Response = Invoke-RestAPIMethod -Uri $RequestUrl -Headers $Headers -Method $Method -Body $($Body | ConvertTo-Json) -Origin $Me
        if (($null -ne $Response.Error) -and ($Response.Error -eq $true)) { return $Response }

        if ($PassThru) { return $Response }
    }

    End { }
}
