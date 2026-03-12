using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function Update-LrLsvTemplate {
    <#
    .SYNOPSIS
        Update a Log Source Virtualization template in LogRhythm.
    .DESCRIPTION
        Update-LrLsvTemplate modifies an LSV template's name and description
        by submitting a PUT request to the LogRhythm Admin API.
    .PARAMETER Id
        The LSV Template ID to update.
    .PARAMETER Name
        Updated name for the LSV template.
    .PARAMETER ShortDesc
        Updated short description.
    .PARAMETER LongDesc
        Updated long description.
    .PARAMETER PassThru
        Switch parameter that will enable the return of the output object from the cmdlet.
    .PARAMETER Credential
        PSCredential containing an API Token in the Password field.
    .OUTPUTS
        Success: No Output.
        Error: PSCustomObject representing error details.
        PassThru: PSCustomObject representing the updated LSV Template.
    .EXAMPLE
        PS C:\> Update-LrLsvTemplate -Id 5 -Name "Updated Template" -PassThru
        ---
        Updates the name of LSV Template 5 and returns the updated object.
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
        [string] $ShortDesc,


        [Parameter(Mandatory = $false, Position = 3)]
        [string] $LongDesc,


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

        # Retrieve current template to merge with updates
        $CurrentTemplate = Get-LrLsvTemplate -Id $Id
        if (($null -ne $CurrentTemplate.Error) -and ($CurrentTemplate.Error -eq $true)) {
            return $CurrentTemplate
        }

        # Request URL
        $RequestUrl = $BaseUrl + "/lr-admin-api/lsvtemplates/" + $Id + "/"

        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        # Build request body from current template, overriding with provided values
        $Body = [PSCustomObject]@{
            id        = $Id
            name      = $(if ($PSBoundParameters.ContainsKey('Name')) { $Name } else { $CurrentTemplate.name })
            shortDesc = $(if ($PSBoundParameters.ContainsKey('ShortDesc')) { $ShortDesc } else { $CurrentTemplate.shortDesc })
            longDesc  = $(if ($PSBoundParameters.ContainsKey('LongDesc')) { $LongDesc } else { $CurrentTemplate.longDesc })
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
