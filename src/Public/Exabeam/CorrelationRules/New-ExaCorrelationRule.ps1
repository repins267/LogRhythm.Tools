using namespace System
using namespace System.Collections.Generic

Function New-ExaCorrelationRule {
    <#
    .SYNOPSIS
        Create a new Exabeam correlation rule.
    .DESCRIPTION
        Creates a new correlation rule in the Exabeam environment. Requires
        a rule name, severity, and at least one sequence with a query and condition.
    .PARAMETER Name
        The correlation rule name.
    .PARAMETER Description
        Optional description for the rule.
    .PARAMETER Severity
        Rule severity level: none, low, medium, high, or critical.
    .PARAMETER Enabled
        Whether the rule is enabled. Default: false.
    .PARAMETER TestMode
        Enable rule test mode. Default: false.
    .PARAMETER SequencesConfig
        Hashtable or PSCustomObject containing the sequences configuration.
        Must include a 'sequences' array with at least one sequence containing
        a 'query' and 'condition'.
    .PARAMETER SuppressConfig
        Optional suppression configuration hashtable.
    .PARAMETER DelayConfig
        Optional delay configuration hashtable.
    .PARAMETER ScheduleConfig
        Optional schedule configuration hashtable.
    .PARAMETER PassThru
        Return the API response object.
    .OUTPUTS
        PSCustomObject representing the created correlation rule when PassThru is specified.
    .EXAMPLE
        PS C:\> $seq = @{
            sequences = @(@{
                name = "Failed Logins"
                query = 'activity_type:"authentication" AND outcome:"failure"'
                condition = @{ triggerOnAnyMatch = $true }
            })
        }
        PS C:\> New-ExaCorrelationRule -Name "Brute Force Detection" -Severity high -SequencesConfig $seq -PassThru
        ---
        Creates a new high-severity correlation rule.
    .NOTES
        Exabeam-API
    .LINK
        https://github.com/LogRhythm-Tools/LogRhythm.Tools
    #>

    [CmdletBinding(SupportsShouldProcess = $true)]
    Param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory = $false)]
        [string] $Description,

        [Parameter(Mandatory = $true)]
        [ValidateSet("none", "low", "medium", "high", "critical")]
        [string] $Severity,

        [Parameter(Mandatory = $false)]
        [bool] $Enabled = $false,

        [Parameter(Mandatory = $false)]
        [bool] $TestMode = $false,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [object] $SequencesConfig,

        [Parameter(Mandatory = $false)]
        [object] $SuppressConfig,

        [Parameter(Mandatory = $false)]
        [object] $DelayConfig,

        [Parameter(Mandatory = $false)]
        [object] $ScheduleConfig,

        [Parameter(Mandatory = $false)]
        [switch] $PassThru
    )

    Begin {
        $Me = $MyInvocation.MyCommand.Name
        $Api = Initialize-ExaApiRequest

        # Define HTTP Method
        $Method = $HttpMethod.Post

        # Define HTTP URI
        $RequestUrl = $Api.BaseUrl + "correlation-rules/v2/rules"
    }

    Process {
        Write-Verbose "[$Me]: Request URL: $RequestUrl"

        # Build request body
        $BodyObj = @{
            name            = $Name
            severity        = $Severity
            enabled         = $Enabled
            testMode        = $TestMode
            sequencesConfig = $SequencesConfig
        }
        if ($Description) { $BodyObj.description = $Description }
        if ($SuppressConfig) { $BodyObj.suppressConfig = $SuppressConfig }
        if ($DelayConfig) { $BodyObj.delayConfig = $DelayConfig }
        if ($ScheduleConfig) { $BodyObj.scheduleConfig = $ScheduleConfig }

        $Body = $BodyObj | ConvertTo-Json -Depth 10 -Compress

        if ($PSCmdlet.ShouldProcess($Name, "Create Exabeam correlation rule")) {
            # Send Request
            $Response = Invoke-RestAPIMethod -Uri $RequestUrl -Headers $Api.Headers -Method $Method -Body $Body -Origin $Me
            if (($null -ne $Response.Error) -and ($Response.Error -eq $true)) {
                return $Response
            }

            if ($PassThru) { return $Response }
        }
    }

    End { }
}
