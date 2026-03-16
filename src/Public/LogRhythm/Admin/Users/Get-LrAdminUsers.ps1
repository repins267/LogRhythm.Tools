using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function Get-LrAdminUsers {
    <#
    .SYNOPSIS
        Retrieve a list of persons from the LogRhythm Admin API.
    .DESCRIPTION
        Get-LrAdminUsers returns persons from the Admin API persons endpoint.
        This is distinct from Get-LrUsers which targets the Case API.
    .PARAMETER Name
        Filter results by person name.
    .PARAMETER PageValuesCount
        Number of results per page. Default is 1000.
    .PARAMETER PageCount
        Page number to return. Default is 1.
    .PARAMETER Credential
        PSCredential containing an API Token in the Password field.
    .OUTPUTS
        PSCustomObject representing LogRhythm Admin person records.
    .EXAMPLE
        PS C:\> Get-LrAdminUsers
        ---
        Returns all persons from the Admin API.
    .NOTES
        LogRhythm-API
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false, Position = 0)]
        [string] $Name,


        [Parameter(Mandatory = $false, Position = 1)]
        [int] $PageValuesCount = 1000,


        [Parameter(Mandatory = $false, Position = 2)]
        [int] $PageCount = 1,


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

        $Method = $HttpMethod.Get

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

        $QueryParams = [Dictionary[string,string]]::new()
        if ($PageValuesCount) { $_pageValueCount = $PageValuesCount } else { $_pageValueCount = 1000 }
        $QueryParams.Add("count", $_pageValueCount)
        $Offset = ($PageCount -1) * $_pageValueCount
        $QueryParams.Add("offset", $Offset)
        if ($Name) { $QueryParams.Add("name", $Name) }

        if ($QueryParams.Count -gt 0) {
            $QueryString = $QueryParams | ConvertTo-QueryString
            Write-Verbose "[$Me]: QueryString is [$QueryString]"
        }

        $RequestUrl = $BaseUrl + "/lr-admin-api/users/" + $QueryString
        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        $Response = Invoke-RestAPIMethod -Uri $RequestUrl -Headers $Headers -Method $Method -Origin $Me
        if (($null -ne $Response.Error) -and ($Response.Error -eq $true)) { return $Response }

        if ($Response.Count -eq $PageValuesCount) {
            Write-Verbose "[$Me]: Begin Pagination"
            DO {
                $PageCount = $PageCount + 1
                $Offset = ($PageCount -1) * $PageValuesCount
                $QueryParams.offset = $Offset
                $QueryString = $QueryParams | ConvertTo-QueryString
                $RequestUrl = $BaseUrl + "/lr-admin-api/users/" + $QueryString
                Write-Verbose "[$Me]: Request URL: $RequestUrl"
                $PaginationResults = Invoke-RestAPIMethod -Uri $RequestUrl -Headers $Headers -Method $Method -Origin $Me
                if (($null -ne $PaginationResults.Error) -and ($PaginationResults.Error -eq $true)) { return $PaginationResults }
                $Response = @($Response) + @($PaginationResults)
            } While ($($PaginationResults.Count) -eq $PageValuesCount)
            $Response = $Response | Sort-Object -Property id -Unique
            Write-Verbose "[$Me]: End Pagination"
        }

        return $Response
    }

    End { }
}
