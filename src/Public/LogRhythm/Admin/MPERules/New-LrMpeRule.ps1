using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function New-LrMpeRule {
    <#
    .SYNOPSIS
        Create a new custom MPE Rule in LogRhythm.
    .DESCRIPTION
        New-LrMpeRule creates a new MPE Rule by submitting a POST request
        to the LogRhythm Admin API.
    .PARAMETER Name
        The name of the new MPE Rule. Maximum 200 characters.
    .PARAMETER CommonEventId
        The common event ID to associate with the MPE Rule.
    .PARAMETER Description
        Optional description for the MPE Rule.
    .PARAMETER RuleContent
        The rule regex/definition content.
    .PARAMETER SortOrder
        Sort order for the rule. Defaults to 0.
    .PARAMETER RuleGroup
        Rule group identifier. Defaults to 0.
    .PARAMETER DefMsgTTL
        Default message TTL. Defaults to 0.
    .PARAMETER PassThru
        Switch parameter that will enable the return of the output object from the cmdlet.
    .PARAMETER Credential
        PSCredential containing an API Token in the Password field.
    .OUTPUTS
        Success: No Output.
        Error: PSCustomObject representing error details.
        PassThru: PSCustomObject representing the newly created LogRhythm MPE Rule.
    .EXAMPLE
        PS C:\> New-LrMpeRule -Name "Custom Syslog Rule" -CommonEventId 1000 -PassThru
        ---
        Creates a new MPE Rule and returns the created rule object.
    .NOTES
        LogRhythm-API
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateLength(1,200)]
        [string] $Name,


        [Parameter(Mandatory = $true, Position = 1)]
        [int32] $CommonEventId,


        [Parameter(Mandatory = $false, Position = 2)]
        [string] $Description,


        [Parameter(Mandatory = $false, Position = 3)]
        [string] $RuleContent,


        [Parameter(Mandatory = $false, Position = 4)]
        [int32] $SortOrder = 0,


        [Parameter(Mandatory = $false, Position = 5)]
        [int32] $RuleGroup = 0,


        [Parameter(Mandatory = $false, Position = 6)]
        [int32] $DefMsgTTL = 0,


        [Parameter(Mandatory = $false, Position = 7)]
        [switch] $PassThru,


        [Parameter(Mandatory = $false, Position = 8)]
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
        $RequestUrl = $BaseUrl + "/lr-admin-api/mperules/"

        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        # Request Body
        $Body = [PSCustomObject]@{
            id            = -1
            name          = $Name
            commonEventId = $CommonEventId
            description   = $(if ($Description) { $Description } else { "" })
            ruleContent   = $(if ($RuleContent) { $RuleContent } else { "" })
            sortOrder     = $SortOrder
            ruleGroup     = $RuleGroup
            defMsgTTL     = $DefMsgTTL
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
