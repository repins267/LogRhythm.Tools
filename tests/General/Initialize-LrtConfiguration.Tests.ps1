InModuleScope 'LogRhythm.Tools' {
    Describe "LogRhythm.Tools: Initialize-LrtConfiguration" -Tag 'Unit' {
        BeforeAll {
            Mock Invoke-RestAPIMethod { return [PSCustomObject]@{ id = 1 } }
            Mock Enable-TrustAllCertsPolicy { }
        }
    
        Context "Input validation" {
            It "Should have CmdletBinding attribute" {
                (Get-Command Initialize-LrtConfiguration).CmdletBinding | Should -BeTrue
            }
    
            It "Should have BaseUrl parameter" {
                (Get-Command Initialize-LrtConfiguration).Parameters['BaseUrl'] | Should -Not -BeNullOrEmpty
            }
    
            It "Should have Version parameter" {
                (Get-Command Initialize-LrtConfiguration).Parameters['Version'] | Should -Not -BeNullOrEmpty
            }
    
            It "Should have ApiKey parameter" {
                (Get-Command Initialize-LrtConfiguration).Parameters['ApiKey'] | Should -Not -BeNullOrEmpty
            }
    
            It "Should have CertPolicyRequired parameter" {
                (Get-Command Initialize-LrtConfiguration).Parameters['CertPolicyRequired'] | Should -Not -BeNullOrEmpty
            }
    
            It "Should have Force switch parameter" {
                $param = (Get-Command Initialize-LrtConfiguration).Parameters['Force']
                $param | Should -Not -BeNullOrEmpty
                $param.ParameterType.Name | Should -Be 'SwitchParameter'
            }
    
            It "Should have PassThru parameter" {
                $param = (Get-Command Initialize-LrtConfiguration).Parameters['PassThru']
                $param | Should -Not -BeNullOrEmpty
                $param.ParameterType.Name | Should -Be 'SwitchParameter'
            }
        }
    
        Context "API response handling" {
            It "Should return expected object on success" {
                # Test stub
            }
        }
    
        Context "Error handling" {
            It "Should return ErrorObject on API failure" {
                Mock Invoke-RestAPIMethod { return [PSCustomObject]@{ Error = $true; Type = "test"; Code = "500"; Note = "mock error"; Raw = $null } }
                # Test error path
            }
        }
    }
}
