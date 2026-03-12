using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function Update-LrLsvTemplateItem {
    <#
    .SYNOPSIS
        Update an item in a Log Source Virtualization template.
    .DESCRIPTION
        Update-LrLsvTemplateItem modifies an existing LSV template item
        by submitting a PUT request to the LogRhythm Admin API.
    .PARAMETER TemplateId
        The LSV Template ID containing the item.
    .PARAMETER ItemId
        The LSV Template Item ID to update.
    .PARAMETER Name
        Updated name for the template item.
    .PARAMETER SortOrder
        Updated sort order.
    .PARAMETER Description
        Updated description.
    .PARAMETER PassThru
        Switch parameter that will enable the return of the output object from the cmdlet.
    .PARAMETER Credential
        PSCredential containing an API Token in the Password field.
    .OUTPUTS
        Success: No Output.
        Error: PSCustomObject representing error details.
        PassThru: PSCustomObject representing the updated LSV Template Item.
    .EXAMPLE
        PS C:\> Update-LrLsvTemplateItem -TemplateId 5 -ItemId 10 -Name "Updated Item" -PassThru
        ---
        Updates the name of item 10 in LSV Template 5.
    .NOTES
        LogRhythm-API
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [int32] $TemplateId,


        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 1)]
        [int32] $ItemId,


        [Parameter(Mandatory = $false, Position = 2)]
        [string] $Name,


        [Parameter(Mandatory = $false, Position = 3)]
        [int32] $SortOrder,


        [Parameter(Mandatory = $false, Position = 4)]
        [string] $Description,


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
        if ($LrtConfig.LogRhythm.Version -match '7\.[0-7]\.\d+') {
            $ErrorObject.Error = $true
            $ErrorObject.Code = "404"
            $ErrorObject.Type = "Cmdlet not supported."
            $ErrorObject.Note = "This cmdlet is available in LogRhythm version 7.8.0 and greater."
            return $ErrorObject
        }

        # Request URL
        $RequestUrl = $BaseUrl + "/lr-admin-api/lsvtemplates/" + $TemplateId + "/lsvtemplateitems/" + $ItemId + "/"

        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        # Build request body with provided fields
        $Body = [PSCustomObject]@{
            id = $ItemId
        }

        if ($PSBoundParameters.ContainsKey('Name')) {
            $Body | Add-Member -NotePropertyName name -NotePropertyValue $Name
        }
        if ($PSBoundParameters.ContainsKey('SortOrder')) {
            $Body | Add-Member -NotePropertyName sortOrder -NotePropertyValue $SortOrder
        }
        if ($PSBoundParameters.ContainsKey('Description')) {
            $Body | Add-Member -NotePropertyName description -NotePropertyValue $Description
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
