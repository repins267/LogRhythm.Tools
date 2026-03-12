using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function Update-LrAgent {
    <#
    .SYNOPSIS
        Update an existing agent record in the LogRhythm Admin API.
    .DESCRIPTION
        Update-LrAgent performs a full PUT update on a System Monitor agent
        record. The existing record is retrieved first, then supplied parameters
        override their respective fields.
    .PARAMETER Id
        The agent ID to update.
    .PARAMETER Name
        Updated name for the agent.
    .PARAMETER SearchScope
        Updated search scope. Valid entries: "ParentEntitySearch", "GlobalEntitySearch".
    .PARAMETER SyslogEnabled
        Enable or disable syslog server on the agent.
    .PARAMETER NetflowEnabled
        Enable or disable netflow server on the agent.
    .PARAMETER SflowEnabled
        Enable or disable sflow server on the agent.
    .PARAMETER PassThru
        Switch parameter that will enable the return of the output object from the cmdlet.
    .PARAMETER Credential
        PSCredential containing an API Token in the Password field.
    .OUTPUTS
        Success: No Output.
        PassThru: PSCustomObject representing the updated agent.
    .EXAMPLE
        PS C:\> Update-LrAgent -Id 2 -Name "UpdatedAgent" -PassThru
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
        [ValidateSet('ParentEntitySearch', 'GlobalEntitySearch', ignorecase=$true)]
        [string] $SearchScope,

        [Parameter(Mandatory = $false, Position = 3)]
        [bool] $SyslogEnabled,

        [Parameter(Mandatory = $false, Position = 4)]
        [bool] $NetflowEnabled,

        [Parameter(Mandatory = $false, Position = 5)]
        [bool] $SflowEnabled,

        [Parameter(Mandatory = $false, Position = 6)]
        [switch] $PassThru,

        [Parameter(Mandatory = $false, Position = 7)]
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

        # Retrieve existing record for GET-then-merge
        $ExistingRecord = Get-LrAgentDetails -Id $Id
        if (($null -ne $ExistingRecord.Error) -and ($ExistingRecord.Error -eq $true)) {
            return $ExistingRecord
        }

        # Merge parameters
        if ($PSBoundParameters.ContainsKey('Name')) { $_name = $Name } else { $_name = $ExistingRecord.name }
        if ($PSBoundParameters.ContainsKey('SearchScope')) { $_searchScope = $SearchScope } else { $_searchScope = $ExistingRecord.searchScope }
        if ($PSBoundParameters.ContainsKey('SyslogEnabled')) { $_syslogEnabled = $SyslogEnabled } else { $_syslogEnabled = $ExistingRecord.syslogEnabled }
        if ($PSBoundParameters.ContainsKey('NetflowEnabled')) { $_netflowEnabled = $NetflowEnabled } else { $_netflowEnabled = $ExistingRecord.netflowEnabled }
        if ($PSBoundParameters.ContainsKey('SflowEnabled')) { $_sflowEnabled = $SflowEnabled } else { $_sflowEnabled = $ExistingRecord.sflowEnabled }

        $RequestUrl = $BaseUrl + "/lr-admin-api/agents/" + $Id + "/"
        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        $Body = [PSCustomObject]@{
            id             = $Id
            name           = $_name
            searchScope    = $_searchScope
            syslogEnabled  = $_syslogEnabled
            netflowEnabled = $_netflowEnabled
            sflowEnabled   = $_sflowEnabled
        }

        Write-Verbose "[$Me]: Request Body:`n$($Body | ConvertTo-Json)"

        $Response = Invoke-RestAPIMethod -Uri $RequestUrl -Headers $Headers -Method $Method -Body $($Body | ConvertTo-Json) -Origin $Me
        if (($null -ne $Response.Error) -and ($Response.Error -eq $true)) { return $Response }

        if ($PassThru) { return $Response }
    }

    End { }
}
