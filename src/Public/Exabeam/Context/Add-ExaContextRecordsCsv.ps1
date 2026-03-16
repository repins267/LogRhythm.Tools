using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function Add-ExaContextRecordsCsv {
    <#
    .SYNOPSIS
        Add records to an Exabeam context table from a CSV file.
    .DESCRIPTION
        Uploads a CSV file to add records to the specified Exabeam context table.
        The file is read as bytes and submitted with multipart content type to the
        context management API.
    .PARAMETER Id
        The unique identifier of the context table to add records to.
    .PARAMETER FilePath
        Path to the CSV file containing records to upload.
    .PARAMETER PassThru
        Switch to return the API response object.
    .OUTPUTS
        PSCustomObject representing the upload result when PassThru is specified.
    .EXAMPLE
        PS C:\> Add-ExaContextRecordsCsv -Id "table-abc123" -FilePath "C:\data\records.csv" -PassThru
        ---
        Uploads CSV records to the specified context table and returns the result.
    .NOTES
        Exabeam-API
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Alias('TableId')]
        [string] $Id,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateScript({ Test-Path $_ })]
        [string] $FilePath,

        [Parameter(Mandatory = $false)]
        [switch] $PassThru
    )

    Begin {
        $Me = $MyInvocation.MyCommand.Name
        $Api = Initialize-ExaApiRequest

        # Define HTTP Method
        $Method = $HttpMethod.Post
    }

    Process {
        # Define HTTP URI
        $RequestUrl = $Api.BaseUrl + "context-management/v1/tables/$Id/records/csv"

        Write-Verbose "[$Me]: Request URL: $RequestUrl"
        Write-Verbose "[$Me]: Uploading file: $FilePath"

        # Read file as bytes for multipart upload
        $FileBytes = [File]::ReadAllBytes((Resolve-Path $FilePath))
        $FileName = [Path]::GetFileName($FilePath)

        # Set Content-Type for multipart/form-data
        $Boundary = [Guid]::NewGuid().ToString()
        $Api.Headers["Content-Type"] = "multipart/form-data; boundary=$Boundary"

        # Build multipart body
        $LF = "`r`n"
        $BodyLines = @(
            "--$Boundary"
            "Content-Disposition: form-data; name=`"file`"; filename=`"$FileName`""
            "Content-Type: text/csv"
            ""
        )
        $BodyStart = [System.Text.Encoding]::UTF8.GetBytes(($BodyLines -join $LF) + $LF)
        $BodyEnd = [System.Text.Encoding]::UTF8.GetBytes("$LF--$Boundary--$LF")

        # Combine body parts
        $BodyStream = [MemoryStream]::new()
        $BodyStream.Write($BodyStart, 0, $BodyStart.Length)
        $BodyStream.Write($FileBytes, 0, $FileBytes.Length)
        $BodyStream.Write($BodyEnd, 0, $BodyEnd.Length)
        $Body = [System.Text.Encoding]::UTF8.GetString($BodyStream.ToArray())
        $BodyStream.Dispose()

        # Send Request
        $Response = Invoke-RestAPIMethod -Uri $RequestUrl -Headers $Api.Headers -Method $Method -Body $Body -Origin $Me
        if (($null -ne $Response.Error) -and ($Response.Error -eq $true)) {
            return $Response
        }

        if ($PassThru) { return $Response }
    }

    End { }
}
