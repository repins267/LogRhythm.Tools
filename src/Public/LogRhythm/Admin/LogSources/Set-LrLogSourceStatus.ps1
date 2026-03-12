using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function Set-LrLogSourceStatus {
    <#
    .SYNOPSIS
        Change the status of one or more Log Sources in LogRhythm.
    .DESCRIPTION
        Set-LrLogSourceStatus updates the status of log sources by submitting
        a PUT request with an array of log source IDs and the target status.
    .PARAMETER Id
        One or more log source IDs to update. Accepts pipeline input.
    .PARAMETER Status
        Target status. Valid values: Active, Retired.
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
        PS C:\> Set-LrLogSourceStatus -Id 100, 101 -Status "Retired"
        ---
        Retires log sources 100 and 101.
    .EXAMPLE
        PS C:\> Set-LrLogSourceStatus -Id 100 -Status "Active" -PassThru
        ---
        Activates log source 100 and returns the response.
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
        $Method = $HttpMethod.Put

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
        if ($LrtConfig.LogRhythm.Version -match '7\.[0-4]\.\d+') {
            $ErrorObject.Error = $true
            $ErrorObject.Code = "404"
            $ErrorObject.Type = "Cmdlet not supported."
            $ErrorObject.Note = "This cmdlet is available in LogRhythm version 7.5.0 and greater."
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
        $RequestUrl = $BaseUrl + "/lr-admin-api/logsources/status/"

        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        # Request Body
        $Body = [PSCustomObject]@{
            logSourceIds     = $_ids.ToArray()
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
