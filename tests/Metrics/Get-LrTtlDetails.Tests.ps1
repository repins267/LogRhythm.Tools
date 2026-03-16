InModuleScope 'LogRhythm.Tools' {
    Describe "LogRhythm.Tools: Get-LrTtlDetails" -Tag 'Unit' {
        BeforeAll {
            $MockTtlResponse = [PSCustomObject]@{
                online   = [PSCustomObject]@{ days = 30; logCount = 500000 }
                nearline = [PSCustomObject]@{ days = 90; logCount = 2000000 }
                archive  = [PSCustomObject]@{ days = 365; logCount = 10000000 }
            }
            Mock Invoke-RestAPIMethod { return $MockTtlResponse }
            Mock Enable-TrustAllCertsPolicy { }
        }
    
        Context "Input validation" {
            It "Should have CmdletBinding attribute" {
                (Get-Command Get-LrTtlDetails).CmdletBinding | Should -BeTrue
            }
    
            It "Should have optional Credential parameter" {
                (Get-Command Get-LrTtlDetails).Parameters.Keys | Should -Contain 'Credential'
            }
        }
    
        Context "API response handling" {
            It "Should return TTL details on success" {
                $result = Get-LrTtlDetails
                $result | Should -Not -BeNullOrEmpty
                $result.online.days | Should -Be 30
            }
    
            It "Should call Invoke-RestAPIMethod targeting lr-metrics-api" {
                Get-LrTtlDetails | Out-Null
                Should -Invoke Invoke-RestAPIMethod -ParameterFilter {
                    $Uri -match 'lr-metrics-api'
                }
            }
    
            It "Should pass Origin as cmdlet name" {
                Get-LrTtlDetails | Out-Null
                Should -Invoke Invoke-RestAPIMethod -ParameterFilter {
                    $Origin -eq 'Get-LrTtlDetails'
                }
            }
        }
    
        Context "Error handling" {
            It "Should return ErrorObject when API returns error" {
                Mock Invoke-RestAPIMethod {
                    return [PSCustomObject]@{
                        Error  = $true
                        Type   = "System.Net.Http"
                        Code   = 401
                        Note   = "Unauthorized"
                        Raw    = $null
                        Origin = "Get-LrTtlDetails"
                    }
                }
    
                $result = Get-LrTtlDetails
                $result.Error | Should -BeTrue
                $result.Code | Should -Be 401
            }
        }
    }
}
