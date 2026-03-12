using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function New-LrLogSourcePending {
    <#
    .SYNOPSIS
        Create a new Pending Log Source in LogRhythm.
    .DESCRIPTION
        New-LrLogSourcePending creates a pending log source record by submitting
        a POST request to the LogRhythm Admin API.
    .PARAMETER Name
        The name of the pending log source.
    .PARAMETER SystemMonitorId
        The system monitor (agent) ID associated with the pending log source.
    .PARAMETER Ip
        Optional IP address for the pending log source.
    .PARAMETER LogInterfaceType
        The log interface type. Common values: Syslog, Flat File, etc.
    .PARAMETER PassThru
        Switch parameter that will enable the return of the output object from the cmdlet.
    .PARAMETER Credential
        PSCredential containing an API Token in the Password field.
    .OUTPUTS
        Success: No Output.
        Error: PSCustomObject representing error details.
        PassThru: PSCustomObject representing the newly created pending log source.
    .EXAMPLE
        PS C:\> New-LrLogSourcePending -Name "10.0.0.1" -SystemMonitorId 4 -Ip "10.0.0.1" -PassThru
        ---
        Creates a new pending log source and returns the created object.
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
        [int32] $SystemMonitorId,


        [Parameter(Mandatory = $false, Position = 2)]
        [string] $Ip,


        [Parameter(Mandatory = $false, Position = 3)]
        [string] $LogInterfaceType,


        [Parameter(Mandatory = $false, Position = 4)]
        [switch] $PassThru,


        [Parameter(Mandatory = $false, Position = 5)]
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
        if ($LrtConfig.LogRhythm.Version -match '7\.[0-4]\.\d+') {
            $ErrorObject.Error = $true
            $ErrorObject.Code = "404"
            $ErrorObject.Type = "Cmdlet not supported."
            $ErrorObject.Note = "This cmdlet is available in LogRhythm version 7.5.0 and greater."
            return $ErrorObject
        }

        # Request URL
        $RequestUrl = $BaseUrl + "/lr-admin-api/logsources/pending/"

        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        # Request Body
        $Body = [PSCustomObject]@{
            name            = $Name
            systemMonitorId = $SystemMonitorId
        }

        if ($Ip) {
            $Body | Add-Member -NotePropertyName ip -NotePropertyValue $Ip
        }
        if ($LogInterfaceType) {
            $Body | Add-Member -NotePropertyName logInterfaceType -NotePropertyValue $LogInterfaceType
        }

        Write-Verbose "[$Me]: Request Body:`n$($Body | ConvertTo-Json)"

        # Send Request
        $Response = Invoke-RestAPIMethod -Uri $RequestUrl -Headers $Headers -Method $Method -Body $($Body | ConvertTo-Json) -Origin $Me
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
