using namespace System
using namespace System.Collections.Generic

Function Initialize-ExaApiRequest {
    <#
    .SYNOPSIS
        Initialize Exabeam API request components including token, headers, and TLS policy.
    .DESCRIPTION
        Consolidates the common Exabeam API setup steps: token refresh, base URL retrieval,
        header construction, and TLS policy enforcement. Returns an object with BaseUrl and
        Headers properties ready for use with Invoke-RestAPIMethod.
    .OUTPUTS
        PSCustomObject with BaseUrl [string] and Headers [Dictionary[string,string]] properties.
    .NOTES
        Exabeam-API
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding()]
    Param()

    # Refresh token
    Set-LrtExaToken

    # Request Setup
    $BaseUrl = $LrtConfig.Exabeam.BaseUrl
    $Token = $LrtConfig.Exabeam.Token.access_token

    # Define HTTP Headers
    $Headers = [Dictionary[string,string]]::new()
    $Headers.Add("Authorization", "Bearer $Token")

    # Check preference requirements for self-signed certificates and set enforcement for Tls1.2
    Enable-TrustAllCertsPolicy

    return [PSCustomObject]@{
        BaseUrl = $BaseUrl
        Headers = $Headers
    }
}
