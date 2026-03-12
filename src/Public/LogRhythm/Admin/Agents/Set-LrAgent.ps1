using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function Set-LrAgent {
    <#
    .SYNOPSIS
        Partially update an agent record in the LogRhythm Admin API.
    .DESCRIPTION
        Set-LrAgent performs a PATCH update on a System Monitor agent record,
        allowing selective field updates without requiring a full object.
    .PARAMETER Id
        The agent ID to update.
    .PARAMETER RecordStatus
        Set the agent record status. Valid entries: "Active", "Retired".
    .PARAMETER PassThru
        Switch parameter that will enable the return of the output object from the cmdlet.
    .PARAMETER Credential
        PSCredential containing an API Token in the Password field.
    .OUTPUTS
        Success: No Output.
        PassThru: PSCustomObject representing the updated agent.
    .EXAMPLE
        PS C:\> Set-LrAgent -Id 2 -RecordStatus "Retired" -PassThru
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
        [ValidateSet('Active', 'Retired', ignorecase=$true)]
        [string] $RecordStatus,

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
        $Method = $HttpMethod.Patch
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

        $RequestUrl = $BaseUrl + "/lr-admin-api/agents/" + $Id + "/"
        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        # Build dynamic body with only supplied parameters
        $Body = [PSCustomObject]@{}
        if ($PSBoundParameters.ContainsKey('RecordStatus')) {
            $Body | Add-Member -NotePropertyName recordStatusName -NotePropertyValue (Get-Culture).TextInfo.ToTitleCase($RecordStatus)
        }

        Write-Verbose "[$Me]: Request Body:`n$($Body | ConvertTo-Json)"

        $Response = Invoke-RestAPIMethod -Uri $RequestUrl -Headers $Headers -Method $Method -Body $($Body | ConvertTo-Json) -Origin $Me
        if (($null -ne $Response.Error) -and ($Response.Error -eq $true)) { return $Response }

        if ($PassThru) { return $Response }
    }

    End { }
}
