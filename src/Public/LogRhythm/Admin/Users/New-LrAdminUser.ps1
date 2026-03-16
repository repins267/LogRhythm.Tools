using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function New-LrAdminUser {
    <#
    .SYNOPSIS
        Create a new person in the LogRhythm Admin API.
    .DESCRIPTION
        New-LrAdminUser creates a person record via the Admin API persons endpoint.
    .PARAMETER FirstName
        First name of the person.
    .PARAMETER LastName
        Last name of the person.
    .PARAMETER Title
        Optional title for the person.
    .PARAMETER Department
        Optional department for the person.
    .PARAMETER Company
        Optional company for the person.
    .PARAMETER PassThru
        Switch parameter that will enable the return of the output object from the cmdlet.
    .PARAMETER Credential
        PSCredential containing an API Token in the Password field.
    .OUTPUTS
        Success: No Output.
        PassThru: PSCustomObject representing the newly created person.
    .EXAMPLE
        PS C:\> New-LrAdminUser -FirstName "John" -LastName "Doe" -PassThru
    .NOTES
        LogRhythm-API
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $FirstName,

        [Parameter(Mandatory = $true, Position = 1)]
        [string] $LastName,

        [Parameter(Mandatory = $false, Position = 2)]
        [string] $Title,

        [Parameter(Mandatory = $false, Position = 3)]
        [string] $Department,

        [Parameter(Mandatory = $false, Position = 4)]
        [string] $Company,

        [Parameter(Mandatory = $false, Position = 5)]
        [switch] $PassThru,

        [Parameter(Mandatory = $false, Position = 6)]
        [ValidateNotNull()]
        [pscredential] $Credential = $LrtConfig.LogRhythm.ApiKey
    )

    Begin {
        $Me = $MyInvocation.MyCommand.Name
        $BaseUrl = $LrtConfig.LogRhythm.BaseUrl
        $Token = $Credential.GetNetworkCredential().Password
        $Headers = [Dictionary[string,string]]::new()
        $Headers.Add("Authorization", "Bearer $Token")
        $Method = $HttpMethod.Post
        Enable-TrustAllCertsPolicy
    }

    Process {
        $ErrorObject = [PSCustomObject]@{
            Error = $false; Type = $null; Code = $null; Note = $null; Raw = $null
        }

        if ($LrtConfig.LogRhythm.Version -match '7\.[0-4]\.\d+') {
            $ErrorObject.Error = $true
            $ErrorObject.Code = "404"
            $ErrorObject.Type = "Cmdlet not supported."
            $ErrorObject.Note = "This cmdlet is available in LogRhythm version 7.5.0 and greater."
            return $ErrorObject
        }

        $RequestUrl = $BaseUrl + "/lr-admin-api/users/"
        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        $Body = [PSCustomObject]@{
            firstName  = $FirstName
            lastName   = $LastName
            title      = $(if ($Title) { $Title } else { "" })
            department = $(if ($Department) { $Department } else { "" })
            company    = $(if ($Company) { $Company } else { "" })
        }

        Write-Verbose "[$Me]: Request Body:`n$($Body | ConvertTo-Json)"

        $Response = Invoke-RestAPIMethod -Uri $RequestUrl -Headers $Headers -Method $Method -Body $($Body | ConvertTo-Json) -Origin $Me
        if (($null -ne $Response.Error) -and ($Response.Error -eq $true)) { return $Response }

        if ($PassThru) { return $Response }
    }

    End { }
}
