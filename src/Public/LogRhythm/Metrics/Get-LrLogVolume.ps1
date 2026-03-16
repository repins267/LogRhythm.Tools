using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function Get-LrLogVolume {
    <#
    .SYNOPSIS
        Retrieve log volume metrics from the LogRhythm Metrics API.
    .DESCRIPTION
        Get-LrLogVolume submits a POST request to the Metrics API to retrieve
        log volume data for the specified time range.
    .PARAMETER StartDate
        The start date for the log volume query.
    .PARAMETER EndDate
        The end date for the log volume query.
    .PARAMETER Credential
        PSCredential containing an API Token in the Password field.
    .OUTPUTS
        PSCustomObject representing log volume metrics.
    .EXAMPLE
        PS C:\> Get-LrLogVolume -StartDate "2024-01-01" -EndDate "2024-01-31"
    .NOTES
        LogRhythm-API
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, Position = 0)]
        [datetime] $StartDate,

        [Parameter(Mandatory = $true, Position = 1)]
        [datetime] $EndDate,

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

        $RequestUrl = $BaseUrl + "/lr-metrics-api/logvolume/"
        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        $Body = [PSCustomObject]@{
            minDate = $StartDate.ToString("yyyy-MM-ddTHH:mm:ssZ")
            maxDate = $EndDate.ToString("yyyy-MM-ddTHH:mm:ssZ")
            groupBy = [PSCustomObject]@{
                fieldName = "Entity"
            }
        }

        Write-Verbose "[$Me]: Request Body:`n$($Body | ConvertTo-Json)"

        $Response = Invoke-RestAPIMethod -Uri $RequestUrl -Headers $Headers -Method $Method -Body $($Body | ConvertTo-Json) -Origin $Me
        if (($null -ne $Response.Error) -and ($Response.Error -eq $true)) { return $Response }

        return $Response
    }

    End { }
}
