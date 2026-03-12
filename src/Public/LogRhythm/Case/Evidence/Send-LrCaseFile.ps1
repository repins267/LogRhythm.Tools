using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function Send-LrCaseFile {
    <#
    .SYNOPSIS
        Upload a file to the LogRhythm Case API file store.
    .DESCRIPTION
        Send-LrCaseFile uploads a file to the Case API files endpoint for
        later attachment to cases as evidence.
    .PARAMETER FilePath
        The full path to the file to upload.
    .PARAMETER PassThru
        Switch parameter that will enable the return of the output object from the cmdlet.
    .PARAMETER Credential
        PSCredential containing an API Token in the Password field.
    .OUTPUTS
        Success: No Output.
        PassThru: PSCustomObject representing the uploaded file record.
    .EXAMPLE
        PS C:\> Send-LrCaseFile -FilePath "C:\evidence\capture.pcap" -PassThru
    .NOTES
        LogRhythm-API
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string] $FilePath,

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
        $Headers = [Dictionary[string,string]]::new()
        $Headers.Add("Authorization", "Bearer $Token")
        $Method = $HttpMethod.Post
        Enable-TrustAllCertsPolicy
    }

    Process {
        $RequestUrl = $BaseUrl + "/lr-case-api/files/"
        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        $FileContent = [File]::ReadAllBytes($FilePath)
        $FileName = [Path]::GetFileName($FilePath)

        $Boundary = [Guid]::NewGuid().ToString()
        $Headers.Add("Content-Type", "multipart/form-data; boundary=$Boundary")

        $BodyLines = @(
            "--$Boundary"
            "Content-Disposition: form-data; name=`"file`"; filename=`"$FileName`""
            "Content-Type: application/octet-stream"
            ""
        )
        $BodyStart = [System.Text.Encoding]::UTF8.GetBytes(($BodyLines -join "`r`n") + "`r`n")
        $BodyEnd = [System.Text.Encoding]::UTF8.GetBytes("`r`n--$Boundary--`r`n")

        $Body = [byte[]]::new($BodyStart.Length + $FileContent.Length + $BodyEnd.Length)
        [Buffer]::BlockCopy($BodyStart, 0, $Body, 0, $BodyStart.Length)
        [Buffer]::BlockCopy($FileContent, 0, $Body, $BodyStart.Length, $FileContent.Length)
        [Buffer]::BlockCopy($BodyEnd, 0, $Body, $BodyStart.Length + $FileContent.Length, $BodyEnd.Length)

        Write-Verbose "[$Me]: Uploading file: $FileName ($($FileContent.Length) bytes)"

        $Response = Invoke-RestAPIMethod -Uri $RequestUrl -Headers $Headers -Method $Method -Body $Body -Origin $Me
        if (($null -ne $Response.Error) -and ($Response.Error -eq $true)) { return $Response }

        if ($PassThru) { return $Response }
    }

    End { }
}
