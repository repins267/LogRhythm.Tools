using namespace System
using namespace System.Collections.Generic

Function Import-ExaAnalyticsRules {
    <#
    .SYNOPSIS
        Import analytics rules into Exabeam.
    .DESCRIPTION
        Imports analytics rule definitions into the Exabeam detection management
        system. Rules can be provided as a JSON file path or as PowerShell objects.
        When using the File parameter set, the file contents are read and submitted
        directly. When using the Object parameter set, the objects are serialized
        to JSON before submission.
    .PARAMETER FilePath
        Path to a JSON file containing analytics rule definitions to import.
    .PARAMETER Rules
        Array of rule objects to import. Objects are serialized to JSON with a
        depth of 10 levels.
    .PARAMETER PassThru
        Switch to return the API response object.
    .OUTPUTS
        PSCustomObject representing the import result when PassThru is specified.
    .EXAMPLE
        PS C:\> Import-ExaAnalyticsRules -FilePath "C:\rules\exported_rules.json" -PassThru
        ---
        Imports analytics rules from a JSON file and returns the result.
    .EXAMPLE
        PS C:\> $rules = Export-ExaAnalyticsRules -Id "rule-001"
        PS C:\> Import-ExaAnalyticsRules -Rules $rules -PassThru
        ---
        Re-imports previously exported analytics rules.
    .NOTES
        Exabeam-API
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, ParameterSetName = 'File', Position = 0)]
        [ValidateScript({ Test-Path $_ })]
        [string] $FilePath,

        [Parameter(Mandatory = $true, ParameterSetName = 'Object', Position = 0)]
        [ValidateNotNull()]
        [object[]] $Rules,

        [Parameter(Mandatory = $false)]
        [switch] $PassThru
    )

    Begin {
        $Me = $MyInvocation.MyCommand.Name
        $Api = Initialize-ExaApiRequest

        # Define HTTP Method
        $Method = $HttpMethod.Post

        # Define HTTP URI
        $RequestUrl = $Api.BaseUrl + "detection-management/v1/rules/import"
    }

    Process {
        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        # Build request body based on parameter set
        if ($PSCmdlet.ParameterSetName -eq 'File') {
            Write-Verbose "[$Me]: Reading rules from file: $FilePath"
            $Body = Get-Content -Path $FilePath -Raw
        } else {
            Write-Verbose "[$Me]: Serializing $($Rules.Count) rule object(s)"
            $Body = $Rules | ConvertTo-Json -Depth 10 -Compress
        }

        # Send Request
        $Response = Invoke-RestAPIMethod -Uri $RequestUrl -Headers $Api.Headers -Method $Method -Body $Body -Origin $Me
        if (($null -ne $Response.Error) -and ($Response.Error -eq $true)) {
            return $Response
        }

        if ($PassThru) { return $Response }
    }

    End { }
}
