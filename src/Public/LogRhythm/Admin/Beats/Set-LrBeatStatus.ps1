using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function Set-LrBeatStatus {
    <#
    .SYNOPSIS
        Update the status of one or more Beats in LogRhythm.
    .DESCRIPTION
        Set-LrBeatStatus updates the status of beats based on the provided
        beat IDs by submitting a PATCH request to the LogRhythm Admin API.
    .PARAMETER Id
        One or more Beat IDs to update. Accepts pipeline input.
    .PARAMETER Status
        Target status for the beats. Valid values: Active, Retired.
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
        PS C:\> Set-LrBeatStatus -Id 5 -Status "Retired"
        ---
        Retires Beat ID 5.
    .EXAMPLE
        PS C:\> Set-LrBeatStatus -Id 5, 10, 15 -Status "Active" -PassThru
        ---
        Activates Beats 5, 10, and 15 and returns the response.
    .NOTES
        LogRhythm-API
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [int32[]] $Id,


        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateSet('Active','Retired', ignorecase=$true)]
        [string] $Status,


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
        $RequestUrl = $BaseUrl + "/lr-admin-api/beats/status/"

        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        # Request Body
        $Body = [PSCustomObject]@{
            beatIds          = $_ids.ToArray()
            recordStatusName = $Status
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
}
