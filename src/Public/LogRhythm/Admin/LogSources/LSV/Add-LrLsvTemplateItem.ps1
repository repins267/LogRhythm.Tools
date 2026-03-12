using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function Add-LrLsvTemplateItem {
    <#
    .SYNOPSIS
        Create a new item in a Log Source Virtualization template.
    .DESCRIPTION
        Add-LrLsvTemplateItem creates a new LSV template item by submitting
        a POST request. The item defines a virtual log source regex pattern
        within the specified template.
    .PARAMETER TemplateId
        The LSV Template ID to add the item to.
    .PARAMETER Name
        The name of the new template item.
    .PARAMETER SortOrder
        Sort order for the item within the template.
    .PARAMETER Description
        Optional description for the template item.
    .PARAMETER PassThru
        Switch parameter that will enable the return of the output object from the cmdlet.
    .PARAMETER Credential
        PSCredential containing an API Token in the Password field.
    .OUTPUTS
        Success: No Output.
        Error: PSCustomObject representing error details.
        PassThru: PSCustomObject representing the newly created LSV Template Item.
    .EXAMPLE
        PS C:\> Add-LrLsvTemplateItem -TemplateId 5 -Name "Firewall-01" -SortOrder 1 -PassThru
        ---
        Creates a new item in LSV Template 5 and returns the created object.
    .NOTES
        LogRhythm-API
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [int32] $TemplateId,


        [Parameter(Mandatory = $true, Position = 1)]
        [string] $Name,


        [Parameter(Mandatory = $true, Position = 2)]
        [int32] $SortOrder,


        [Parameter(Mandatory = $false, Position = 3)]
        [string] $Description,


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
        if ($LrtConfig.LogRhythm.Version -match '7\.[0-7]\.\d+') {
            $ErrorObject.Error = $true
            $ErrorObject.Code = "404"
            $ErrorObject.Type = "Cmdlet not supported."
            $ErrorObject.Note = "This cmdlet is available in LogRhythm version 7.8.0 and greater."
            return $ErrorObject
        }

        # Request URL
        $RequestUrl = $BaseUrl + "/lr-admin-api/lsvtemplates/" + $TemplateId + "/lsvtemplateitems/"

        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        # Request Body
        $Body = [PSCustomObject]@{
            id          = -1
            name        = $Name
            sortOrder   = $SortOrder
            description = $(if ($Description) { $Description } else { "" })
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
