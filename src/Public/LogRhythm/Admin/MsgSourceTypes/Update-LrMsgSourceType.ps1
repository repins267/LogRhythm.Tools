using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function Update-LrMsgSourceType {
    <#
    .SYNOPSIS
        Update a message source type in the LogRhythm Admin API.
    .DESCRIPTION
        Update-LrMsgSourceType performs a full PUT update on a message source
        type record. The existing record is retrieved first, then supplied
        parameters override their respective fields.
    .PARAMETER Id
        The message source type ID to update.
    .PARAMETER Name
        Updated name for the message source type.
    .PARAMETER Abbreviation
        Updated abbreviation for the message source type.
    .PARAMETER PassThru
        Switch parameter that will enable the return of the output object from the cmdlet.
    .PARAMETER Credential
        PSCredential containing an API Token in the Password field.
    .OUTPUTS
        Success: No Output.
        PassThru: PSCustomObject representing the updated message source type.
    .EXAMPLE
        PS C:\> Update-LrMsgSourceType -Id 1001 -Name "Updated Name" -PassThru
    .NOTES
        LogRhythm-API
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [int32] $Id,

        [Parameter(Mandatory = $false, Position = 1)]
        [string] $Name,

        [Parameter(Mandatory = $false, Position = 2)]
        [string] $Abbreviation,

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
        $ErrorObject = [PSCustomObject]@{
            Error = $false; Type = $null; Code = $null; Note = $null; Raw = $null
        }

        if ($LrtConfig.LogRhythm.Version -match '7\.[0-4]\.\d+') {
            $ErrorObject.Error = $true
            $ErrorObject.Code = "404"
            $ErrorObject.Type = "Cmdlet not supported."
            $ErrorObject.Note = "This cmdlet is available in LogRhythm version 7.5.0 and greater."
            return $ErrorObject
        }

        # GET-then-merge
        $ExistingRecord = Get-LrMsgSourceType -Id $Id
        if (($null -ne $ExistingRecord.Error) -and ($ExistingRecord.Error -eq $true)) {
            return $ExistingRecord
        }

        if ($PSBoundParameters.ContainsKey('Name')) { $_name = $Name } else { $_name = $ExistingRecord.name }
        if ($PSBoundParameters.ContainsKey('Abbreviation')) { $_abbreviation = $Abbreviation } else { $_abbreviation = $ExistingRecord.abbreviation }

        $RequestUrl = $BaseUrl + "/lr-admin-api/msgSourceTypes/" + $Id + "/"
        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        $Body = [PSCustomObject]@{
            id           = $Id
            name         = $_name
            abbreviation = $_abbreviation
        }

        Write-Verbose "[$Me]: Request Body:`n$($Body | ConvertTo-Json)"

        $Response = Invoke-RestAPIMethod -Uri $RequestUrl -Headers $Headers -Method $Method -Body $($Body | ConvertTo-Json) -Origin $Me
        if (($null -ne $Response.Error) -and ($Response.Error -eq $true)) { return $Response }

        if ($PassThru) { return $Response }
    }

    End { }
}
