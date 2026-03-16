InModuleScope 'LogRhythm.Tools' {
    Describe "LogRhythm.Tools: Add-LrHostRole" -Tag 'Unit' {
        BeforeAll {
            $MockSuccessResponse = [PSCustomObject]@{ id = 1; name = "Mediator"; hostId = 2 }
            Mock Invoke-RestAPIMethod { return $MockSuccessResponse }
            Mock Enable-TrustAllCertsPolicy { }
        }
    
        Context "Input validation" {
            It "Should have CmdletBinding attribute" {
                (Get-Command Add-LrHostRole).CmdletBinding | Should -BeTrue
            }
    
            It "Should have mandatory Id parameter" {
                (Get-Command Add-LrHostRole).Parameters['Id'].Attributes.Mandatory | Should -Contain $true
            }
    
            It "Should have mandatory RoleName parameter" {
                (Get-Command Add-LrHostRole).Parameters['RoleName'].Attributes.Mandatory | Should -Contain $true
            }
    
            It "Should accept Id from pipeline by property name" {
                $param = (Get-Command Add-LrHostRole).Parameters['Id']
                $param.Attributes.ValueFromPipelineByPropertyName | Should -Contain $true
            }
    
            It "Should have Id as int32 type" {
                (Get-Command Add-LrHostRole).Parameters['Id'].ParameterType.Name | Should -Be 'Int32'
            }
    
            It "Should have RoleName as string type" {
                (Get-Command Add-LrHostRole).Parameters['RoleName'].ParameterType.Name | Should -Be 'String'
            }
        }
    
        Context "Mutating cmdlet requirements" {
            It "-PassThru parameter should exist" {
                (Get-Command Add-LrHostRole).Parameters.Keys | Should -Contain 'PassThru'
            }
    
            It "-PassThru should be a switch parameter" {
                (Get-Command Add-LrHostRole).Parameters['PassThru'].ParameterType.Name | Should -Be 'SwitchParameter'
            }
        }
    
        Context "API response handling" {
            It "Should call Invoke-RestAPIMethod with POST method" {
                Add-LrHostRole -Id 2 -RoleName "Mediator" -PassThru | Out-Null
                Should -Invoke Invoke-RestAPIMethod -ParameterFilter {
                    $Method -eq 'POST' -or $Method -eq $HttpMethod.Post
                }
            }
    
            It "Should construct URL with host Id in path" {
                Add-LrHostRole -Id 2 -RoleName "Mediator" -PassThru | Out-Null
                Should -Invoke Invoke-RestAPIMethod -ParameterFilter {
                    $Uri -match 'lr-admin-api/hosts/2/roles'
                }
            }
    
            It "Should include role name in request body" {
                Add-LrHostRole -Id 2 -RoleName "Mediator" -PassThru | Out-Null
                Should -Invoke Invoke-RestAPIMethod -ParameterFilter {
                    $Body -match '"name".*"Mediator"'
                }
            }
    
            It "Should return response when -PassThru is used" {
                $result = Add-LrHostRole -Id 2 -RoleName "Mediator" -PassThru
                $result | Should -Not -BeNullOrEmpty
                $result.id | Should -Be 1
            }
    
            It "Should return nothing without -PassThru" {
                $result = Add-LrHostRole -Id 2 -RoleName "Mediator"
                $result | Should -BeNullOrEmpty
            }
    
            It "Should pass Origin parameter as cmdlet name" {
                Add-LrHostRole -Id 2 -RoleName "Mediator" -PassThru | Out-Null
                Should -Invoke Invoke-RestAPIMethod -ParameterFilter {
                    $Origin -eq 'Add-LrHostRole'
                }
            }
        }
    
        Context "Error handling" {
            It "Should return ErrorObject when API returns error" {
                Mock Invoke-RestAPIMethod {
                    return [PSCustomObject]@{
                        Error  = $true
                        Type   = "System.Net.Http"
                        Code   = 404
                        Note   = "Resource not found."
                        Raw    = $null
                        Origin = "Add-LrHostRole"
                        Uri    = "https://localhost:8501/lr-admin-api/hosts/999/roles/"
                        Method = "POST"
                        Body   = '{"name":"BadRole"}'
                    }
                }
    
                $result = Add-LrHostRole -Id 999 -RoleName "BadRole" -PassThru
                $result.Error | Should -BeTrue
                $result.Code | Should -Be 404
            }
    
            It "Should reject unsupported LR versions (7.0-7.4)" {
                $origVersion = $LrtConfig.LogRhythm.Version
                try {
                    $LrtConfig.LogRhythm.Version = "7.4.0"
                    $result = Add-LrHostRole -Id 2 -RoleName "Mediator" -PassThru
                    $result.Error | Should -BeTrue
                    $result.Note | Should -Match "7.5.0"
                } finally {
                    $LrtConfig.LogRhythm.Version = $origVersion
                }
            }
        }
    }
}
