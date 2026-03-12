using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function Initialize-LrtConfiguration {
    <#
    .SYNOPSIS
        Guided first-time setup for LogRhythm.Tools module configuration.
    .DESCRIPTION
        Initialize-LrtConfiguration provides an interactive guided setup
        experience for configuring the LogRhythm.Tools module. It creates
        the configuration directory and file if they do not exist, then
        walks the user through setting essential values.

        For non-interactive use, provide all parameters directly to skip
        prompts and configure the module silently.

        The configuration is stored at:
        - Config JSON: %LocalAppData%\LogRhythm.Tools\LogRhythm.Tools.json
        - API Keys: %LocalAppData%\LogRhythm.Tools\<Service>.ApiKey.xml
        - Credentials: %LocalAppData%\LogRhythm.Tools\<Service>.Credential.xml
    .PARAMETER BaseUrl
        The LogRhythm API base URL (e.g., "https://lr-api.example.com:8501").
        If not provided in non-interactive mode, the user will be prompted.
    .PARAMETER Version
        The LogRhythm SIEM version (e.g., "7.11.0").
    .PARAMETER ApiKey
        PSCredential containing the LogRhythm API token in the Password field.
        If not provided, the user will be prompted to enter one.
    .PARAMETER CertPolicyRequired
        Set to $true to enable certificate policy bypass for self-signed certs.
    .PARAMETER Force
        Overwrite existing configuration without prompting for confirmation.
    .PARAMETER PassThru
        Return the configuration object after setup.
    .INPUTS
        None
    .OUTPUTS
        Without PassThru: No output on success. Status messages via Write-Host.
        With PassThru: PSCustomObject representing the full configuration.
    .EXAMPLE
        PS C:\> Initialize-LrtConfiguration

        Launches guided interactive setup.
    .EXAMPLE
        PS C:\> Initialize-LrtConfiguration -BaseUrl "https://lr:8501" -Version "7.11.0" -ApiKey (Get-Credential) -Force

        Non-interactive setup with all required values provided.
    .NOTES
        LogRhythm-API
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding(SupportsShouldProcess = $true)]
    Param(
        [Parameter(Mandatory = $false, Position = 0)]
        [string] $BaseUrl,

        [Parameter(Mandatory = $false, Position = 1)]
        [string] $Version,

        [Parameter(Mandatory = $false, Position = 2)]
        [pscredential] $ApiKey,

        [Parameter(Mandatory = $false, Position = 3)]
        [bool] $CertPolicyRequired = $false,

        [Parameter(Mandatory = $false)]
        [switch] $Force,

        [Parameter(Mandatory = $false)]
        [switch] $PassThru
    )

    Begin {
        $Me = $MyInvocation.MyCommand.Name

        $ModuleName = "LogRhythm.Tools"
        $ConfigDirPath = Join-Path `
            -Path ([Environment]::GetFolderPath("LocalApplicationData")) `
            -ChildPath $ModuleName
        $ConfigFilePath = Join-Path -Path $ConfigDirPath -ChildPath "$ModuleName.json"
    }

    Process {
        # Check for existing config
        if ((Test-Path $ConfigFilePath) -and (-not $Force)) {
            Write-Host ""
            Write-Host "  Existing configuration found at:" -ForegroundColor Yellow
            Write-Host "  $ConfigFilePath" -ForegroundColor Cyan
            Write-Host ""
            $Confirm = Read-Host "  Overwrite existing configuration? (y/N)"
            if ($Confirm -notmatch '^[Yy]') {
                Write-Host "  Setup cancelled. Use Set-LrtConfiguration to modify individual settings." -ForegroundColor Yellow
                return
            }
        }

        # Ensure config directory exists
        if (-not (Test-Path $ConfigDirPath)) {
            if ($PSCmdlet.ShouldProcess($ConfigDirPath, "Create configuration directory")) {
                New-Item -Path $ConfigDirPath -ItemType Directory -Force | Out-Null
                Write-Verbose "[$Me]: Created config directory: $ConfigDirPath"
            }
        }

        # Create config from template or defaults
        $ScriptDir = $MyInvocation.MyCommand.Module.ModuleBase
        if ($ScriptDir) {
            $TemplatePath = Join-Path -Path $ScriptDir -ChildPath "..\dist\common\$ModuleName.json"
        }
        if ($TemplatePath -and (Test-Path $TemplatePath)) {
            Copy-Item -Path $TemplatePath -Destination $ConfigFilePath -Force
            $NewConfig = Get-Content -Path $ConfigFilePath -Raw | ConvertFrom-Json
        } else {
            # Use current $LrtConfig as base or create minimal config
            if ($LrtConfig) {
                $NewConfig = $LrtConfig | ConvertTo-Json -Depth 5 | ConvertFrom-Json
            } else {
                $NewConfig = [PSCustomObject]@{
                    General = [PSCustomObject]@{ CertPolicyRequired = $false }
                    Proxy = [PSCustomObject]@{ Required = $false; Host = ""; Port = ""; RequiresCredential = $false; Credential = "" }
                    LogRhythm = [PSCustomObject]@{ Version = "7.11.0"; BaseUrl = "https://[NOT_SET]:8501"; ApiKey = "" }
                }
            }
        }

        Write-Host ""
        Write-Host "  ================================================================" -ForegroundColor Cyan
        Write-Host "  LogRhythm.Tools Configuration Setup" -ForegroundColor Cyan
        Write-Host "  ================================================================" -ForegroundColor Cyan
        Write-Host ""

        #region: Certificate Policy
        if ($PSBoundParameters.ContainsKey('CertPolicyRequired')) {
            $NewConfig.General.CertPolicyRequired = $CertPolicyRequired
        } else {
            Write-Host "  [1/4] Certificate Policy" -ForegroundColor Yellow
            Write-Host "  Allow self-signed certificates? Recommended for lab/dev environments."
            $CertInput = Read-Host "  Enable cert policy bypass? (y/N)"
            if ($CertInput -match '^[Yy]') {
                $NewConfig.General.CertPolicyRequired = $true
            } else {
                $NewConfig.General.CertPolicyRequired = $false
            }
            Write-Host ""
        }
        #endregion

        #region: LogRhythm Version
        if ($PSBoundParameters.ContainsKey('Version')) {
            $NewConfig.LogRhythm.Version = $Version
        } else {
            Write-Host "  [2/4] LogRhythm SIEM Version" -ForegroundColor Yellow
            $CurrentVersion = $NewConfig.LogRhythm.Version
            $VersionInput = Read-Host "  Enter SIEM version (e.g., 7.11.0) [$CurrentVersion]"
            if ($VersionInput.Length -gt 0) {
                $NewConfig.LogRhythm.Version = $VersionInput
            }
            Write-Host ""
        }
        #endregion

        #region: LogRhythm BaseUrl
        if ($PSBoundParameters.ContainsKey('BaseUrl')) {
            $NewConfig.LogRhythm.BaseUrl = $BaseUrl
        } else {
            Write-Host "  [3/4] LogRhythm API Base URL" -ForegroundColor Yellow
            Write-Host "  Format: https://hostname:8501"
            $CurrentUrl = $NewConfig.LogRhythm.BaseUrl
            if ($CurrentUrl -match '\[NOT_SET\]') { $CurrentUrl = "" }
            $UrlInput = Read-Host "  Enter API base URL [$CurrentUrl]"
            if ($UrlInput.Length -gt 0) {
                # Normalize: strip trailing slash
                $UrlInput = $UrlInput.TrimEnd('/')
                $NewConfig.LogRhythm.BaseUrl = $UrlInput
            }
            Write-Host ""
        }
        #endregion

        #region: LogRhythm API Key
        $SaveApiKey = $null
        if ($PSBoundParameters.ContainsKey('ApiKey')) {
            $SaveApiKey = $ApiKey
        } else {
            Write-Host "  [4/4] LogRhythm API Key" -ForegroundColor Yellow
            Write-Host "  Enter your LogRhythm API token (press Enter to skip)."
            $TokenInput = Read-Host "  API Token" -AsSecureString
            # Check if the user entered anything
            $TokenPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
                [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($TokenInput)
            )
            if ($TokenPlain.Length -gt 0) {
                $SaveApiKey = [PSCredential]::new("LrApiKey", $TokenInput)
            }
            Write-Host ""
        }
        #endregion

        # Save JSON config (without secrets)
        if ($PSCmdlet.ShouldProcess($ConfigFilePath, "Save configuration")) {
            $NewConfig.LogRhythm.ApiKey = ""
            $NewConfig | ConvertTo-Json -Depth 5 | Set-Content -Path $ConfigFilePath -Encoding UTF8
            Write-Verbose "[$Me]: Configuration saved to $ConfigFilePath"
        }

        # Save API key as encrypted XML
        if ($null -ne $SaveApiKey) {
            $KeyFilePath = Join-Path -Path $ConfigDirPath -ChildPath "LogRhythm.ApiKey.xml"
            if ($PSCmdlet.ShouldProcess($KeyFilePath, "Save encrypted API key")) {
                Export-Clixml -Path $KeyFilePath -InputObject $SaveApiKey
                Write-Verbose "[$Me]: API key saved to $KeyFilePath"
            }
        }

        # Update in-memory config
        $script:LrtConfig = Get-Content -Path $ConfigFilePath -Raw | ConvertFrom-Json

        # Reload API key into memory
        if ($null -ne $SaveApiKey) {
            $script:LrtConfig.LogRhythm.ApiKey = $SaveApiKey
        }

        # Also update the global scope for the current session
        Set-Variable -Name LrtConfig -Value $script:LrtConfig -Scope Global

        Write-Host ""
        Write-Host "  ================================================================" -ForegroundColor Green
        Write-Host "  Configuration saved successfully!" -ForegroundColor Green
        Write-Host "  ================================================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "  Config file: $ConfigFilePath" -ForegroundColor Cyan
        if ($null -ne $SaveApiKey) {
            Write-Host "  API key:     $ConfigDirPath\LogRhythm.ApiKey.xml (encrypted)" -ForegroundColor Cyan
        }
        Write-Host ""
        Write-Host "  Next steps:" -ForegroundColor Yellow
        Write-Host "  - Run Test-LrtConfiguration -TestConnectivity to verify your connection"
        Write-Host "  - Use Set-LrtConfiguration -Service <name> to configure additional services"
        Write-Host "  - Run Get-LrtConfiguration to view current settings"
        Write-Host ""

        if ($PassThru) {
            return $script:LrtConfig
        }
    }

    End { }
}
