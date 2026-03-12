using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function New-LrMpePolicy {
    <#
    .SYNOPSIS
        Create a new MPE Policy in LogRhythm.
    .DESCRIPTION
        New-LrMpePolicy creates a new MPE Policy by submitting a POST request
        to the LogRhythm Admin API.
    .PARAMETER Name
        The name of the new MPE Policy.
    .PARAMETER MessageSourceTypeId
        The message source type ID to associate with the MPE Policy.
    .PARAMETER Description
        Optional description for the MPE Policy.
    .PARAMETER RuleTimeout
        Optional rule timeout value in seconds. Defaults to 0.
    .PARAMETER PassThru
        Switch parameter that will enable the return of the output object from the cmdlet.
    .PARAMETER Credential
        PSCredential containing an API Token in the Password field.
    .OUTPUTS
        Success: No Output.
        Error: PSCustomObject representing error details.
        PassThru: PSCustomObject representing the newly created LogRhythm MPE Policy.
    .EXAMPLE
        PS C:\> New-LrMpePolicy -Name "Custom Syslog Policy" -MessageSourceTypeId 1001 -PassThru
        ---
        Creates a new MPE Policy and returns the created policy object.
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
        [int32] $MessageSourceTypeId,


        [Parameter(Mandatory = $false, Position = 2)]
        [string] $Description,


        [Parameter(Mandatory = $false, Position = 3)]
        [int32] $RuleTimeout = 0,


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
        $RequestUrl = $BaseUrl + "/lr-admin-api/mpepolicies/"

        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        # Request Body
        $Body = [PSCustomObject]@{
            id                  = -1
            name                = $Name
            description         = $(if ($Description) { $Description } else { "" })
            messageSourceTypeId = $MessageSourceTypeId
            ruleTimeout         = $RuleTimeout
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
