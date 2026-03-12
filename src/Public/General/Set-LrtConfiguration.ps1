using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function Set-LrtConfiguration {
    <#
    .SYNOPSIS
        Update LogRhythm.Tools module configuration values.
    .DESCRIPTION
        Set-LrtConfiguration modifies configuration values for the module,
        persists them to disk, and updates the in-memory $LrtConfig variable.

        Use -Service to target a specific configuration section. API keys and
        credentials are stored as encrypted XML via Export-Clixml (DPAPI on
        Windows), separate from the main JSON config file.

        After setting values, the in-memory $LrtConfig is updated immediately
        so no module reimport is needed.
    .PARAMETER Service
        The configuration section to modify. Required.
    .PARAMETER BaseUrl
        The base URL for the service API endpoint.
    .PARAMETER Version
        The LogRhythm SIEM version (e.g., "7.11.0"). Only applies to LogRhythm service.
    .PARAMETER ApiKey
        PSCredential containing an API token in the Password field.
        The Username field can be any value (e.g., "api" or "LogRhythm").
        Stored as encrypted XML via Export-Clixml.
    .PARAMETER Credential
        PSCredential for services requiring username/password authentication.
        Stored as encrypted XML via Export-Clixml.
    .PARAMETER CertPolicyRequired
        Enable or disable certificate policy bypass. Only applies to General.
    .PARAMETER ProxyHost
        Proxy server hostname or IP. Only applies to Proxy service.
    .PARAMETER ProxyPort
        Proxy server port. Only applies to Proxy service.
    .PARAMETER ProxyRequired
        Enable or disable proxy usage. Only applies to Proxy service.
    .PARAMETER PassThru
        Return the updated configuration section.
    .INPUTS
        None
    .OUTPUTS
        Without PassThru: No output on success.
        With PassThru: PSCustomObject representing the updated configuration section.
    .EXAMPLE
        PS C:\> Set-LrtConfiguration -Service LogRhythm -BaseUrl "https://lr-api.example.com:8501"

        Sets the LogRhythm API base URL.
    .EXAMPLE
        PS C:\> Set-LrtConfiguration -Service LogRhythm -ApiKey (Get-Credential)

        Sets the LogRhythm API key from a credential prompt.
    .EXAMPLE
        PS C:\> Set-LrtConfiguration -Service LogRhythm -Version "7.11.0" -BaseUrl "https://lr:8501" -ApiKey (Get-Credential) -PassThru

        Configures LogRhythm connection and returns the updated config.
    .NOTES
        LogRhythm-API
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding(SupportsShouldProcess = $true)]
    Param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateSet(
            "General", "Proxy", "LogRhythm", "Exabeam", "LogRhythmEcho",
            "ActiveDirectory", "AzureAD", "DefenderATP", "Mimecast",
            "RecordedFuture", "VirusTotal", "UrlScan", "SecretServer", "Shodan"
        )]
        [string] $Service,

        [Parameter(Mandatory = $false, Position = 1)]
        [string] $BaseUrl,

        [Parameter(Mandatory = $false, Position = 2)]
        [string] $Version,

        [Parameter(Mandatory = $false, Position = 3)]
        [pscredential] $ApiKey,

        [Parameter(Mandatory = $false, Position = 4)]
        [pscredential] $Credential,

        [Parameter(Mandatory = $false)]
        [bool] $CertPolicyRequired,

        [Parameter(Mandatory = $false)]
        [string] $ProxyHost,

        [Parameter(Mandatory = $false)]
        [string] $ProxyPort,

        [Parameter(Mandatory = $false)]
        [bool] $ProxyRequired,

        [Parameter(Mandatory = $false)]
        [switch] $PassThru
    )

    Begin {
        $Me = $MyInvocation.MyCommand.Name

        # Config paths
        $ConfigDirPath = Join-Path `
            -Path ([Environment]::GetFolderPath("LocalApplicationData")) `
            -ChildPath "LogRhythm.Tools"
        $ConfigFilePath = Join-Path -Path $ConfigDirPath -ChildPath "LogRhythm.Tools.json"
    }

    Process {
        if (-not $LrtConfig) {
            Write-Warning "[$Me]: No configuration loaded. Run Initialize-LrtConfiguration first."
            return
        }

        if (-not (Test-Path $ConfigFilePath)) {
            Write-Warning "[$Me]: Config file not found at $ConfigFilePath."
            return
        }

        $ServiceConfig = $LrtConfig.$Service
        if ($null -eq $ServiceConfig) {
            Write-Warning "[$Me]: Service '$Service' not found in configuration."
            return
        }

        $Changed = $false

        # BaseUrl
        if ($PSBoundParameters.ContainsKey('BaseUrl')) {
            if ($ServiceConfig.PSObject.Properties.Name -contains "BaseUrl") {
                if ($PSCmdlet.ShouldProcess($Service, "Set BaseUrl to '$BaseUrl'")) {
                    $LrtConfig.$Service.BaseUrl = $BaseUrl
                    $Changed = $true
                    Write-Verbose "[$Me]: $Service BaseUrl set to $BaseUrl"
                }
            } else {
                Write-Warning "[$Me]: Service '$Service' does not have a BaseUrl property."
            }
        }

        # Version (LogRhythm only)
        if ($PSBoundParameters.ContainsKey('Version')) {
            if ($ServiceConfig.PSObject.Properties.Name -contains "Version") {
                if ($PSCmdlet.ShouldProcess($Service, "Set Version to '$Version'")) {
                    $LrtConfig.$Service.Version = $Version
                    $Changed = $true
                    Write-Verbose "[$Me]: $Service Version set to $Version"
                }
            } else {
                Write-Warning "[$Me]: Service '$Service' does not have a Version property."
            }
        }

        # General: CertPolicyRequired
        if ($PSBoundParameters.ContainsKey('CertPolicyRequired')) {
            if ($Service -eq "General") {
                if ($PSCmdlet.ShouldProcess("General", "Set CertPolicyRequired to $CertPolicyRequired")) {
                    $LrtConfig.General.CertPolicyRequired = $CertPolicyRequired
                    $Changed = $true
                    Write-Verbose "[$Me]: CertPolicyRequired set to $CertPolicyRequired"
                }
            } else {
                Write-Warning "[$Me]: CertPolicyRequired only applies to the General service."
            }
        }

        # Proxy settings
        if ($PSBoundParameters.ContainsKey('ProxyRequired')) {
            if ($Service -eq "Proxy") {
                if ($PSCmdlet.ShouldProcess("Proxy", "Set Required to $ProxyRequired")) {
                    $LrtConfig.Proxy.Required = $ProxyRequired
                    $Changed = $true
                }
            } else {
                Write-Warning "[$Me]: ProxyRequired only applies to the Proxy service."
            }
        }
        if ($PSBoundParameters.ContainsKey('ProxyHost')) {
            if ($Service -eq "Proxy") {
                if ($PSCmdlet.ShouldProcess("Proxy", "Set Host to '$ProxyHost'")) {
                    $LrtConfig.Proxy.Host = $ProxyHost
                    $Changed = $true
                }
            } else {
                Write-Warning "[$Me]: ProxyHost only applies to the Proxy service."
            }
        }
        if ($PSBoundParameters.ContainsKey('ProxyPort')) {
            if ($Service -eq "Proxy") {
                if ($PSCmdlet.ShouldProcess("Proxy", "Set Port to '$ProxyPort'")) {
                    $LrtConfig.Proxy.Port = $ProxyPort
                    $Changed = $true
                }
            } else {
                Write-Warning "[$Me]: ProxyPort only applies to the Proxy service."
            }
        }

        # ApiKey (encrypted XML)
        if ($PSBoundParameters.ContainsKey('ApiKey')) {
            if ($ServiceConfig.PSObject.Properties.Name -contains "ApiKey") {
                if ($PSCmdlet.ShouldProcess($Service, "Set ApiKey")) {
                    $KeyFileName = $Service + ".ApiKey.xml"
                    $KeyFilePath = Join-Path -Path $ConfigDirPath -ChildPath $KeyFileName
                    Export-Clixml -Path $KeyFilePath -InputObject $ApiKey
                    $LrtConfig.$Service.ApiKey = $ApiKey
                    $Changed = $true
                    Write-Verbose "[$Me]: $Service API key saved to $KeyFilePath"
                }
            } else {
                Write-Warning "[$Me]: Service '$Service' does not support ApiKey."
            }
        }

        # Credential (encrypted XML)
        if ($PSBoundParameters.ContainsKey('Credential')) {
            if ($ServiceConfig.PSObject.Properties.Name -contains "Credential") {
                if ($PSCmdlet.ShouldProcess($Service, "Set Credential")) {
                    $CredFileName = $Service + ".Credential.xml"
                    $CredFilePath = Join-Path -Path $ConfigDirPath -ChildPath $CredFileName
                    Export-Clixml -Path $CredFilePath -InputObject $Credential
                    $LrtConfig.$Service.Credential = $Credential
                    $Changed = $true
                    Write-Verbose "[$Me]: $Service credential saved to $CredFilePath"
                }
            } else {
                Write-Warning "[$Me]: Service '$Service' does not support Credential."
            }
        }

        # Persist JSON config (excludes secrets - those are in XML files)
        if ($Changed) {
            # Build a clean copy for JSON serialization (no PSCredential objects)
            $JsonConfig = $LrtConfig | ConvertTo-Json -Depth 5 | ConvertFrom-Json
            foreach ($Category in $JsonConfig.PSObject.Properties) {
                if ($null -eq $Category.Value) { continue }
                $Props = $Category.Value.PSObject.Properties
                foreach ($Prop in $Props) {
                    if ($Prop.Name -eq "ApiKey" -and $Prop.Value -is [PSCredential]) {
                        $Category.Value.ApiKey = ""
                    }
                    if ($Prop.Name -eq "Credential" -and $Prop.Value -is [PSCredential]) {
                        $Category.Value.Credential = ""
                    }
                }
            }
            $JsonConfig | ConvertTo-Json -Depth 5 | Set-Content -Path $ConfigFilePath -Encoding UTF8
            Write-Verbose "[$Me]: Configuration saved to $ConfigFilePath"
        }

        if ($PassThru) {
            return $LrtConfig.$Service
        }
    }

    End { }
}
