InModuleScope 'LogRhythm.Tools' {
    Describe "LogRhythm.Tools: New-LrAgent" -Tag 'Unit' {
        BeforeAll {
            # Mock dependencies
            Mock Invoke-RestAPIMethod { return [PSCustomObject]@{ id = 1 } }
            Mock Enable-TrustAllCertsPolicy { }
        }
    
        Context "Input validation" {
            It "Should have CmdletBinding attribute" {
                (Get-Command New-LrAgent).CmdletBinding | Should -BeTrue
            }
    
            It "Should have mandatory Name parameter" {
                (Get-Command New-LrAgent).Parameters['Name'].Attributes.Mandatory | Should -Contain $true
            }
    
            It "Should have mandatory AgentType parameter" {
                (Get-Command New-LrAgent).Parameters['AgentType'].Attributes.Mandatory | Should -Contain $true
            }
    
            It "-PassThru parameter should exist" {
                (Get-Command New-LrAgent).Parameters.Keys | Should -Contain 'PassThru'
            }
        }
    
        Context "API response handling" {
            It "Should return expected object on success" {
                # Test with mocked Invoke-RestAPIMethod
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
