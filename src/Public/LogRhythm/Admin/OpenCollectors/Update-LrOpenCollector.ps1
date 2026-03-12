using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function Update-LrOpenCollector {
    <#
    .SYNOPSIS
        Update an Open Collector in LogRhythm.
    .DESCRIPTION
        Update-LrOpenCollector modifies an existing open collector by submitting
        a PUT request to the LogRhythm Admin API. Only the name can be updated.
        The entity cannot be changed and host information is ignored.
    .PARAMETER Id
        The Open Collector ID to update.
    .PARAMETER Name
        Updated name for the open collector.
    .PARAMETER PassThru
        Switch parameter that will enable the return of the output object from the cmdlet.
    .PARAMETER Credential
        PSCredential containing an API Token in the Password field.
    .OUTPUTS
        Success: No Output.
        Error: PSCustomObject representing error details.
        PassThru: PSCustomObject representing the updated Open Collector.
    .EXAMPLE
        PS C:\> Update-LrOpenCollector -Id 5 -Name "OC-Linux-Updated" -PassThru
        ---
        Updates the name of Open Collector 5 and returns the updated object.
    .NOTES
        LogRhythm-API
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [int32] $Id,


        [Parameter(Mandatory = $true, Position = 1)]
        [string] $Name,


        [Parameter(Mandatory = $false, Position = 2)]
        [switch] $PassThru,


        [Parameter(Mandatory = $false, Position = 3)]
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

        # Request URL
        $RequestUrl = $BaseUrl + "/lr-admin-api/openCollectors/" + $Id + "/"

        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        # Request Body
        $Body = [PSCustomObject]@{
            id   = $Id
            name = $Name
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
