using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function New-LrBeat {
    <#
    .SYNOPSIS
        Create a new Beat in LogRhythm.
    .DESCRIPTION
        New-LrBeat creates a new beat by submitting a POST request to the
        LogRhythm Admin API. The beatsTemplateId is automatically fetched
        based on the BeatTypeId. Entity is automatically mapped based on
        the open collector, and host is mapped based on SystemMonitorId.
    .PARAMETER Name
        The name of the new beat.
    .PARAMETER BeatTypeId
        The beat type ID. Use Get-LrBeatTypes to retrieve valid values.
    .PARAMETER OpenCollectorId
        The open collector ID to associate with the beat.
    .PARAMETER SystemMonitorId
        The system monitor (agent) ID for host mapping.
    .PARAMETER Description
        Optional description for the beat.
    .PARAMETER PassThru
        Switch parameter that will enable the return of the output object from the cmdlet.
    .PARAMETER Credential
        PSCredential containing an API Token in the Password field.
    .OUTPUTS
        Success: No Output.
        Error: PSCustomObject representing error details.
        PassThru: PSCustomObject representing the newly created Beat.
    .EXAMPLE
        PS C:\> New-LrBeat -Name "Syslog Beat" -BeatTypeId 1 -OpenCollectorId 10 -SystemMonitorId 5 -PassThru
        ---
        Creates a new beat and returns the created object.
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
        [int32] $BeatTypeId,


        [Parameter(Mandatory = $true, Position = 2)]
        [int32] $OpenCollectorId,


        [Parameter(Mandatory = $true, Position = 3)]
        [int32] $SystemMonitorId,


        [Parameter(Mandatory = $false, Position = 4)]
        [string] $Description,


        [Parameter(Mandatory = $false, Position = 5)]
        [switch] $PassThru,


        [Parameter(Mandatory = $false, Position = 6)]
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
        $Method = $HttpMethod.Post

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

        # Request URL
        $RequestUrl = $BaseUrl + "/lr-admin-api/beats/"

        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        # Request Body
        $Body = [PSCustomObject]@{
            id              = -1
            beatName        = $Name
            beatTypeId      = $BeatTypeId
            openCollectorId = $OpenCollectorId
            beatToAgent     = [PSCustomObject]@{
                systemMonitorId = $SystemMonitorId
            }
            description     = $(if ($Description) { $Description } else { "" })
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
