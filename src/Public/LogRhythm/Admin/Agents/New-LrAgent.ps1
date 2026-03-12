using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function New-LrAgent {
    <#
    .SYNOPSIS
        Create a new agent record in the LogRhythm Admin API.
    .DESCRIPTION
        New-LrAgent creates a System Monitor agent record via the Admin API.
    .PARAMETER Name
        The name of the agent.
    .PARAMETER HostId
        The host ID to associate the agent with.
    .PARAMETER AgentType
        The type of agent. Valid entries: "Windows", "Linux", "Solaris", "AIX", "HPUX", "Flat File".
    .PARAMETER EntityId
        The entity ID for the agent.
    .PARAMETER SearchScope
        The search scope for the agent. Valid entries: "ParentEntitySearch",
        "GlobalEntitySearch".
    .PARAMETER SyslogEnabled
        Enable syslog server on the agent.
    .PARAMETER NetflowEnabled
        Enable netflow server on the agent.
    .PARAMETER SflowEnabled
        Enable sflow server on the agent.
    .PARAMETER PassThru
        Switch parameter that will enable the return of the output object from the cmdlet.
    .PARAMETER Credential
        PSCredential containing an API Token in the Password field.
    .OUTPUTS
        Success: No Output.
        PassThru: PSCustomObject representing the newly created agent.
    .EXAMPLE
        PS C:\> New-LrAgent -Name "NewAgent01" -HostId 2 -AgentType "Windows" -EntityId 1 -PassThru
    .NOTES
        LogRhythm-API
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $Name,

        [Parameter(Mandatory = $true, Position = 1)]
        [int32] $HostId,

        [Parameter(Mandatory = $true, Position = 2)]
        [ValidateSet(
            'Windows', 'Linux', 'Solaris', 'AIX', 'HPUX', 'Flat File',
            ignorecase=$true
        )]
        [string] $AgentType,

        [Parameter(Mandatory = $true, Position = 3)]
        [int32] $EntityId,

        [Parameter(Mandatory = $false, Position = 4)]
        [ValidateSet('ParentEntitySearch', 'GlobalEntitySearch', ignorecase=$true)]
        [string] $SearchScope = "ParentEntitySearch",

        [Parameter(Mandatory = $false, Position = 5)]
        [bool] $SyslogEnabled = $false,

        [Parameter(Mandatory = $false, Position = 6)]
        [bool] $NetflowEnabled = $false,

        [Parameter(Mandatory = $false, Position = 7)]
        [bool] $SflowEnabled = $false,

        [Parameter(Mandatory = $false, Position = 8)]
        [switch] $PassThru,

        [Parameter(Mandatory = $false, Position = 9)]
        [ValidateNotNull()]
        [pscredential] $Credential = $LrtConfig.LogRhythm.ApiKey
    )

    Begin {
        $Me = $MyInvocation.MyCommand.Name
        $BaseUrl = $LrtConfig.LogRhythm.BaseUrl
        $Token = $Credential.GetNetworkCredential().Password
        $Headers = [Dictionary[string,string]]::new()
        $Headers.Add("Authorization", "Bearer $Token")
        $Method = $HttpMethod.Post
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

        $RequestUrl = $BaseUrl + "/lr-admin-api/agents/"
        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        $Body = [PSCustomObject]@{
            name           = $Name
            hostId         = $HostId
            agentType      = $AgentType
            entityId       = $EntityId
            searchScope    = $SearchScope
            syslogEnabled  = $SyslogEnabled
            netflowEnabled = $NetflowEnabled
            sflowEnabled   = $SflowEnabled
        }

        Write-Verbose "[$Me]: Request Body:`n$($Body | ConvertTo-Json)"

        $Response = Invoke-RestAPIMethod -Uri $RequestUrl -Headers $Headers -Method $Method -Body $($Body | ConvertTo-Json) -Origin $Me
        if (($null -ne $Response.Error) -and ($Response.Error -eq $true)) { return $Response }

        if ($PassThru) { return $Response }
    }

    End { }
}
