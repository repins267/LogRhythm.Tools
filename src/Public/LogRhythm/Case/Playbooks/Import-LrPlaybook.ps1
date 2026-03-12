using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function Import-LrPlaybook {
    <#
    .SYNOPSIS
        Import a new playbook for LogRhythm case use.
    .DESCRIPTION
        The Import-LrPlaybook cmdlet adds a playbook to LogRhythm.
    .PARAMETER Credential
        PSCredential containing an API Token in the Password field.
        Note: You can bypass the need to provide a Credential by setting
        the preference variable $LrtConfig.LogRhythm.ApiKey
        with a valid Api Token.
    .PARAMETER Playbook
        Full file path to the LogRhythm Playbook file to import.
    .PARAMETER PassThru
        Switch paramater that will enable the return of the output object from the cmdlet.
    .INPUTS
        [System.String] "Playbook" ==> [Playbook] : Full path to the playbook file.
    .OUTPUTS
        PSCustomObject representing the added playbook.
    .EXAMPLE
        PS C:\> Import-LrPlaybook -Playbook "C:\Playbooks\MyPlaybook.lrp" -PassThru
    .NOTES
        LogRhythm-API
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [string] $Playbook,

        [Parameter(Mandatory = $false, Position = 1)]
        [switch] $PassThru,

        [Parameter(Mandatory = $false, Position = 2)]
        [ValidateNotNull()]
        [pscredential] $Credential = $LrtConfig.LogRhythm.ApiKey
    )


    Begin {
        $Me = $MyInvocation.MyCommand.Name

        $BaseUrl = $LrtConfig.LogRhythm.BaseUrl
        $Token = $Credential.GetNetworkCredential().Password

        # Request Headers
        $Headers = [Dictionary[string,string]]::new()
        $Headers.Add("Authorization", "Bearer $Token")

        # Request Method
        $Method = $HttpMethod.Post

        # Check preference requirements for self-signed certificates and set enforcement for Tls1.2
        Enable-TrustAllCertsPolicy
    }


    Process {
        # Establish General Error object Output
        $ErrorObject = [PSCustomObject]@{
            Code                  =   $null
            Error                 =   $false
            Type                  =   $null
            Note                  =   $null
            ResponseUrl           =   $null
            Value                 =   $Playbook
        }

        if (Test-Path -Path $Playbook) {
            $FileName = Split-Path $Playbook -Leaf
        } else {
            $ErrorObject.Error = $true
            $ErrorObject.Note = "Provided path is not resolvable.  Please provide a full path to the LogRhythm Playbook."
            return $ErrorObject
        }

        $RequestUrl = $BaseUrl + "/lr-case-api/playbooks/import"
        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        # Build multipart/form-data body
        $Boundary = [System.Guid]::NewGuid().ToString()
        $FileContent = [System.IO.File]::ReadAllText($Playbook)
        $LF = "`r`n"

        $Body = (
            "--$Boundary",
            "Content-Disposition: form-data; name=`"file`"; filename=`"$FileName`"",
            "Content-Type: application/octet-stream",
            "",
            $FileContent,
            "--$Boundary--"
        ) -join $LF

        $ContentType = "multipart/form-data; boundary=$Boundary"

        # Send Request
        $Response = Invoke-RestAPIMethod -Uri $RequestUrl -Headers $Headers -Method $Method -Body $Body -ContentType $ContentType -Origin $Me
        if (($null -ne $Response.Error) -and ($Response.Error -eq $true)) {
            return $Response
        }

        if ($PassThru) {
            return $Response
        }
    }


    End { }
}
