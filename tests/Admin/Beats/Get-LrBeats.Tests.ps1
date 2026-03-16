InModuleScope 'LogRhythm.Tools' {
    Describe "LogRhythm.Tools: Get-LrBeats" -Tag 'Unit' {
        BeforeAll {
            $MockBeatResponse = @(
                [PSCustomObject]@{ id = 1; name = "Windows Sysmon"; type = "Windows"; status = "Active" }
                [PSCustomObject]@{ id = 2; name = "Linux Syslog"; type = "Linux"; status = "Active" }
                [PSCustomObject]@{ id = 3; name = "Network Monitor"; type = "Network"; status = "Retired" }
            )
            Mock Invoke-RestAPIMethod { return $MockBeatResponse }
            Mock Enable-TrustAllCertsPolicy { }
        }
    
        Context "Input validation" {
            It "Should have CmdletBinding attribute" {
                (Get-Command Get-LrBeats).CmdletBinding | Should -BeTrue
            }
    
            It "Should have optional Name parameter" {
                $param = (Get-Command Get-LrBeats).Parameters['Name']
                $param | Should -Not -BeNullOrEmpty
                $param.Attributes.Mandatory | Should -Not -Contain $true
            }
    
            It "Should have default PageValuesCount of 1000" {
                $param = (Get-Command Get-LrBeats).Parameters['PageValuesCount']
                $param | Should -Not -BeNullOrEmpty
            }
    
            It "Should have default PageCount of 1" {
                $param = (Get-Command Get-LrBeats).Parameters['PageCount']
                $param | Should -Not -BeNullOrEmpty
            }
    
            It "Should have optional Credential parameter" {
                (Get-Command Get-LrBeats).Parameters.Keys | Should -Contain 'Credential'
            }
        }
    
        Context "API response handling" {
            It "Should return all beats when no filter specified" {
                $result = Get-LrBeats
                $result.Count | Should -Be 3
            }
    
            It "Should call Invoke-RestAPIMethod with correct HTTP method" {
                Get-LrBeats | Out-Null
                Should -Invoke Invoke-RestAPIMethod -ParameterFilter {
                    $Method -eq 'GET' -or $Method -eq $HttpMethod.Get
                }
            }
    
            It "Should call Invoke-RestAPIMethod with Origin parameter" {
                Get-LrBeats | Out-Null
                Should -Invoke Invoke-RestAPIMethod -ParameterFilter {
                    $Origin -eq 'Get-LrBeats'
                }
            }
    
            It "Should construct URL targeting lr-admin-api beats endpoint" {
                Get-LrBeats | Out-Null
                Should -Invoke Invoke-RestAPIMethod -ParameterFilter {
                    $Uri -match 'lr-admin-api.*beats'
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
                        Note   = "Unauthorized to access resource.  Validate API Key."
                        Raw    = $null
                        Origin = "Get-LrBeats"
                        Uri    = "https://localhost:8501/lr-admin-api/beats/"
                        Method = "GET"
                        Body   = $null
                    }
                }
    
                $result = Get-LrBeats
                $result.Error | Should -BeTrue
                $result.Code | Should -Be 401
            }
        }
    }
}
