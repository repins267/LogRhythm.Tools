using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function Remove-LrLsvAssociations {
    <#
    .SYNOPSIS
        Dissociate LSV items from a Log Source Virtualization template.
    .DESCRIPTION
        Remove-LrLsvAssociations removes associated log source virtualization
        items from an LSV template by submitting a DELETE request.
    .PARAMETER TemplateId
        The LSV Template ID to dissociate items from.
    .PARAMETER ItemId
        One or more LSV item IDs to dissociate from the template.
    .PARAMETER PassThru
        Switch parameter that will enable the return of the output object from the cmdlet.
    .PARAMETER Credential
        PSCredential containing an API Token in the Password field.
    .INPUTS
        [System.Int32[]] -> ItemId
    .OUTPUTS
        Success: No Output.
        Error: PSCustomObject representing error details.
        PassThru: PSCustomObject representing the API response.
    .EXAMPLE
        PS C:\> Remove-LrLsvAssociations -TemplateId 5 -ItemId 10, 11
        ---
        Dissociates items 10 and 11 from LSV Template 5.
    .NOTES
        LogRhythm-API
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, Position = 0)]
        [int32] $TemplateId,


        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 1)]
        [int32[]] $ItemId,


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
        $Method = $HttpMethod.Delete

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
        foreach ($_id in $ItemId) {
            $_ids.Add($_id)
        }
    }

    End {
        if ($_ids.Count -eq 0) {
            return
        }

        # Request URL
        $RequestUrl = $BaseUrl + "/lr-admin-api/lsvtemplates/" + $TemplateId + "/lsvtemplateitems/"

        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        # Request Body - array of IDs
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
