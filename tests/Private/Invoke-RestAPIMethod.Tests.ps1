#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

InModuleScope 'LogRhythm.Tools' {
    Describe "Invoke-RestAPIMethod" -Tag 'Unit' {

        # ================================================================
        # 1. Parameter validation
        # ================================================================
        Context "Parameter validation and defaults" {
            BeforeAll {
                Mock Invoke-RestMethod { return @{ ok = $true } }
            }

            It "Should have mandatory Uri parameter" {
                (Get-Command Invoke-RestAPIMethod).Parameters['Uri'].Attributes |
                    Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                    ForEach-Object { $_.Mandatory | Should -BeTrue }
            }

            It "Should have mandatory Method parameter" {
                (Get-Command Invoke-RestAPIMethod).Parameters['Method'].Attributes |
                    Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                    ForEach-Object { $_.Mandatory | Should -BeTrue }
            }

            It "Should accept optional Headers parameter" {
                (Get-Command Invoke-RestAPIMethod).Parameters.Keys | Should -Contain 'Headers'
            }

            It "Should accept optional Body parameter" {
                (Get-Command Invoke-RestAPIMethod).Parameters.Keys | Should -Contain 'Body'
            }

            It "Should accept optional Origin parameter" {
                (Get-Command Invoke-RestAPIMethod).Parameters.Keys | Should -Contain 'Origin'
            }

            It "Should accept optional MaxRetries parameter" {
                (Get-Command Invoke-RestAPIMethod).Parameters.Keys | Should -Contain 'MaxRetries'
            }

            It "Should accept optional Delay parameter" {
                (Get-Command Invoke-RestAPIMethod).Parameters.Keys | Should -Contain 'Delay'
            }
        }

        # ================================================================
        # 2. Successful response passthrough
        # ================================================================
        Context "Successful response" {
            BeforeAll {
                Mock Invoke-RestMethod { return [PSCustomObject]@{ id = 42; name = 'widget' } }
            }

            It "Should return the raw Invoke-RestMethod response on success" {
                $result = Invoke-RestAPIMethod -Uri 'https://api.example.com/items' -Method 'GET'
                $result.id   | Should -Be 42
                $result.name | Should -Be 'widget'
            }

            It "Should call Invoke-RestMethod exactly once when no errors occur" {
                Invoke-RestAPIMethod -Uri 'https://api.example.com/items' -Method 'GET' | Out-Null
                Should -Invoke Invoke-RestMethod -Times 1 -Exactly
            }

            It "Should pass Body to Invoke-RestMethod when provided" {
                Mock Invoke-RestMethod { return @{ ok = $true } }
                Invoke-RestAPIMethod -Uri 'https://api.example.com/items' -Method 'POST' -Body '{"a":1}' | Out-Null
                Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter { $Body -eq '{"a":1}' }
            }

            It "Should NOT pass Body to Invoke-RestMethod when Body is empty" {
                Mock Invoke-RestMethod { return @{ ok = $true } }
                Invoke-RestAPIMethod -Uri 'https://api.example.com/items' -Method 'GET' | Out-Null
                Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter { -not $Body }
            }
        }

        # ================================================================
        # 3. ErrorObject structure
        # ================================================================
        Context "Error object structure" {
            # The function's catch block reads properties from the ErrorRecord.
            # Instead of fighting mock ErrorRecords through throw/catch,
            # we test the ErrorObject template directly.

            It "ErrorObject should have all required properties" {
                # Invoke with a non-retryable mock error
                Mock Invoke-RestMethod { throw "Simulated API error" }

                $result = Invoke-RestAPIMethod -Uri 'https://api.example.com/test' -Method 'GET' -Origin 'Test-Caller'
                $result.Error  | Should -BeTrue
                $result.Origin | Should -Be 'Test-Caller'
                $result.Uri    | Should -Be 'https://api.example.com/test'
                $result.Method | Should -Be 'GET'
            }

            It "Should populate Body in ErrorObject when Body is provided" {
                Mock Invoke-RestMethod { throw "Simulated error" }
                $body = '{"name":"test"}'
                $result = Invoke-RestAPIMethod -Uri 'https://api.example.com/create' -Method 'POST' -Body $body -Origin 'Test'
                $result.Error | Should -BeTrue
                $result.Body  | Should -Be $body
            }

            It "Should have null Body when no Body parameter was given" {
                Mock Invoke-RestMethod { throw "Simulated error" }
                $result = Invoke-RestAPIMethod -Uri 'https://api.example.com/get' -Method 'GET'
                $result.Body | Should -BeNullOrEmpty
            }

            It "Should have Raw property populated with the caught exception" {
                Mock Invoke-RestMethod { throw "Simulated error" }
                $result = Invoke-RestAPIMethod -Uri 'https://api.example.com/test' -Method 'GET'
                $result.Raw | Should -Not -BeNullOrEmpty
            }

            It "Should have Request property defined in ErrorObject" {
                Mock Invoke-RestMethod { throw "Simulated error" }
                $result = Invoke-RestAPIMethod -Uri 'https://api.example.com/test' -Method 'GET'
                # Request property exists (sourced from $_.CategoryInfo.Activity)
                $result.PSObject.Properties.Name | Should -Contain 'Request'
            }
        }

        # ================================================================
        # 4. Origin tracking
        # ================================================================
        Context "Origin tracking" {
            BeforeAll {
                Mock Invoke-RestMethod { throw "error" }
            }

            It "Should set Origin in ErrorObject to the caller name" {
                $result = Invoke-RestAPIMethod -Uri 'https://api.example.com/auth' -Method 'GET' -Origin 'Get-LrUserProfile'
                $result.Origin | Should -Be 'Get-LrUserProfile'
            }

            It "Should have null Origin when Origin parameter is not supplied" {
                $result = Invoke-RestAPIMethod -Uri 'https://api.example.com/auth' -Method 'GET'
                $result.Origin | Should -BeNullOrEmpty
            }
        }

        # ================================================================
        # 5. Retry behavior (429)
        # ================================================================
        Context "Retry on HTTP 429" {
            It "Should retry when Invoke-RestMethod throws a 429 then succeeds" {
                # The function reads $_.Exception.Response.StatusCode.value__ in its catch.
                # We need to construct an exception whose Response property has the right shape.
                $script:callCount = 0
                Mock Invoke-RestMethod {
                    $script:callCount++
                    if ($script:callCount -le 1) {
                        $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::TooManyRequests)
                        $ex = [Microsoft.PowerShell.Commands.HttpResponseException]::new("Response status code does not indicate success: 429", $response)
                        throw $ex
                    }
                    return @{ status = 'ok' }
                }
                Mock Start-Sleep {}

                $result = Invoke-RestAPIMethod -Uri 'https://api.example.com/throttled' -Method 'GET' -Delay 10
                $script:callCount | Should -BeGreaterThan 1
            }
        }

        # ================================================================
        # 6. 500 retry for specific Origins
        # ================================================================
        Context "HTTP 500 retry for List Item operations" {
            It "Should treat 500 as retryable when Origin is Add-LrListItem" {
                $script:callCount = 0
                Mock Invoke-RestMethod {
                    $script:callCount++
                    if ($script:callCount -le 1) {
                        $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::InternalServerError)
                        $ex = [Microsoft.PowerShell.Commands.HttpResponseException]::new("Response status code does not indicate success: 500", $response)
                        throw $ex
                    }
                    return @{ done = $true }
                }
                Mock Start-Sleep {}

                $result = Invoke-RestAPIMethod -Uri 'https://api.example.com/list' -Method 'POST' -Origin 'Add-LrListItem' -Delay 10
                $script:callCount | Should -BeGreaterThan 1
            }

            It "Should NOT retry 500 for unrelated Origins" {
                Mock Invoke-RestMethod {
                    $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::InternalServerError)
                    $ex = [Microsoft.PowerShell.Commands.HttpResponseException]::new("Response status code does not indicate success: 500", $response)
                    throw $ex
                }

                $result = Invoke-RestAPIMethod -Uri 'https://api.example.com/other' -Method 'GET' -Origin 'Get-LrLists'
                $result.Error | Should -BeTrue
            }
        }

        # ================================================================
        # 7. ContentType passthrough
        # ================================================================
        Context "ContentType handling" {
            It "Should pass ContentType to Invoke-RestMethod" {
                Mock Invoke-RestMethod { return @{ ok = $true } }
                Invoke-RestAPIMethod -Uri 'https://api.example.com/test' -Method 'POST' -Body '{}' -ContentType 'text/plain' | Out-Null
                Should -Invoke Invoke-RestMethod -ParameterFilter { $ContentType -eq 'text/plain' }
            }
        }
    }
}
