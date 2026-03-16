InModuleScope 'LogRhythm.Tools' {
    Describe "LogRhythm.Tools: Get-LrAlarmUrl" -Tag 'Unit' {
        BeforeAll {
            $MockUrlResponse = [PSCustomObject]@{
                url = "https://logrhythm.example.com/alarms"
            }
            Mock Invoke-RestAPIMethod { return $MockUrlResponse }
            Mock Enable-TrustAllCertsPolicy { }
        }
    
        Context "Input validation" {
            It "Should have CmdletBinding attribute" {
                (Get-Command Get-LrAlarmUrl).CmdletBinding | Should -BeTrue
            }
    
            It "Should have optional Credential parameter" {
                $param = (Get-Command Get-LrAlarmUrl).Parameters['Credential']
                $param | Should -Not -BeNullOrEmpty
                $param.Attributes.Mandatory | Should -Not -Contain $true
            }
        }
    
        Context "API response handling" {
            It "Should return alarm URL on success" {
                $result = Get-LrAlarmUrl
                $result | Should -Not -BeNullOrEmpty
                $result.url | Should -Be "https://logrhythm.example.com/alarms"
            }
    
            It "Should call Invoke-RestAPIMethod with GET method" {
                Get-LrAlarmUrl | Out-Null
                Should -Invoke Invoke-RestAPIMethod -ParameterFilter {
                    $Method -eq 'GET' -or $Method -eq $HttpMethod.Get
                }
            }
    
            It "Should target the lr-alarm-api alarms/url endpoint" {
                Get-LrAlarmUrl | Out-Null
                Should -Invoke Invoke-RestAPIMethod -ParameterFilter {
                    $Uri -match 'lr-alarm-api/alarms/url'
                }
            }
    
            It "Should pass Origin as cmdlet name" {
                Get-LrAlarmUrl | Out-Null
                Should -Invoke Invoke-RestAPIMethod -ParameterFilter {
                    $Origin -eq 'Get-LrAlarmUrl'
                }
            }
        }
    
        Context "Error handling" {
            It "Should return ErrorObject when API returns error" {
                Mock Invoke-RestAPIMethod {
                    return [PSCustomObject]@{
                        Error  = $true
                        Type   = "System.Net.Http"
                        Code   = 403
                        Note   = "Access Forbidden.  Validate API Key."
                        Raw    = $null
                        Origin = "Get-LrAlarmUrl"
                    }
                }
    
                $result = Get-LrAlarmUrl
                $result.Error | Should -BeTrue
                $result.Code | Should -Be 403
            }
    
            It "Should reject LR versions before 7.7.0" {
                $origVersion = $LrtConfig.LogRhythm.Version
                try {
                    $LrtConfig.LogRhythm.Version = "7.6.2"
                    $result = Get-LrAlarmUrl
                    $result.Error | Should -BeTrue
                    $result.Note | Should -Match "7.7.0"
                } finally {
                    $LrtConfig.LogRhythm.Version = $origVersion
                }
            }
        }
    }
}
