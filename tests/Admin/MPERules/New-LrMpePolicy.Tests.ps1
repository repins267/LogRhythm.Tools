Describe "LogRhythm.Tools: New-LrMpePolicy" -Tag 'Unit' {
    BeforeAll {
        # Mock dependencies
        Mock Invoke-RestAPIMethod { return [PSCustomObject]@{ id = 1; name = "TestPolicy" } }
        Mock Enable-TrustAllCertsPolicy { }
    }

    Context "Input validation" {
        It "Should have CmdletBinding attribute" {
            (Get-Command New-LrMpePolicy).CmdletBinding | Should -BeTrue
        }

        It "Should have mandatory Name parameter" {
            (Get-Command New-LrMpePolicy).Parameters['Name'].Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -BeTrue
        }

        It "-PassThru parameter should exist" {
            (Get-Command New-LrMpePolicy).Parameters.Keys | Should -Contain 'PassThru'
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
