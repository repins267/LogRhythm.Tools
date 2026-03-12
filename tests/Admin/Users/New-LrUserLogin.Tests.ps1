Describe "LogRhythm.Tools: New-LrUserLogin" -Tag 'Unit' {
    BeforeAll {
        # Mock dependencies
        Mock Invoke-RestAPIMethod { return [PSCustomObject]@{ id = 1; userName = "TestLogin" } }
        Mock Enable-TrustAllCertsPolicy { }
    }

    Context "Input validation" {
        It "Should have CmdletBinding attribute" {
            (Get-Command New-LrUserLogin).CmdletBinding | Should -BeTrue
        }

        It "Should have mandatory PersonId parameter" {
            (Get-Command New-LrUserLogin).Parameters['PersonId'].Attributes.Mandatory | Should -Contain $true
        }

        It "Should have mandatory UserName parameter" {
            (Get-Command New-LrUserLogin).Parameters['UserName'].Attributes.Mandatory | Should -Contain $true
        }

        It "Should have mandatory Password parameter" {
            (Get-Command New-LrUserLogin).Parameters['Password'].Attributes.Mandatory | Should -Contain $true
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
            (Get-Command New-LrUserLogin).Parameters.Keys | Should -Contain 'PassThru'
        }
    }
}
