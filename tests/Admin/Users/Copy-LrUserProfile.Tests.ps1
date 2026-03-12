Describe "LogRhythm.Tools: Copy-LrUserProfile" -Tag 'Unit' {
    BeforeAll {
        # Mock dependencies
        Mock Invoke-RestAPIMethod { return [PSCustomObject]@{ id = 2; name = "TestProfile - Copy" } }
        Mock Enable-TrustAllCertsPolicy { }
    }

    Context "Input validation" {
        It "Should have CmdletBinding attribute" {
            (Get-Command Copy-LrUserProfile).CmdletBinding | Should -BeTrue
        }

        It "Should have mandatory Id parameter" {
            (Get-Command Copy-LrUserProfile).Parameters['Id'].Attributes.Mandatory | Should -Contain $true
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
            (Get-Command Copy-LrUserProfile).Parameters.Keys | Should -Contain 'PassThru'
        }
    }
}
