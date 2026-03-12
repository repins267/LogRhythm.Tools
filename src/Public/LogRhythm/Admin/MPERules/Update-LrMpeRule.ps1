using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function Update-LrMpeRule {
    <#
    .SYNOPSIS
        Update a custom MPE Rule in LogRhythm.
    .DESCRIPTION
        Update-LrMpeRule modifies a custom MPE Rule by submitting a PUT request
        to the LogRhythm Admin API. Only custom MPE Rules can be edited.
    .PARAMETER Id
        The MPE Rule ID to update.
    .PARAMETER Name
        Updated name for the MPE Rule. Maximum 200 characters.
    .PARAMETER Description
        Updated description for the MPE Rule.
    .PARAMETER RuleContent
        Updated rule regex/definition content.
    .PARAMETER CommonEventId
        Updated common event ID.
    .PARAMETER SortOrder
        Updated sort order.
    .PARAMETER RuleGroup
        Updated rule group identifier.
    .PARAMETER DefMsgTTL
        Updated default message TTL.
    .PARAMETER PassThru
        Switch parameter that will enable the return of the output object from the cmdlet.
    .PARAMETER Credential
        PSCredential containing an API Token in the Password field.
    .OUTPUTS
        Success: No Output.
        Error: PSCustomObject representing error details.
        PassThru: PSCustomObject representing the updated LogRhythm MPE Rule.
    .EXAMPLE
        PS C:\> Update-LrMpeRule -Id 1001 -Name "Updated Rule Name" -PassThru
        ---
        Updates the name of MPE Rule 1001 and returns the updated object.
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
        [ValidateLength(1,200)]
        [string] $Name,


        [Parameter(Mandatory = $false, Position = 2)]
        [string] $Description,


        [Parameter(Mandatory = $false, Position = 3)]
        [string] $RuleContent,


        [Parameter(Mandatory = $false, Position = 4)]
        [int32] $CommonEventId,


        [Parameter(Mandatory = $false, Position = 5)]
        [int32] $SortOrder,


        [Parameter(Mandatory = $false, Position = 6)]
        [int32] $RuleGroup,


        [Parameter(Mandatory = $false, Position = 7)]
        [int32] $DefMsgTTL,


        [Parameter(Mandatory = $false, Position = 8)]
        [switch] $PassThru,


        [Parameter(Mandatory = $false, Position = 9)]
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

        # Retrieve current rule to merge with updates
        $CurrentRule = Get-LrMpeRule -Id $Id
        if (($null -ne $CurrentRule.Error) -and ($CurrentRule.Error -eq $true)) {
            return $CurrentRule
        }

        # Request URL
        $RequestUrl = $BaseUrl + "/lr-admin-api/mperules/" + $Id + "/"

        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        # Build request body from current rule, overriding with provided values
        $Body = [PSCustomObject]@{
            id            = $Id
            name          = $(if ($PSBoundParameters.ContainsKey('Name')) { $Name } else { $CurrentRule.name })
            description   = $(if ($PSBoundParameters.ContainsKey('Description')) { $Description } else { $CurrentRule.description })
            commonEventId = $(if ($PSBoundParameters.ContainsKey('CommonEventId')) { $CommonEventId } else { $CurrentRule.commonEventId })
            ruleContent   = $(if ($PSBoundParameters.ContainsKey('RuleContent')) { $RuleContent } else { $CurrentRule.ruleContent })
            sortOrder     = $(if ($PSBoundParameters.ContainsKey('SortOrder')) { $SortOrder } else { $CurrentRule.sortOrder })
            ruleGroup     = $(if ($PSBoundParameters.ContainsKey('RuleGroup')) { $RuleGroup } else { $CurrentRule.ruleGroup })
            defMsgTTL     = $(if ($PSBoundParameters.ContainsKey('DefMsgTTL')) { $DefMsgTTL } else { $CurrentRule.defMsgTTL })
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
