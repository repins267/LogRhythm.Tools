using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function New-LrUserLogin {
    <#
    .SYNOPSIS
        Create a new user login in the LogRhythm Admin API.
    .DESCRIPTION
        New-LrUserLogin creates a user login record associated with a person.
    .PARAMETER PersonId
        The person ID to associate the login with.
    .PARAMETER Login
        The login username.
    .PARAMETER Password
        The login password as a SecureString.
    .PARAMETER PassThru
        Switch parameter that will enable the return of the output object from the cmdlet.
    .PARAMETER Credential
        PSCredential containing an API Token in the Password field.
    .OUTPUTS
        Success: No Output.
        PassThru: PSCustomObject representing the newly created user login.
    .EXAMPLE
        PS C:\> New-LrUserLogin -PersonId 1 -Login "jdoe" -Password (ConvertTo-SecureString "P@ss" -AsPlainText -Force) -PassThru
    .NOTES
        LogRhythm-API
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, Position = 0)]
        [int32] $PersonId,

        [Parameter(Mandatory = $true, Position = 1)]
        [string] $Login,

        [Parameter(Mandatory = $true, Position = 2)]
        [securestring] $Password,

        [Parameter(Mandatory = $false, Position = 3)]
        [switch] $PassThru,

        [Parameter(Mandatory = $false, Position = 4)]
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

        $RequestUrl = $BaseUrl + "/lr-admin-api/userLogins/"
        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        # Convert SecureString to plain text for API submission
        $_bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
        $_plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($_bstr)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($_bstr)

        $Body = [PSCustomObject]@{
            personId = $PersonId
            login    = $Login
            password = $_plainPassword
        }

        Write-Verbose "[$Me]: Request Body:`n[PersonId: $PersonId, Login: $Login]"

        $Response = Invoke-RestAPIMethod -Uri $RequestUrl -Headers $Headers -Method $Method -Body $($Body | ConvertTo-Json) -Origin $Me
        if (($null -ne $Response.Error) -and ($Response.Error -eq $true)) { return $Response }

        if ($PassThru) { return $Response }
    }

    End { }
}
