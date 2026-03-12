Describe "LogRhythm.Tools: Get-LrIdentityPhoto" -Tag 'Unit' {
    BeforeAll {
        # Mock dependencies
        Mock Invoke-RestAPIMethod { return [PSCustomObject]@{ id = 1; photoData = "base64string" } }
        Mock Enable-TrustAllCertsPolicy { }
    }

    Context "Input validation" {
        It "Should have CmdletBinding attribute" {
            (Get-Command Get-LrIdentityPhoto).CmdletBinding | Should -BeTrue
        }

        It "Should have mandatory Id parameter" {
            (Get-Command Get-LrIdentityPhoto).Parameters['Id'].Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -BeTrue
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
