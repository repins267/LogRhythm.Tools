using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function Approve-LrLogSourcePending {
    <#
    .SYNOPSIS
        Accept a Pending Log Source in LogRhythm.
    .DESCRIPTION
        Approve-LrLogSourcePending accepts a single pending log source by ID.
    .PARAMETER Id
        The pending log source ID to accept.
    .PARAMETER PassThru
        Switch parameter that will enable the return of the output object from the cmdlet.
    .PARAMETER Credential
        PSCredential containing an API Token in the Password field.
    .OUTPUTS
        Success: No Output.
        Error: PSCustomObject representing error details.
        PassThru: PSCustomObject representing the accepted log source.
    .EXAMPLE
        PS C:\> Approve-LrLogSourcePending -Id 110 -PassThru
        ---
        Accepts pending log source 110 and returns the result.
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
        [switch] $PassThru,


        [Parameter(Mandatory = $false, Position = 2)]
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
        if ($LrtConfig.LogRhythm.Version -match '7\.[0-4]\.\d+') {
            $ErrorObject.Error = $true
            $ErrorObject.Code = "404"
            $ErrorObject.Type = "Cmdlet not supported."
            $ErrorObject.Note = "This cmdlet is available in LogRhythm version 7.5.0 and greater."
            return $ErrorObject
        }

        # Request URL
        $RequestUrl = $BaseUrl + "/lr-admin-api/logsources-request/" + $Id + "/accept/"

        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        # Send Request
        $Response = Invoke-RestAPIMethod -Uri $RequestUrl -Headers $Headers -Method $Method -Origin $Me
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
