using namespace System
using namespace System.Collections.Generic

Function Import-ExaCorrelationRules {
    <#
    .SYNOPSIS
        Import correlation rules into Exabeam.
    .DESCRIPTION
        Imports correlation rule definitions into the Exabeam environment. Rules
        can be provided as a JSON file path or as PowerShell objects. When using
        the File parameter set, the file contents are read and submitted directly.
        When using the Object parameter set, the objects are serialized to JSON.
    .PARAMETER FilePath
        Path to a JSON file containing correlation rule definitions to import.
    .PARAMETER Rules
        Array of rule objects to import. Objects are serialized to JSON with a
        depth of 10 levels.
    .PARAMETER PassThru
        Return the API response object.
    .OUTPUTS
        PSCustomObject representing the import result when PassThru is specified.
    .EXAMPLE
        PS C:\> Import-ExaCorrelationRules -FilePath "C:\rules\corr_rules.json" -PassThru
        ---
        Imports correlation rules from a JSON file and returns the result.
    .EXAMPLE
        PS C:\> $rules = Export-ExaCorrelationRules -Id "rule-001"
        PS C:\> Import-ExaCorrelationRules -Rules $rules -PassThru
        ---
        Re-imports previously exported correlation rules.
    .NOTES
        Exabeam-API
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding(SupportsShouldProcess = $true)]
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
        $RequestUrl = $Api.BaseUrl + "correlation-rules/v2/rules/import"
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

        if ($PSCmdlet.ShouldProcess("correlation rules", "Import into Exabeam")) {
            # Send Request
            $Response = Invoke-RestAPIMethod -Uri $RequestUrl -Headers $Api.Headers -Method $Method -Body $Body -Origin $Me
            if (($null -ne $Response.Error) -and ($Response.Error -eq $true)) {
                return $Response
            }

            if ($PassThru) { return $Response }
        }
    }

    End { }
}
