using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function Update-LrBeat {
    <#
    .SYNOPSIS
        Update a Beat in LogRhythm.
    .DESCRIPTION
        Update-LrBeat modifies a beat by submitting a PUT request to the
        LogRhythm Admin API. Note: beatName, openCollector, beatType,
        beatsTemplateId, lastHeartbeat, and dateCreated cannot be updated.
        Entity is auto-mapped from open collector; host from SystemMonitorId.
    .PARAMETER Id
        The Beat ID to update.
    .PARAMETER Description
        Updated description for the beat.
    .PARAMETER SystemMonitorId
        Updated system monitor (agent) ID for host mapping.
    .PARAMETER PassThru
        Switch parameter that will enable the return of the output object from the cmdlet.
    .PARAMETER Credential
        PSCredential containing an API Token in the Password field.
    .OUTPUTS
        Success: No Output.
        Error: PSCustomObject representing error details.
        PassThru: PSCustomObject representing the updated Beat.
    .EXAMPLE
        PS C:\> Update-LrBeat -Id 5 -Description "Updated syslog beat" -PassThru
        ---
        Updates the description of Beat 5 and returns the updated object.
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
        [string] $Description,


        [Parameter(Mandatory = $false, Position = 2)]
        [int32] $SystemMonitorId,


        [Parameter(Mandatory = $false, Position = 3)]
        [switch] $PassThru,


        [Parameter(Mandatory = $false, Position = 4)]
        [ValidateNotNull()]
        [pscredential] $Credential = $LrtConfig.LogRhythm.ApiKey
    )

    Begin {
        $Me = $MyInvocation.MyCommand.Name

        # Request Setup
        $BaseUrl = $LrtConfig.LogRhythm.BaseUrl
        $Token = $Credential.GetNetworkCredential().Password

        # Define HTTP Headers
        $Headers = [Dictionary[string,string]]::new()
        $Headers.Add("Authorization", "Bearer $Token")

        # Define HTTP Method
        $Method = $HttpMethod.Put

        # Check preference requirements for self-signed certificates and set enforcement for Tls1.2
        Enable-TrustAllCertsPolicy
    }

    Process {
        # Establish General Error object Output
        $ErrorObject = [PSCustomObject]@{
            Error                 =   $false
            Type                  =   $null
            Code                  =   $null
            Note                  =   $null
            Raw                   =   $null
        }

        # Verify version
        if ($LrtConfig.LogRhythm.Version -match '7\.[0-7]\.\d+') {
            $ErrorObject.Error = $true
            $ErrorObject.Code = "404"
            $ErrorObject.Type = "Cmdlet not supported."
            $ErrorObject.Note = "This cmdlet is available in LogRhythm version 7.8.0 and greater."
            return $ErrorObject
        }

        # Retrieve current beat to merge with updates
        $CurrentBeat = Get-LrBeat -Id $Id
        if (($null -ne $CurrentBeat.Error) -and ($CurrentBeat.Error -eq $true)) {
            return $CurrentBeat
        }

        # Request URL
        $RequestUrl = $BaseUrl + "/lr-admin-api/beats/" + $Id + "/"

        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        # Build request body from current beat, overriding with provided values
        $Body = [PSCustomObject]@{
            id          = $Id
            description = $(if ($PSBoundParameters.ContainsKey('Description')) { $Description } else { $CurrentBeat.description })
        }

        if ($PSBoundParameters.ContainsKey('SystemMonitorId')) {
            $Body | Add-Member -NotePropertyName beatToAgent -NotePropertyValue ([PSCustomObject]@{
                systemMonitorId = $SystemMonitorId
            })
        }

        Write-Verbose "[$Me]: Request Body:`n$($Body | ConvertTo-Json -Depth 5)"

        # Send Request
        $Response = Invoke-RestAPIMethod -Uri $RequestUrl -Headers $Headers -Method $Method -Body $($Body | ConvertTo-Json -Depth 5) -Origin $Me
        if (($null -ne $Response.Error) -and ($Response.Error -eq $true)) {
            return $Response
        }

        if ($PassThru) {
            return $Response
        }
    }

    End {
    }
}
