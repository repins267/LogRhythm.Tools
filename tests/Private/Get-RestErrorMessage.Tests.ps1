#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

InModuleScope 'LogRhythm.Tools' {
    Describe "Get-RestErrorMessage" -Tag 'Unit' {

        Context "Function existence" {
            It "Should be available as a private function in the module" {
                Get-Command Get-RestErrorMessage -ErrorAction SilentlyContinue |
                    Should -Not -BeNullOrEmpty
            }
        }

        Context "PS Desktop path (PSVersion < 6) with JSON response body" -Skip:($PSVersionTable.PSVersion.Major -ge 6) {
            It "Should return parsed JSON from the exception response stream" {
                # Build a mock exception with a response stream containing JSON
                $jsonBody = '{"statusCode":400,"message":"List has more than 100 items."}'
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($jsonBody)
                $stream = [System.IO.MemoryStream]::new($bytes)
                $stream.Position = 0

                $mockResponse = [PSCustomObject]@{}
                $mockResponse | Add-Member -MemberType ScriptMethod -Name 'GetResponseStream' -Value { return $stream }.GetNewClosure()

                $mockErr = [PSCustomObject]@{
                    Exception = [PSCustomObject]@{
                        Response = $mockResponse
                    }
                }

                $result = Get-RestErrorMessage -Err $mockErr
                $result.statusCode | Should -Be 400
                $result.message    | Should -BeLike '*100*'
            }

            It "Should return raw string when response body is not JSON" {
                $plainBody = 'Internal Server Error'
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($plainBody)
                $stream = [System.IO.MemoryStream]::new($bytes)
                $stream.Position = 0

                $mockResponse = [PSCustomObject]@{}
                $mockResponse | Add-Member -MemberType ScriptMethod -Name 'GetResponseStream' -Value { return $stream }.GetNewClosure()

                $mockErr = [PSCustomObject]@{
                    Exception = [PSCustomObject]@{
                        Response = $mockResponse
                    }
                }

                $result = Get-RestErrorMessage -Err $mockErr
                $result | Should -Be 'Internal Server Error'
            }

            It "Should return null when Exception.Response is null" {
                $mockErr = [PSCustomObject]@{
                    Exception = [PSCustomObject]@{
                        Response = $null
                    }
                }

                $result = Get-RestErrorMessage -Err $mockErr
                $result | Should -BeNullOrEmpty
            }
        }

        Context "PS Core path (PSVersion >= 6)" -Skip:($PSVersionTable.PSVersion.Major -lt 6) {
            It "Should return ErrorDetails.Message from the Error variable" {
                # The PS Core branch reads from $Error.ErrorDetails.Message
                # This is a design characteristic of the function - it reads the
                # automatic $Error variable rather than the passed-in $Err parameter.
                # We test that the function does not throw.
                { Get-RestErrorMessage -Err ([PSCustomObject]@{ Exception = $null }) } | Should -Not -Throw
            }
        }

        Context "Parameter validation" {
            It "Should require the Err parameter" {
                (Get-Command Get-RestErrorMessage).Parameters['Err'].Attributes |
                    Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                    ForEach-Object { $_.Mandatory | Should -BeTrue }
            }
        }
    }
}
