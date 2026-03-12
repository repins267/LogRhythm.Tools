using namespace System
using namespace System.Collections.Generic

Function Get-LrtExaToken {
    <#
    .SYNOPSIS
        Get an access token to access Exabeam API resources.
        
    .DESCRIPTION
        Retrieves an access token from Exabeam by authenticating with provided client ID and secret. 
        The token is essential for making authenticated requests to Exabeam's APIs. This function uses the OAuth 2.0
        client credentials grant type to authenticate and fetch the token. The function constructs the request URI
        using configuration settings from $LrtConfig.
    .PARAMETER Credential
        PSCredential containing an API Token in the Password field.
    .OUTPUTS
        [System.Object] representing an Exabeam resource access token.
    .NOTES
        Exabeam-API   
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false, Position = 1)]
        [ValidateNotNull()]
        [pscredential] $Credential
    )

    Begin { 
        $Me = $MyInvocation.MyCommand.Name
        Enable-TrustAllCertsPolicy

        # Use passed credential or fallback to config
        $ExaCred = if ($PSBoundParameters.ContainsKey('Credential')) { $Credential } else { $LrtConfig.Exabeam.ApiKey }

        $ClientId = $ExaCred.Username
        $ClientSecret = $ExaCred.GetNetworkCredential().Password

        # Ensure BaseUrl ends with a slash before appending
        $BaseUrl = $LrtConfig.Exabeam.BaseUrl.TrimEnd('/')
        $ResourceUri = "$BaseUrl/auth/v1/token"
    }

    Process {
        $BodyContents = [PSCustomObject]@{
            "grant_type" = 'client_credentials'
            client_id = $ClientId 
            client_secret = $ClientSecret
        }

        $Body = $BodyContents | ConvertTo-Json 
        Write-Verbose "[$Me]: Exabeam Auth Request Body Built"

        $Headers = [Dictionary[string,string]]::new()
        $Headers.Add("accept",'application/json')
        $Headers.Add("content-type",'application/json')

        # Use the compliant v1.5.0 wrapper
        $TokenResponse = Invoke-RestAPIMethod -Uri $ResourceUri -Headers $Headers -Method $HttpMethod.Post -Body $Body -Origin $Me

        # If the wrapper returns our standard ErrorObject, throw it so the caller knows it failed
        if ($null -ne $TokenResponse.Error) {
            $PSCmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new(
                [Exception]::new("[$Me] Exabeam Auth Failed: $($TokenResponse.Error)"),
                "ExabeamAuthFailure",
                [System.Management.Automation.ErrorCategory]::AuthenticationError,
                $ResourceUri
            ))
        }

        # Add expiration calculation
        $TokenResponse | Add-Member -MemberType NoteProperty -Name expires_on -Value $((Get-Date).AddSeconds($TokenResponse.expires_in)) -Force

        return $TokenResponse
    }

    End { }
}