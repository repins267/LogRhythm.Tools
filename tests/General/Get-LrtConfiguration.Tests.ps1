Describe "LogRhythm.Tools: Get-LrtConfiguration" -Tag 'Unit' {
    BeforeAll {
        Mock Invoke-RestAPIMethod { return [PSCustomObject]@{ id = 1 } }
        Mock Enable-TrustAllCertsPolicy { }
    }

    Context "Input validation" {
        It "Should have CmdletBinding attribute" {
            (Get-Command Get-LrtConfiguration).CmdletBinding | Should -BeTrue
        }

        It "Should have optional Service parameter" {
            $param = (Get-Command Get-LrtConfiguration).Parameters['Service']
            $param | Should -Not -BeNullOrEmpty
            $param.Attributes.Mandatory | Should -Not -BeTrue
        }

        It "Should have ShowSecrets switch parameter" {
            $param = (Get-Command Get-LrtConfiguration).Parameters['ShowSecrets']
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
