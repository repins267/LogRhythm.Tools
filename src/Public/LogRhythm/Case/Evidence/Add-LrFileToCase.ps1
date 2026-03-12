using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function Add-LrFileToCase {
    <#
    .SYNOPSIS
        Add a file as evidence to a LogRhythm case.
    .DESCRIPTION
        Add-LrFileToCase attaches a file to a case as evidence via the Case API.
    .PARAMETER Id
        The case ID or case number to add the file to.
    .PARAMETER FilePath
        The full path to the file to attach.
    .PARAMETER Note
        Optional note to associate with the file evidence.
    .PARAMETER PassThru
        Switch parameter that will enable the return of the output object from the cmdlet.
    .PARAMETER Credential
        PSCredential containing an API Token in the Password field.
    .OUTPUTS
        Success: No Output.
        PassThru: PSCustomObject representing the evidence record.
    .EXAMPLE
        PS C:\> Add-LrFileToCase -Id 1780 -FilePath "C:\evidence\malware.zip" -Note "Captured sample" -PassThru
    .NOTES
        LogRhythm-API
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [ValidateNotNull()]
        [object] $Id,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string] $FilePath,

        [Parameter(Mandatory = $false, Position = 2)]
        [string] $Note,

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
        # Test CaseID Format
        $IdStatus = Test-LrCaseIdFormat $Id
        if ($IdStatus.IsValid -eq $true) {
            $CaseNumber = $IdStatus.CaseNumber
        } else {
            return $IdStatus
        }

        $RequestUrl = $BaseUrl + "/lr-case-api/cases/$CaseNumber/evidence/file/"
        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        # Read file content for upload
        $FileContent = [File]::ReadAllBytes($FilePath)
        $FileName = [Path]::GetFileName($FilePath)

        # Build multipart form data
        $Boundary = [Guid]::NewGuid().ToString()
        $Headers.Add("Content-Type", "multipart/form-data; boundary=$Boundary")

        $BodyLines = @(
            "--$Boundary"
            "Content-Disposition: form-data; name=`"file`"; filename=`"$FileName`""
            "Content-Type: application/octet-stream"
            ""
        )

        if ($Note) {
            $NoteLines = @(
                "--$Boundary"
                "Content-Disposition: form-data; name=`"note`""
                ""
                $Note
            )
        }

        $BodyStart = [System.Text.Encoding]::UTF8.GetBytes(($BodyLines -join "`r`n") + "`r`n")
        if ($Note) {
            $NoteBytes = [System.Text.Encoding]::UTF8.GetBytes("`r`n" + ($NoteLines -join "`r`n") + "`r`n")
        } else {
            $NoteBytes = [byte[]]::new(0)
        }
        $BodyEnd = [System.Text.Encoding]::UTF8.GetBytes("`r`n--$Boundary--`r`n")

        $Body = [byte[]]::new($BodyStart.Length + $FileContent.Length + $NoteBytes.Length + $BodyEnd.Length)
        [Buffer]::BlockCopy($BodyStart, 0, $Body, 0, $BodyStart.Length)
        [Buffer]::BlockCopy($FileContent, 0, $Body, $BodyStart.Length, $FileContent.Length)
        if ($NoteBytes.Length -gt 0) {
            [Buffer]::BlockCopy($NoteBytes, 0, $Body, $BodyStart.Length + $FileContent.Length, $NoteBytes.Length)
        }
        [Buffer]::BlockCopy($BodyEnd, 0, $Body, $BodyStart.Length + $FileContent.Length + $NoteBytes.Length, $BodyEnd.Length)

        Write-Verbose "[$Me]: Uploading file: $FileName ($($FileContent.Length) bytes)"

        $Response = Invoke-RestAPIMethod -Uri $RequestUrl -Headers $Headers -Method $Method -Body $Body -Origin $Me
        if (($null -ne $Response.Error) -and ($Response.Error -eq $true)) { return $Response }

        if ($PassThru) { return $Response }
    }

    End { }
}
