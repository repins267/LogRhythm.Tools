using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function Update-LrMpePolicyRule {
    <#
    .SYNOPSIS
        Update an MPE Rule within an MPE Policy context.
    .DESCRIPTION
        Update-LrMpePolicyRule modifies an MPE Rule's settings within a specific
        MPE Policy by submitting a PUT request to the LogRhythm Admin API.
        The MPE Rule ID in the path takes precedence for the update operation.
    .PARAMETER PolicyId
        The MPE Policy ID containing the rule.
    .PARAMETER RuleId
        The MPE Rule ID to update within the policy.
    .PARAMETER SortOrder
        Updated sort order for the rule within the policy.
    .PARAMETER Enabled
        Whether the rule is enabled within the policy context.
    .PARAMETER DefMsgTTL
        Updated default message TTL override.
    .PARAMETER PassThru
        Switch parameter that will enable the return of the output object from the cmdlet.
    .PARAMETER Credential
        PSCredential containing an API Token in the Password field.
    .OUTPUTS
        Success: No Output.
        Error: PSCustomObject representing error details.
        PassThru: PSCustomObject representing the updated MPE Rule within the policy.
    .EXAMPLE
        PS C:\> Update-LrMpePolicyRule -PolicyId 5 -RuleId 1001 -SortOrder 10 -PassThru
        ---
        Updates the sort order of MPE Rule 1001 in Policy 5 and returns the response.
    .EXAMPLE
        PS C:\> Update-LrMpePolicyRule -PolicyId 5 -RuleId 1001 -Enabled $false
        ---
        Disables MPE Rule 1001 within Policy 5.
    .NOTES
        LogRhythm-API
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [int32] $PolicyId,


        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 1)]
        [int32] $RuleId,


        [Parameter(Mandatory = $false, Position = 2)]
        [int32] $SortOrder,


        [Parameter(Mandatory = $false, Position = 3)]
        [bool] $Enabled,


        [Parameter(Mandatory = $false, Position = 4)]
        [int32] $DefMsgTTL,


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

        # Request URL
        $RequestUrl = $BaseUrl + "/lr-admin-api/mpepolicies/" + $PolicyId + "/mperules/" + $RuleId + "/"

        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        # Build request body with only provided fields
        $Body = [PSCustomObject]@{
            mpeRuleId = $RuleId
        }

        if ($PSBoundParameters.ContainsKey('SortOrder')) {
            $Body | Add-Member -NotePropertyName sortOrder -NotePropertyValue $SortOrder
        }
        if ($PSBoundParameters.ContainsKey('Enabled')) {
            $Body | Add-Member -NotePropertyName enabled -NotePropertyValue $Enabled
        }
        if ($PSBoundParameters.ContainsKey('DefMsgTTL')) {
            $Body | Add-Member -NotePropertyName defMsgTTL -NotePropertyValue $DefMsgTTL
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
