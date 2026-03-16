using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function Get-LrIdentityFromList {
    <#
    .SYNOPSIS
        Retrieve an identity from a specific identity list via the LogRhythm Admin API.
    .DESCRIPTION
        Get-LrIdentityFromList returns a specific identity record from an
        identity list by list ID and identity ID.
    .PARAMETER ListId
        The identity list ID.
    .PARAMETER IdentityId
        The identity ID to retrieve from the list.
    .PARAMETER Credential
        PSCredential containing an API Token in the Password field.
    .OUTPUTS
        PSCustomObject representing the identity record from the list.
    .EXAMPLE
        PS C:\> Get-LrIdentityFromList -ListId 1 -IdentityId 100
    .NOTES
        LogRhythm-API
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, Position = 0)]
        [int32] $ListId,

        [Parameter(Mandatory = $true, Position = 1)]
        [int32] $IdentityId,

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

        $RequestUrl = $BaseUrl + "/lr-admin-api/identity-lists/" + $ListId + "/identities/" + $IdentityId + "/"
        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        $Response = Invoke-RestAPIMethod -Uri $RequestUrl -Headers $Headers -Method $Method -Origin $Me
        if (($null -ne $Response.Error) -and ($Response.Error -eq $true)) { return $Response }

        return $Response
    }

    End { }
}
