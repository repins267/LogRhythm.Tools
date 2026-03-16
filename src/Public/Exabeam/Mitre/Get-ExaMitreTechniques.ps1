using namespace System
using namespace System.Collections.Generic

Function Get-ExaMitreTechniques {
    <#
    .SYNOPSIS
        Retrieve MITRE ATT&CK techniques from Exabeam.
    .DESCRIPTION
        Returns the list of MITRE ATT&CK techniques and sub-techniques available
        in the Exabeam environment. Useful for mapping detection rules to the
        MITRE ATT&CK framework.
    .OUTPUTS
        PSCustomObject representing MITRE ATT&CK techniques and sub-techniques.
    .EXAMPLE
        PS C:\> Get-ExaMitreTechniques
        ---
        Returns all MITRE ATT&CK techniques available in Exabeam.
    .NOTES
        Exabeam-API
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding()]
    Param()

    Begin {
        $Me = $MyInvocation.MyCommand.Name
        $Api = Initialize-ExaApiRequest

        # Define HTTP Method
        $Method = $HttpMethod.Get

        # Define HTTP URI
        $RequestUrl = $Api.BaseUrl + "mitre/v1/techniques"
    }

    Process {
        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        # Send Request
        $Response = Invoke-RestAPIMethod -Uri $RequestUrl -Headers $Api.Headers -Method $Method -Origin $Me
        if (($null -ne $Response.Error) -and ($Response.Error -eq $true)) {
            return $Response
        }

        return $Response
    }

    End { }
}
