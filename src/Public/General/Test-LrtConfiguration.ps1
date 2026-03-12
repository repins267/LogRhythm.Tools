using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function Test-LrtConfiguration {
    <#
    .SYNOPSIS
        Validate LogRhythm.Tools configuration and test API connectivity.
    .DESCRIPTION
        Test-LrtConfiguration checks that configuration values are present
        and optionally tests connectivity to the configured API endpoints.

        For each service, it validates:
        - BaseUrl is set and not the default placeholder
        - ApiKey or Credential is present (where applicable)
        - API endpoint is reachable (when -TestConnectivity is specified)

        The LogRhythm connectivity test makes a lightweight GET request to
        the Admin API persons endpoint.
    .PARAMETER Service
        Optional name of a specific service to test. If omitted, tests all
        configured services.
    .PARAMETER TestConnectivity
        When specified, performs actual HTTP requests to verify API
        connectivity beyond just checking config values are present.
    .INPUTS
        None
    .OUTPUTS
        PSCustomObject[] with Service, Status, and Message properties for
        each tested service.
    .EXAMPLE
        PS C:\> Test-LrtConfiguration

        Validates all configuration sections have required values set.
    .EXAMPLE
        PS C:\> Test-LrtConfiguration -Service LogRhythm -TestConnectivity

        Validates LogRhythm config and tests API connectivity.
    .NOTES
        LogRhythm-API
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateSet(
            "LogRhythm", "Exabeam", "AzureAD", "DefenderATP", "Mimecast",
            "RecordedFuture", "VirusTotal", "UrlScan", "Shodan"
        )]
        [string] $Service,

        [Parameter(Mandatory = $false, Position = 1)]
        [switch] $TestConnectivity
    )

    Begin {
        $Me = $MyInvocation.MyCommand.Name
        Enable-TrustAllCertsPolicy

        $Results = [List[PSCustomObject]]::new()
    }

    Process {
        if (-not $LrtConfig) {
            $Results.Add([PSCustomObject]@{
                Service = "Module"
                Status  = "Failed"
                Message = "No configuration loaded. Run Initialize-LrtConfiguration."
            })
            return $Results
        }

        # Services that have API keys and base URLs
        $ApiServices = @(
            @{ Name = "LogRhythm";      HasApiKey = $true;  HasCredential = $false }
            @{ Name = "Exabeam";        HasApiKey = $true;  HasCredential = $false }
            @{ Name = "AzureAD";        HasApiKey = $true;  HasCredential = $false }
            @{ Name = "DefenderATP";    HasApiKey = $true;  HasCredential = $false }
            @{ Name = "Mimecast";       HasApiKey = $true;  HasCredential = $true  }
            @{ Name = "RecordedFuture"; HasApiKey = $true;  HasCredential = $false }
            @{ Name = "VirusTotal";     HasApiKey = $true;  HasCredential = $false }
            @{ Name = "UrlScan";        HasApiKey = $true;  HasCredential = $false }
            @{ Name = "Shodan";         HasApiKey = $true;  HasCredential = $false }
        )

        # Filter to specific service if requested
        if ($Service) {
            $ApiServices = $ApiServices | Where-Object { $_.Name -eq $Service }
        }

        foreach ($Svc in $ApiServices) {
            $SvcName = $Svc.Name
            $SvcConfig = $LrtConfig.$SvcName
            $Result = [PSCustomObject]@{
                Service = $SvcName
                Status  = "Passed"
                Message = "Configuration valid."
            }

            if ($null -eq $SvcConfig) {
                $Result.Status = "NotConfigured"
                $Result.Message = "Service section not found in configuration."
                $Results.Add($Result)
                continue
            }

            # Check BaseUrl
            if ($SvcConfig.PSObject.Properties.Name -contains "BaseUrl") {
                $Url = $SvcConfig.BaseUrl
                if ([string]::IsNullOrWhiteSpace($Url) -or $Url -match '\[NOT_SET\]') {
                    $Result.Status = "Failed"
                    $Result.Message = "BaseUrl is not configured."
                    $Results.Add($Result)
                    continue
                }
            }

            # Check ApiKey
            if ($Svc.HasApiKey) {
                $Key = $SvcConfig.ApiKey
                if ($null -eq $Key -or ($Key -is [string] -and [string]::IsNullOrWhiteSpace($Key))) {
                    $Result.Status = "Warning"
                    $Result.Message = "API key not set."
                    $Results.Add($Result)
                    continue
                }
            }

            # Connectivity test
            if ($TestConnectivity -and $SvcName -eq "LogRhythm") {
                try {
                    $Token = $SvcConfig.ApiKey.GetNetworkCredential().Password
                    $Headers = [Dictionary[string,string]]::new()
                    $Headers.Add("Authorization", "Bearer $Token")
                    $TestUrl = $SvcConfig.BaseUrl + "/lr-admin-api/persons/?count=1&offset=0"
                    Write-Verbose "[$Me]: Testing connectivity to $TestUrl"
                    $Response = Invoke-RestAPIMethod -Uri $TestUrl -Headers $Headers -Method $HttpMethod.Get -Origin $Me
                    if (($null -ne $Response.Error) -and ($Response.Error -eq $true)) {
                        $Result.Status = "Failed"
                        $Result.Message = "API returned error: $($Response.Note)"
                    } else {
                        $Result.Message = "Connected successfully."
                    }
                } catch {
                    $Result.Status = "Failed"
                    $Result.Message = "Connection failed: $($_.Exception.Message)"
                }
            }

            $Results.Add($Result)
        }

        return $Results
    }

    End { }
}
