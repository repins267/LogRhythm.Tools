using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function New-LrLsvTemplate {
    <#
    .SYNOPSIS
        Create a new Log Source Virtualization template in LogRhythm.
    .DESCRIPTION
        New-LrLsvTemplate creates a new LSV template. Only Id and Name are
        mandatory. Items may optionally be passed to associate with the template
        at creation time.
    .PARAMETER Name
        The name of the new LSV template.
    .PARAMETER ShortDesc
        Optional short description.
    .PARAMETER LongDesc
        Optional long description.
    .PARAMETER Items
        Optional array of item objects to associate. Each item requires id and sortOrder.
    .PARAMETER PassThru
        Switch parameter that will enable the return of the output object from the cmdlet.
    .PARAMETER Credential
        PSCredential containing an API Token in the Password field.
    .OUTPUTS
        Success: No Output.
        Error: PSCustomObject representing error details.
        PassThru: PSCustomObject representing the newly created LSV Template.
    .EXAMPLE
        PS C:\> New-LrLsvTemplate -Name "Firewall VSources" -PassThru
        ---
        Creates a new LSV template and returns the created object.
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
        [string] $ShortDesc,


        [Parameter(Mandatory = $false, Position = 2)]
        [string] $LongDesc,


        [Parameter(Mandatory = $false, Position = 3)]
        [object[]] $Items,


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
        $RequestUrl = $BaseUrl + "/lr-admin-api/lsvtemplates/"

        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        # Request Body
        $Body = [PSCustomObject]@{
            id        = -1
            name      = $Name
            shortDesc = $(if ($ShortDesc) { $ShortDesc } else { "" })
            longDesc  = $(if ($LongDesc) { $LongDesc } else { "" })
        }

        if ($Items) {
            $Body | Add-Member -NotePropertyName items -NotePropertyValue $Items
        }

        Write-Verbose "[$Me]: Request Body:`n$($Body | ConvertTo-Json -Depth 5)"

        # Send Request
        $Response = Invoke-RestAPIMethod -Uri $RequestUrl -Headers $Headers -Method $Method -Body $($Body | ConvertTo-Json -Depth 5) -Origin $Me
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
