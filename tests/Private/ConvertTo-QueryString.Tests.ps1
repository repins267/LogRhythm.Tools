#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

InModuleScope 'LogRhythm.Tools' {
    Describe "ConvertTo-QueryString" -Tag 'Unit' {

        Context "Function existence" {
            It "Should be available as a private function in the module" {
                { Get-Command ConvertTo-QueryString -ErrorAction Stop } | Should -Not -Throw
            }
        }

        Context "Single key-value pair" {
            It "Should return a query string starting with '?'" {
                $result = ConvertTo-QueryString -Params ([PSCustomObject]@{ name = "test" })
                $result | Should -Match '^\?'
            }

            It "Should contain the key and value" {
                $result = ConvertTo-QueryString -Params ([PSCustomObject]@{ name = "test" })
                $result | Should -Match 'name=test'
            }
        }

        Context "Multiple key-value pairs with PSCustomObject" {
            It "Should include all keys" {
                $result = ConvertTo-QueryString -Params ([PSCustomObject]@{ alpha = "1"; beta = "2"; gamma = "3" })
                $result | Should -Match 'alpha=1'
                $result | Should -Match 'beta=2'
                $result | Should -Match 'gamma=3'
            }

            It "Should separate pairs with '&'" {
                $result = ConvertTo-QueryString -Params ([PSCustomObject]@{ a = "1"; b = "2" })
                $result | Should -Match '&'
            }

            It "Should not have a trailing '&'" {
                $result = ConvertTo-QueryString -Params ([PSCustomObject]@{ a = "1"; b = "2" })
                $result | Should -Not -Match '&$'
            }
        }

        Context "Hashtable input" {
            It "Should handle hashtable via GetEnumerator" {
                $ht = @{ key1 = "val1" }
                $result = ConvertTo-QueryString -Params $ht
                $result | Should -Match 'key1=val1'
            }

            It "Should handle multiple hashtable entries" {
                $ht = @{ x = "10"; y = "20" }
                $result = ConvertTo-QueryString -Params $ht
                $result | Should -Match 'x=10'
                $result | Should -Match 'y=20'
            }
        }

        Context "Dictionary input" {
            It "Should handle Dictionary[string,string]" {
                $dict = [System.Collections.Generic.Dictionary[string,string]]::new()
                $dict.Add("count", "100")
                $dict.Add("offset", "0")
                $result = ConvertTo-QueryString -Params $dict
                $result | Should -Match 'count=100'
                $result | Should -Match 'offset=0'
            }
        }

        Context "Pipeline input" {
            It "Should work with pipeline input" {
                $result = [PSCustomObject]@{ search = "logs" } | ConvertTo-QueryString
                $result | Should -Match 'search=logs'
            }
        }

        Context "Empty input" {
            It "Should return empty string for an empty hashtable" {
                $result = ConvertTo-QueryString -Params @{}
                $result | Should -Be ""
            }

            It "Should return empty string for PSCustomObject with no properties" {
                $result = ConvertTo-QueryString -Params ([PSCustomObject]@{})
                $result | Should -Be ""
            }
        }

        Context "OmitNull switch" {
            It "Should omit keys with null values when -OmitNull is specified" {
                $obj = [PSCustomObject]@{ present = "yes"; missing = $null }
                $result = ConvertTo-QueryString -Params $obj -OmitNull
                $result | Should -Match 'present=yes'
                $result | Should -Not -Match 'missing'
            }

            It "Should omit keys with empty string values when -OmitNull is specified" {
                $obj = [PSCustomObject]@{ filled = "data"; empty = "" }
                $result = ConvertTo-QueryString -Params $obj -OmitNull
                $result | Should -Match 'filled=data'
                $result | Should -Not -Match 'empty='
            }

            It "Should include null values when -OmitNull is NOT specified" {
                $obj = [PSCustomObject]@{ a = "1"; b = $null }
                $result = ConvertTo-QueryString -Params $obj
                $result | Should -Match 'a=1'
                $result | Should -Match 'b='
            }
        }

        Context "Encode switch" {
            It "Should URI-encode the query string when -Encode is specified" {
                $obj = [PSCustomObject]@{ search = "hello world" }
                $result = ConvertTo-QueryString -Params $obj -Encode
                $result | Should -Match 'hello%20world'
            }

            It "Should NOT encode when -Encode is not specified" {
                $obj = [PSCustomObject]@{ search = "hello world" }
                $result = ConvertTo-QueryString -Params $obj
                $result | Should -Match 'hello world'
            }
        }

        Context "Boolean values" {
            It "Should convert boolean false to string 'False'" {
                $obj = [PSCustomObject]@{ enabled = $false }
                $result = ConvertTo-QueryString -Params $obj
                $result | Should -Match 'enabled=False'
            }

            It "Should convert boolean true to string 'True'" {
                $obj = [PSCustomObject]@{ enabled = $true }
                $result = ConvertTo-QueryString -Params $obj
                $result | Should -Match 'enabled=True'
            }
        }
    }
}
