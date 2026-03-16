InModuleScope 'LogRhythm.Tools' {
    Describe "LogRhythm.Tools: Get-LrLogVolume" -Tag 'Unit' {
        BeforeAll {
            $MockVolumeResponse = [PSCustomObject]@{
                entityName = "Primary Site"
                logCount   = 1250000
                minDate    = "2026-03-01T00:00:00Z"
                maxDate    = "2026-03-07T00:00:00Z"
            }
            Mock Invoke-RestAPIMethod { return $MockVolumeResponse }
            Mock Enable-TrustAllCertsPolicy { }
        }
    
        Context "Input validation" {
            It "Should have CmdletBinding attribute" {
                (Get-Command Get-LrLogVolume).CmdletBinding | Should -BeTrue
            }
    
            It "Should have mandatory StartDate parameter" {
                $attrs = (Get-Command Get-LrLogVolume).Parameters['StartDate'].Attributes
                $attrs.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -BeTrue
            }
    
            It "Should have mandatory EndDate parameter" {
                $attrs = (Get-Command Get-LrLogVolume).Parameters['EndDate'].Attributes
                $attrs.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -BeTrue
            }
    
            It "Should accept datetime type for StartDate" {
                (Get-Command Get-LrLogVolume).Parameters['StartDate'].ParameterType.Name | Should -Be 'DateTime'
            }
    
            It "Should accept datetime type for EndDate" {
                (Get-Command Get-LrLogVolume).Parameters['EndDate'].ParameterType.Name | Should -Be 'DateTime'
            }
        }
    
        Context "API response handling" {
            It "Should return log volume data on success" {
                $result = Get-LrLogVolume -StartDate "2026-03-01" -EndDate "2026-03-07"
                $result | Should -Not -BeNullOrEmpty
                $result.logCount | Should -Be 1250000
            }
    
            It "Should call Invoke-RestAPIMethod with POST method" {
                Get-LrLogVolume -StartDate "2026-03-01" -EndDate "2026-03-07" | Out-Null
                Should -Invoke Invoke-RestAPIMethod -ParameterFilter {
                    $Method -eq 'POST' -or $Method -eq $HttpMethod.Post
                }
            }
    
            It "Should target the lr-metrics-api logvolume endpoint" {
                Get-LrLogVolume -StartDate "2026-03-01" -EndDate "2026-03-07" | Out-Null
                Should -Invoke Invoke-RestAPIMethod -ParameterFilter {
                    $Uri -match 'lr-metrics-api/logvolume'
                }
            }
    
            It "Should include minDate and maxDate in request body" {
                Get-LrLogVolume -StartDate "2026-03-01" -EndDate "2026-03-07" | Out-Null
                Should -Invoke Invoke-RestAPIMethod -ParameterFilter {
                    $Body -match 'minDate' -and $Body -match 'maxDate'
                }
            }
    
            It "Should include groupBy Entity in request body" {
                Get-LrLogVolume -StartDate "2026-03-01" -EndDate "2026-03-07" | Out-Null
                Should -Invoke Invoke-RestAPIMethod -ParameterFilter {
                    $Body -match '"fieldName".*"Entity"'
                }
            }
    
            It "Should pass Origin as cmdlet name" {
                Get-LrLogVolume -StartDate "2026-03-01" -EndDate "2026-03-07" | Out-Null
                Should -Invoke Invoke-RestAPIMethod -ParameterFilter {
                    $Origin -eq 'Get-LrLogVolume'
                }
            }
        }
    
        Context "Error handling" {
            It "Should return ErrorObject when API returns error" {
                Mock Invoke-RestAPIMethod {
                    return [PSCustomObject]@{
                        Error  = $true
                        Type   = "System.Net.Http"
                        Code   = 500
                        Note   = "Internal server error"
                        Raw    = $null
                        Origin = "Get-LrLogVolume"
                    }
                }
    
                $result = Get-LrLogVolume -StartDate "2026-03-01" -EndDate "2026-03-07"
                $result.Error | Should -BeTrue
                $result.Code | Should -Be 500
            }
    
            It "Should reject unsupported LR versions (7.0-7.4)" {
                $origVersion = $LrtConfig.LogRhythm.Version
                try {
                    $LrtConfig.LogRhythm.Version = "7.3.5"
                    $result = Get-LrLogVolume -StartDate "2026-03-01" -EndDate "2026-03-07"
                    $result.Error | Should -BeTrue
                    $result.Note | Should -Match "7.5.0"
                } finally {
                    $LrtConfig.LogRhythm.Version = $origVersion
                }
            }
        }
    }
}
