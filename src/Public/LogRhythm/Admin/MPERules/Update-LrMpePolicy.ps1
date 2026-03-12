using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function Update-LrMpePolicy {
    <#
    .SYNOPSIS
        Update an existing MPE Policy in LogRhythm.
    .DESCRIPTION
        Update-LrMpePolicy modifies an MPE Policy by submitting a PUT request
        to the LogRhythm Admin API. For System MPE policies, only the RuleTimeout
        field is allowed to be updated. The messageSourceTypeId field is non-editable.
    .PARAMETER Id
        The MPE Policy ID to update.
    .PARAMETER Name
        Updated name for the MPE Policy.
    .PARAMETER Description
        Updated description for the MPE Policy.
    .PARAMETER RuleTimeout
        Updated rule timeout value in seconds.
    .PARAMETER RecordStatus
        Updated record status. Valid values: Active, Retired.
    .PARAMETER PassThru
        Switch parameter that will enable the return of the output object from the cmdlet.
    .PARAMETER Credential
        PSCredential containing an API Token in the Password field.
    .OUTPUTS
        Success: No Output.
        Error: PSCustomObject representing error details.
        PassThru: PSCustomObject representing the updated LogRhythm MPE Policy.
    .EXAMPLE
        PS C:\> Update-LrMpePolicy -Id 5 -Name "Updated Policy Name" -PassThru
        ---
        Updates the name of MPE Policy 5 and returns the updated object.
    .EXAMPLE
        PS C:\> Update-LrMpePolicy -Id 5 -RuleTimeout 60
        ---
        Updates the rule timeout of MPE Policy 5 to 60 seconds.
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
        [string] $Name,


        [Parameter(Mandatory = $false, Position = 2)]
        [string] $Description,


        [Parameter(Mandatory = $false, Position = 3)]
        [int32] $RuleTimeout,


        [Parameter(Mandatory = $false, Position = 4)]
        [ValidateSet('Active','Retired', ignorecase=$true)]
        [string] $RecordStatus,


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

        # Retrieve current policy to merge with updates
        $CurrentPolicy = Get-LrMpePolicy -Id $Id
        if (($null -ne $CurrentPolicy.Error) -and ($CurrentPolicy.Error -eq $true)) {
            return $CurrentPolicy
        }

        # Request URL
        $RequestUrl = $BaseUrl + "/lr-admin-api/mpepolicies/" + $Id + "/"

        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        # Build request body from current policy, overriding with provided values
        $Body = [PSCustomObject]@{
            id               = $Id
            name             = $(if ($PSBoundParameters.ContainsKey('Name')) { $Name } else { $CurrentPolicy.name })
            description      = $(if ($PSBoundParameters.ContainsKey('Description')) { $Description } else { $CurrentPolicy.description })
            ruleTimeout      = $(if ($PSBoundParameters.ContainsKey('RuleTimeout')) { $RuleTimeout } else { $CurrentPolicy.ruleTimeout })
            recordStatusName = $(if ($PSBoundParameters.ContainsKey('RecordStatus')) { $RecordStatus } else { $CurrentPolicy.recordStatusName })
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
