using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function Update-LrHosts {
    <#
    .SYNOPSIS
        Batch update host records in the LogRhythm Admin API.
    .DESCRIPTION
        Update-LrHosts performs a batch PUT update on multiple host records.
        Accepts an array of host objects to update in a single API call.
    .PARAMETER Hosts
        An array of host objects to update. Each object should contain the full
        host record fields (id, entity, name, recordStatusName, etc.).
    .PARAMETER PassThru
        Switch parameter that will enable the return of the output object from the cmdlet.
    .PARAMETER Credential
        PSCredential containing an API Token in the Password field.
    .OUTPUTS
        Success: No Output.
        PassThru: PSCustomObject representing the updated host records.
    .EXAMPLE
        PS C:\> $hosts = @(
            [PSCustomObject]@{ id = 1; entity = @{ id = 1 }; name = "Host1"; recordStatusName = "Active" }
            [PSCustomObject]@{ id = 2; entity = @{ id = 1 }; name = "Host2"; recordStatusName = "Active" }
        )
        PS C:\> Update-LrHosts -Hosts $hosts -PassThru
    .NOTES
        LogRhythm-API
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, Position = 0)]
        [object[]] $Hosts,

        [Parameter(Mandatory = $false, Position = 1)]
        [switch] $PassThru,

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

        $RequestUrl = $BaseUrl + "/lr-admin-api/hosts/"
        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        $Body = $Hosts | ConvertTo-Json -Depth 5
        Write-Verbose "[$Me]: Request Body:`n$Body"

        $Response = Invoke-RestAPIMethod -Uri $RequestUrl -Headers $Headers -Method $Method -Body $Body -Origin $Me
        if (($null -ne $Response.Error) -and ($Response.Error -eq $true)) { return $Response }

        if ($PassThru) { return $Response }
    }

    End { }
}
