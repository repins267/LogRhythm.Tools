using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function Update-LrCaseLogsIndex {
    <#
    .SYNOPSIS
        Update the logs index for a LogRhythm case.
    .DESCRIPTION
        Update-LrCaseLogsIndex performs a PUT update on the logs index
        associated with a case's evidence.
    .PARAMETER Id
        The case ID or case number.
    .PARAMETER LogsIndex
        The logs index object to set on the case.
    .PARAMETER PassThru
        Switch parameter that will enable the return of the output object from the cmdlet.
    .PARAMETER Credential
        PSCredential containing an API Token in the Password field.
    .OUTPUTS
        Success: No Output.
        PassThru: PSCustomObject representing the updated logs index.
    .EXAMPLE
        PS C:\> Update-LrCaseLogsIndex -Id 1780 -LogsIndex $indexObj -PassThru
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
        [object] $LogsIndex,

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
        $Method = $HttpMethod.Put
        Enable-TrustAllCertsPolicy
    }

    Process {
        $IdStatus = Test-LrCaseIdFormat $Id
        if ($IdStatus.IsValid -eq $true) {
            $CaseNumber = $IdStatus.CaseNumber
        } else {
            return $IdStatus
        }

        $RequestUrl = $BaseUrl + "/lr-case-api/cases/$CaseNumber/evidence/logs-index/"
        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        $Body = $LogsIndex | ConvertTo-Json -Depth 5
        Write-Verbose "[$Me]: Request Body:`n$Body"

        $Response = Invoke-RestAPIMethod -Uri $RequestUrl -Headers $Headers -Method $Method -Body $Body -Origin $Me
        if (($null -ne $Response.Error) -and ($Response.Error -eq $true)) { return $Response }

        if ($PassThru) { return $Response }
    }

    End { }
}
