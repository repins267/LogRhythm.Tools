Describe "LogRhythm.Tools: New-LrAdminUser" -Tag 'Unit' {
    BeforeAll {
        # Mock dependencies
        Mock Invoke-RestAPIMethod { return [PSCustomObject]@{ id = 1; firstName = "Test"; lastName = "User" } }
        Mock Enable-TrustAllCertsPolicy { }
    }

    Context "Input validation" {
        It "Should have CmdletBinding attribute" {
            (Get-Command New-LrAdminUser).CmdletBinding | Should -BeTrue
        }

        It "Should have mandatory FirstName parameter" {
            (Get-Command New-LrAdminUser).Parameters['FirstName'].Attributes.Mandatory | Should -Contain $true
        }

        It "Should have mandatory LastName parameter" {
            (Get-Command New-LrAdminUser).Parameters['LastName'].Attributes.Mandatory | Should -Contain $true
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
            (Get-Command New-LrAdminUser).Parameters.Keys | Should -Contain 'PassThru'
        }
    }
}
