using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function New-LrOpenCollector {
    <#
    .SYNOPSIS
        Create a new Open Collector in LogRhythm.
    .DESCRIPTION
        New-LrOpenCollector creates a new open collector by submitting a POST
        request to the LogRhythm Admin API. If an open collector already exists
        on the given host and entity, the existing record is returned.
    .PARAMETER Name
        The name of the new open collector.
    .PARAMETER HostId
        The host ID to associate with the open collector.
    .PARAMETER EntityId
        The entity ID to associate with the open collector.
    .PARAMETER Description
        Optional description for the open collector.
    .PARAMETER PassThru
        Switch parameter that will enable the return of the output object from the cmdlet.
    .PARAMETER Credential
        PSCredential containing an API Token in the Password field.
    .OUTPUTS
        Success: No Output.
        Error: PSCustomObject representing error details.
        PassThru: PSCustomObject representing the newly created Open Collector.
    .EXAMPLE
        PS C:\> New-LrOpenCollector -Name "OC-Linux-01" -HostId 10 -EntityId 1 -PassThru
        ---
        Creates a new open collector and returns the created object.
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
        [int32] $EntityId,


        [Parameter(Mandatory = $false, Position = 3)]
        [string] $Description,


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
        if ($LrtConfig.LogRhythm.Version -match '7\.[0-7]\.\d+') {
            $ErrorObject.Error = $true
            $ErrorObject.Code = "404"
            $ErrorObject.Type = "Cmdlet not supported."
            $ErrorObject.Note = "This cmdlet is available in LogRhythm version 7.8.0 and greater."
            return $ErrorObject
        }

        # Request URL
        $RequestUrl = $BaseUrl + "/lr-admin-api/openCollectors/"

        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        # Request Body
        $Body = [PSCustomObject]@{
            name        = $Name
            host        = [PSCustomObject]@{
                id = $HostId
            }
            entity      = [PSCustomObject]@{
                id = $EntityId
            }
            description = $(if ($Description) { $Description } else { "" })
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
