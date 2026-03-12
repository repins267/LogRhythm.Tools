using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function New-LrMsgSourceType {
    <#
    .SYNOPSIS
        Create a new message source type in the LogRhythm Admin API.
    .DESCRIPTION
        New-LrMsgSourceType creates a message source type record via the
        Admin API.
    .PARAMETER Name
        The name of the message source type.
    .PARAMETER Abbreviation
        Short abbreviation for the message source type.
    .PARAMETER PassThru
        Switch parameter that will enable the return of the output object from the cmdlet.
    .PARAMETER Credential
        PSCredential containing an API Token in the Password field.
    .OUTPUTS
        Success: No Output.
        PassThru: PSCustomObject representing the newly created message source type.
    .EXAMPLE
        PS C:\> New-LrMsgSourceType -Name "Custom App Logs" -Abbreviation "CAL" -PassThru
    .NOTES
        LogRhythm-API
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $Name,

        [Parameter(Mandatory = $false, Position = 1)]
        [string] $Abbreviation,

        [Parameter(Mandatory = $false, Position = 2)]
        [switch] $PassThru,

        [Parameter(Mandatory = $false, Position = 3)]
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

        $RequestUrl = $BaseUrl + "/lr-admin-api/msgSourceTypes/"
        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        $Body = [PSCustomObject]@{
            name         = $Name
            abbreviation = $(if ($Abbreviation) { $Abbreviation } else { "" })
        }

        Write-Verbose "[$Me]: Request Body:`n$($Body | ConvertTo-Json)"

        $Response = Invoke-RestAPIMethod -Uri $RequestUrl -Headers $Headers -Method $Method -Body $($Body | ConvertTo-Json) -Origin $Me
        if (($null -ne $Response.Error) -and ($Response.Error -eq $true)) { return $Response }

        if ($PassThru) { return $Response }
    }

    End { }
}
