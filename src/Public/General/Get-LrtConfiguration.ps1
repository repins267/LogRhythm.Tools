using namespace System
using namespace System.IO
using namespace System.Collections.Generic

Function Get-LrtConfiguration {
    <#
    .SYNOPSIS
        Display the current LogRhythm.Tools module configuration.
    .DESCRIPTION
        Get-LrtConfiguration returns the current module configuration from
        $LrtConfig. By default, API keys and credentials are masked for
        security. Use -ShowSecrets to reveal stored credential values.

        Optionally filter to a specific service section using the -Service
        parameter.
    .PARAMETER Service
        Optional name of a specific configuration section to return.
        Valid values include: General, Proxy, LogRhythm, Exabeam,
        LogRhythmEcho, ActiveDirectory, AzureAD, DefenderATP, Mimecast,
        RecordedFuture, VirusTotal, UrlScan, SecretServer, Shodan.
    .PARAMETER ShowSecrets
        Switch to reveal API key and credential values instead of masking them.
    .INPUTS
        None
    .OUTPUTS
        PSCustomObject representing the module configuration.
    .EXAMPLE
        PS C:\> Get-LrtConfiguration

        Returns all configuration sections with secrets masked.
    .EXAMPLE
        PS C:\> Get-LrtConfiguration -Service LogRhythm

        Returns only the LogRhythm configuration section.
    .EXAMPLE
        PS C:\> Get-LrtConfiguration -Service LogRhythm -ShowSecrets

        Returns the LogRhythm section with the API key visible.
    .NOTES
        LogRhythm-API
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateSet(
            "General", "Proxy", "LogRhythm", "Exabeam", "LogRhythmEcho",
            "ActiveDirectory", "AzureAD", "DefenderATP", "Mimecast",
            "RecordedFuture", "VirusTotal", "UrlScan", "SecretServer", "Shodan"
        )]
        [string] $Service,

        [Parameter(Mandatory = $false, Position = 1)]
        [switch] $ShowSecrets
    )

    Begin {
        $Me = $MyInvocation.MyCommand.Name
    }

    Process {
        if (-not $LrtConfig) {
            Write-Warning "[$Me]: No configuration loaded. Run Initialize-LrtConfiguration first."
            return
        }

        # Build output - deep clone to avoid modifying live config
        $ConfigJson = $LrtConfig | ConvertTo-Json -Depth 5
        $Output = $ConfigJson | ConvertFrom-Json

        # Mask secrets unless -ShowSecrets is specified
        if (-not $ShowSecrets) {
            foreach ($Category in $Output.PSObject.Properties) {
                if ($null -eq $Category.Value) { continue }
                $Props = $Category.Value.PSObject.Properties
                foreach ($Prop in $Props) {
                    if ($Prop.Name -eq "ApiKey" -and $Prop.Value) {
                        if ($Prop.Value -is [PSCredential]) {
                            $Category.Value.ApiKey = "********"
                        } elseif ($Prop.Value -is [string] -and $Prop.Value.Length -gt 0) {
                            $Category.Value.ApiKey = "********"
                        }
                    }
                    if ($Prop.Name -eq "Credential" -and $Prop.Value) {
                        if ($Prop.Value -is [PSCredential]) {
                            $Category.Value.Credential = "********"
                        } elseif ($Prop.Value -is [string] -and $Prop.Value.Length -gt 0) {
                            $Category.Value.Credential = "********"
                        }
                    }
                    if ($Prop.Name -eq "Token" -and $Prop.Value -is [string] -and $Prop.Value.Length -gt 0) {
                        $Category.Value.Token = "********"
                    }
                }
            }
        }

        # Filter to specific service if requested
        if ($Service) {
            if ($Output.PSObject.Properties.Name -contains $Service) {
                Write-Verbose "[$Me]: Returning configuration for service: $Service"
                return $Output.$Service
            } else {
                Write-Warning "[$Me]: Service '$Service' not found in configuration."
                return
            }
        }

        Write-Verbose "[$Me]: Returning full configuration."
        return $Output
    }

    End { }
}
