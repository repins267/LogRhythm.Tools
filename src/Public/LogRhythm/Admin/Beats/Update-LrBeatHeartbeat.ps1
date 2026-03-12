using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function Update-LrBeatHeartbeat {
    <#
    .SYNOPSIS
        Update the heartbeat timestamp for one or more Beats in LogRhythm.
    .DESCRIPTION
        Update-LrBeatHeartbeat updates the heartbeat and dateUpdated of
        multiple beats based on the provided beat IDs. Non-existing or
        retired beat IDs will not be updated.
    .PARAMETER Id
        One or more Beat IDs to update heartbeat for. Accepts pipeline input.
    .PARAMETER PassThru
        Switch parameter that will enable the return of the output object from the cmdlet.
    .PARAMETER Credential
        PSCredential containing an API Token in the Password field.
    .INPUTS
        [System.Int32[]] -> Id
    .OUTPUTS
        Success: No Output.
        Error: PSCustomObject representing error details.
        PassThru: PSCustomObject representing the API response.
    .EXAMPLE
        PS C:\> Update-LrBeatHeartbeat -Id 5, 10
        ---
        Updates the heartbeat for Beats 5 and 10.
    .NOTES
        LogRhythm-API
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [int32[]] $Id,


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
        $Method = $HttpMethod.Patch

        # Check preference requirements for self-signed certificates and set enforcement for Tls1.2
        Enable-TrustAllCertsPolicy

        # Collect IDs for pipeline support
        $_ids = [list[int32]]::new()
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

        # Collect IDs from pipeline
        foreach ($_id in $Id) {
            $_ids.Add($_id)
        }
    }

    End {
        if ($_ids.Count -eq 0) {
            return
        }

        # Request URL
        $RequestUrl = $BaseUrl + "/lr-admin-api/beats/heartBeat/"

        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        # Request Body - array of beat IDs
        $Body = $_ids | ConvertTo-Json
        if ($_ids.Count -eq 1) {
            $Body = "[$Body]"
        }

        Write-Verbose "[$Me]: Request Body:`n$Body"

        # Send Request
        $Response = Invoke-RestAPIMethod -Uri $RequestUrl -Headers $Headers -Method $Method -Body $Body -Origin $Me
        if (($null -ne $Response.Error) -and ($Response.Error -eq $true)) {
            return $Response
        }

        if ($PassThru) {
            return $Response
        }
    }
}
