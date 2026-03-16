#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

InModuleScope 'LogRhythm.Tools' {
    Describe "Enable-TrustAllCertsPolicy" -Tag 'Unit' {

        Context "Function existence" {
            It "Should be available as a private function in the module" {
                Get-Command Enable-TrustAllCertsPolicy -ErrorAction SilentlyContinue |
                    Should -Not -BeNullOrEmpty
            }
        }

        Context "TLS 1.2 protocol enforcement" {
            BeforeAll {
                # Save current state
                $script:origProtocol = [System.Net.ServicePointManager]::SecurityProtocol

                # Ensure LrtConfig exists with CertPolicyRequired = $false so we only
                # test the TLS line without side-effects from cert policy branches.
                $script:origConfig = if (Get-Variable -Name LrtConfig -Scope Script -ErrorAction SilentlyContinue) {
                    $LrtConfig
                } else { $null }
                $script:LrtConfig = [PSCustomObject]@{
                    General = [PSCustomObject]@{ CertPolicyRequired = $false }
                }
                Set-Variable -Name LrtConfig -Value $script:LrtConfig -Scope Script
            }

            AfterAll {
                [System.Net.ServicePointManager]::SecurityProtocol = $script:origProtocol
                if ($null -ne $script:origConfig) {
                    Set-Variable -Name LrtConfig -Value $script:origConfig -Scope Script
                }
            }

            It "Should set SecurityProtocol to include Tls12" {
                # Temporarily set a different protocol to verify the function changes it
                [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls11
                Enable-TrustAllCertsPolicy
                [System.Net.ServicePointManager]::SecurityProtocol | Should -Be ([System.Net.SecurityProtocolType]::Tls12)
            }
        }

        Context "PowerShell Core path (SkipCertificateCheck)" {
            BeforeAll {
                $script:LrtConfig = [PSCustomObject]@{
                    General = [PSCustomObject]@{ CertPolicyRequired = $true }
                }
                Set-Variable -Name LrtConfig -Value $script:LrtConfig -Scope Script

                # Clean up any existing default parameter
                $script:origDefaults = $PSDefaultParameterValues.Clone()
                $PSDefaultParameterValues.Remove('Invoke-RestMethod:SkipCertificateCheck')
            }

            AfterAll {
                # Restore
                $Global:PSDefaultParameterValues = $script:origDefaults
            }

            It "Should add SkipCertificateCheck default on PS Core when CertPolicyRequired is true" -Skip:($PSEdition -ne 'Core') {
                Enable-TrustAllCertsPolicy
                $PSDefaultParameterValues['Invoke-RestMethod:SkipCertificateCheck'] | Should -BeTrue
            }
        }

        Context "CertPolicyRequired disabled" {
            BeforeAll {
                $script:LrtConfig = [PSCustomObject]@{
                    General = [PSCustomObject]@{ CertPolicyRequired = $false }
                }
                Set-Variable -Name LrtConfig -Value $script:LrtConfig -Scope Script
            }

            It "Should not throw when CertPolicyRequired is false" {
                { Enable-TrustAllCertsPolicy } | Should -Not -Throw
            }
        }
    }
}
