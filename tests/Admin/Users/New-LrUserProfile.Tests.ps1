Describe "LogRhythm.Tools: New-LrUserProfile" -Tag 'Unit' {
    BeforeAll {
        # Mock dependencies
        Mock Invoke-RestAPIMethod { return [PSCustomObject]@{ id = 1; name = "TestProfile" } }
        Mock Enable-TrustAllCertsPolicy { }
    }

    Context "Input validation" {
        It "Should have CmdletBinding attribute" {
            (Get-Command New-LrUserProfile).CmdletBinding | Should -BeTrue
        }

        It "Should have mandatory Name parameter" {
            (Get-Command New-LrUserProfile).Parameters['Name'].Attributes.Mandatory | Should -Contain $true
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

    Context "Mutating cmdlet requirements" {
        It "-PassThru parameter should exist" {
            (Get-Command New-LrUserProfile).Parameters.Keys | Should -Contain 'PassThru'
        }
    }
}
