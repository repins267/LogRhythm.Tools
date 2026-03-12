using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function Get-LrOpenCollectorBeats {
    <#
    .SYNOPSIS
        Retrieve Beats associated with an Open Collector from LogRhythm.
    .DESCRIPTION
        Get-LrOpenCollectorBeats returns all beats associated with the
        specified open collector ID.
    .PARAMETER Id
        The Open Collector ID to retrieve associated beats for.
    .PARAMETER PageValuesCount
        Number of results per page. Default is 1000.
    .PARAMETER PageCount
        Page number to return. Default is 1.
    .PARAMETER Credential
        PSCredential containing an API Token in the Password field.
    .OUTPUTS
        PSCustomObject representing LogRhythm Beat records for the open collector.
    .EXAMPLE
        PS C:\> Get-LrOpenCollectorBeats -Id 5
        ---
        Returns all beats associated with Open Collector ID 5.
    .NOTES
        LogRhythm-API
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [int32] $Id,


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

        # Request Setup
        $BaseUrl = $LrtConfig.LogRhythm.BaseUrl
        $Token = $Credential.GetNetworkCredential().Password

        # Define HTTP Headers
        $Headers = [Dictionary[string,string]]::new()
        $Headers.Add("Authorization", "Bearer $Token")

        # Define HTTP Method
        $Method = $HttpMethod.Get

        # Check preference requirements for self-signed certificates and set enforcement for Tls1.2
        Enable-TrustAllCertsPolicy
    }

    Process {
        # Establish General Error object Output
        $ErrorObject = [PSCustomObject]@{
            Error                 =   $false
            Type                  =   $null
            Code                  =   $null
            Note                  =   $null
            Raw                   =   $null
        }

        # Verify version
        if ($LrtConfig.LogRhythm.Version -match '7\.[0-7]\.\d+') {
            $ErrorObject.Error = $true
            $ErrorObject.Code = "404"
            $ErrorObject.Type = "Cmdlet not supported."
            $ErrorObject.Note = "This cmdlet is available in LogRhythm version 7.8.0 and greater."
            return $ErrorObject
        }

        #region: Process Query Parameters____________________________________________________
        $QueryParams = [Dictionary[string,string]]::new()

        if ($PageValuesCount) {
            $_pageValueCount = $PageValuesCount
        } else {
            $_pageValueCount = 1000
        }
        $QueryParams.Add("count", $_pageValueCount)

        $Offset = ($PageCount -1) * $_pageValueCount
        $QueryParams.Add("offset", $Offset)

        if ($QueryParams.Count -gt 0) {
            $QueryString = $QueryParams | ConvertTo-QueryString
            Write-Verbose "[$Me]: QueryString is [$QueryString]"
        }

        # Request URL
        $RequestUrl = $BaseUrl + "/lr-admin-api/openCollectors/" + $Id + "/beats/" + $QueryString

        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        # Send Request
        $Response = Invoke-RestAPIMethod -Uri $RequestUrl -Headers $Headers -Method $Method -Origin $Me
        if (($null -ne $Response.Error) -and ($Response.Error -eq $true)) {
            return $Response
        }

        # Check if pagination is required
        if ($Response.Count -eq $PageValuesCount) {
            Write-Verbose "[$Me]: Begin Pagination"

            DO {
                $PageCount = $PageCount + 1
                $Offset = ($PageCount -1) * $PageValuesCount
                $QueryParams.offset = $Offset
                $QueryString = $QueryParams | ConvertTo-QueryString
                $RequestUrl = $BaseUrl + "/lr-admin-api/openCollectors/" + $Id + "/beats/" + $QueryString
                Write-Verbose "[$Me]: Request URL: $RequestUrl"

                $PaginationResults = Invoke-RestAPIMethod -Uri $RequestUrl -Headers $Headers -Method $Method -Origin $Me
                if (($null -ne $PaginationResults.Error) -and ($PaginationResults.Error -eq $true)) {
                    return $PaginationResults
                }

                $Response = $Response + $PaginationResults
            } While ($($PaginationResults.Count) -eq $PageValuesCount)

            $Response = $Response | Sort-Object -Property id -Unique
            Write-Verbose "[$Me]: End Pagination"
        }

        return $Response
    }

    End {
    }
}
