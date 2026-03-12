# Claude Code Prompt: Full Audit & Update of LogRhythm.Tools PowerShell Module
# Target: LogRhythm SIEM 7.23 GA API
# Repo: https://github.com/LogRhythm-Tools/LogRhythm.Tools

---

## YOUR MISSION

You are performing a comprehensive audit and update of the **LogRhythm.Tools** PowerShell module
to align with the **LogRhythm SIEM 7.23 GA API** documented at:
- https://developers.exabeam.com/logrhythm-siem/reference

The module is at **v1.4.0** (254 cmdlets across 57 directories). All work must conform
exactly to the project's CODESTYLE.md and use the established infrastructure patterns.

---

## PHASE 0 — READ THESE FILES BEFORE WRITING ANY CODE

Read every file listed below in full before writing a single line of code.
Understanding these is non-negotiable — they define every standard you must follow.

```
./CODESTYLE.md
./CONTRIBUTING.md
./docs/templates/1-Function.ps1
./docs/templates/2-RESTFunction.ps1
./docs/templates/2-AzRESTFunction.ps1
./docs/templates/3-Pester.Tests.ps1
./src/Private/Invoke-RestAPIMethod.ps1
./src/Private/Get-RestErrorMessage.ps1
./src/LogRhythm.Tools.psm1
```

Then read these representative existing cmdlets to internalize the real-world pattern
before writing anything new:

```
./src/Public/LogRhythm/Admin/LogSources/Add-LrLogSource.ps1
./src/Public/LogRhythm/Admin/Agents/Get-LrAgentsPending.ps1
./src/Public/LogRhythm/Admin/MPERules/Get-LrMpePolicies.ps1
./src/Public/LogRhythm/Case/General/Update-LrCaseStatus.ps1
./src/Public/LogRhythm/Alarms/Get-LrAlarms.ps1
```

---

## CRITICAL INFRASTRUCTURE RULES (apply to ALL new and modified cmdlets)

These are non-negotiable. Every violation will cause the PR to be rejected per CONTRIBUTING.md.

### 1. File Naming
One function per file. File name must EXACTLY match the function name (case-sensitive).
`Get-LrHostDetails.ps1` contains only `Function Get-LrHostDetails`.

### 2. Namespace Declarations
Every file must begin with:
```powershell
using namespace System
using namespace System.IO
using namespace System.Collections.Generic
```

### 3. Function Naming Pattern
`[Verb]-[Lr|Lrt|Exa][OptionalClassifier][Description]`
- `Lr` prefix = LogRhythm SIEM API cmdlets
- `Lrt` prefix = LogRhythm Tools utility/third-party cmdlets
- `Exa` prefix = Exabeam-specific cmdlets
- Only approved PowerShell verbs (Get, New, Add, Remove, Update, Set, Test, Format,
  Invoke, Copy, Import, Export, Enable, Disable, Find, Merge, Sync, Send, Start)
- NEVER use Write-Output. Use return for pipeline output.

### 4. Mandatory CmdletBinding and Parameters Block Structure
```powershell
[CmdletBinding()]
Param(
    # Pipeline-supporting parameters come first with positions
    [Parameter(Mandatory = $true, ValueFromPipeline = $true,
               ValueFromPipelineByPropertyName = $true, Position = 0)]
    [ValidateNotNull()]
    [int32] $Id,

    # Optional parameters
    [Parameter(Mandatory = $false, Position = N)]
    [switch] $PassThru,

    # Credential ALWAYS comes last
    [Parameter(Mandatory = $false, Position = N+1)]
    [ValidateNotNull()]
    [pscredential] $Credential = $LrtConfig.LogRhythm.ApiKey
)
```

### 5. Mandatory Begin/Process/End Structure
```powershell
Begin {
    $Me = $MyInvocation.MyCommand.Name

    $BaseUrl = $LrtConfig.LogRhythm.BaseUrl
    $Token = $Credential.GetNetworkCredential().Password

    $Headers = [Dictionary[string,string]]::new()
    $Headers.Add("Authorization", "Bearer $Token")

    $Method = $HttpMethod.Get   # or .Post / .Put / .Delete / .Patch

    Enable-TrustAllCertsPolicy
}

Process {
    $ErrorObject = [PSCustomObject]@{
        Code    = $null
        Error   = $false
        Type    = $null
        Note    = $null
        Value   = $Id        # The input value that failed
        Raw     = $null
    }

    # ... build $RequestUrl ...

    Write-Verbose "[$Me]: Request URL: $RequestUrl"

    # USE Invoke-RestAPIMethod — NOT Invoke-RestMethod directly
    $Response = Invoke-RestAPIMethod -Uri $RequestUrl -Headers $Headers `
        -Method $Method -Origin $Me
    if (($null -ne $Response.Error) -and ($Response.Error -eq $true)) {
        return $Response
    }

    if ($PassThru) { return $Response }
}

End { }
```

### 6. ALWAYS use `Invoke-RestAPIMethod` (not `Invoke-RestMethod`)
The private `Invoke-RestAPIMethod` wrapper in `./src/Private/Invoke-RestAPIMethod.ps1`
handles HTTP 429 retry (default 25 retries, 500ms delay), HTTP 500 retry for list operations,
and standardized error object construction. Every single LR API call must go through it.
Pass `-Origin $Me` always.

### 7. Version Gate Pattern
For any cmdlet requiring LR 7.5 or higher, include at the top of Process{}:
```powershell
if ($LrtConfig.LogRhythm.Version -match '7\.[0-4]\.\d+') {
    $ErrorObject.Error = $true
    $ErrorObject.Code = "404"
    $ErrorObject.Type = "Cmdlet not supported."
    $ErrorObject.Note = "This cmdlet is available in LogRhythm version 7.5.0 and greater."
    return $ErrorObject
}
```
Adjust the regex to match the actual minimum version for the endpoint.

### 8. Verbose Output Schema
```powershell
Write-Verbose "[$Me]: Request URL: $RequestUrl"
Write-Verbose "[$Me]: Request Method: $Method"
Write-Verbose "[$Me]: Request Body:`n$($Body | ConvertTo-Json -Depth 5)"
Write-Verbose "[$Me]: Results Count: $($Response.Count)"
```

### 9. Comment-Based Help (required sections, no exceptions)
```powershell
<#
.SYNOPSIS
    One sentence.
.DESCRIPTION
    Full description of behavior, including any automatic lookups performed.
.PARAMETER Credential
    PSCredential containing an API Token in the Password field.
    Note: You can bypass the need to provide a Credential by setting
    the preference variable $LrtConfig.LogRhythm.ApiKey with a valid Api Token.
.PARAMETER [EachParam]
    Type annotation + description + valid values if applicable.
.INPUTS
    List each parameter that accepts pipeline input.
.OUTPUTS
    PSCustomObject representing the LogRhythm [object type].
    On error: PSCustomObject with Error=true and diagnostic fields.
.EXAMPLE
    PS C:\> Get-LrFoo -Id 1234
    [show actual realistic output]
.NOTES
    LogRhythm-API
.LINK
    https://github.com/LogRhythm-Tools/LogRhythm.Tools
#>
```

### 10. Spacing & Braces (from CODESTYLE.md)
- 4 spaces, no tabs
- Single space after commas: `$Headers.Add("Authorization", "Bearer $Token")`
- No space inside parens: `$PSCmdlet.ThrowTerminatingError($PSItem)` not `...( $PSItem )`
- Space before/after assignment: `$x = 1` not `$x=1`
- Open brace at end of statement line
- PascalCase for ALL variable names (including loop vars): `$Item`, `$Response`, `$RetryCount`

### 11. No Write-Output
Never use `Write-Output`. Use `return` for pipeline output, `Write-Verbose` for diagnostic
messages, `Write-Host` for user-facing console messages.

### 12. PassThru Pattern
For any cmdlet that modifies/creates/deletes a resource, implement `-PassThru`:
```powershell
[Parameter(Mandatory = $false, Position = N)]
[switch] $PassThru
```
Without `-PassThru`, the cmdlet returns nothing on success. With it, returns the object.

---

## PHASE 1 — COMPLETE AUDIT OF ALL 254 EXISTING CMDLETS

For every `.ps1` file in `./src/Public/LogRhythm/` perform these checks:

### 1.1 API Endpoint Verification
Check each cmdlet's `$RequestUrl` against the 7.23 API reference at
https://developers.exabeam.com/logrhythm-siem/reference

Known base URL patterns in the module:
- Admin API: `$BaseUrl + "/lr-admin-api/[resource]/"`
- Case API: `$BaseUrl + "/lr-case-api/[resource]/"`
- Alarm API: `$BaseUrl + "/lr-alarm-api/[resource]/"`
- Search API: `$BaseUrl + "/lr-search-api/actions/search-[task|result]"`
- AIE Drilldown: `$LrtConfig.LogRhythm.AieBaseUrl + "/..."` — CHECK: may still use
  separate AieBaseUrl vs consolidated BaseUrl (see v1.2.0 changelog note about BaseUrl consolidation)

For each cmdlet, document:
- [ ] Endpoint path still matches 7.23 spec
- [ ] HTTP method still correct (note any POST to PUT or PUT to PATCH changes)
- [ ] Request body schema matches 7.23 (new required/optional fields)
- [ ] Response schema matches (renamed/added/removed fields in PSCustomObject)
- [ ] Query parameters complete (new filter options available)

### 1.2 Code Quality Checks (apply to every file)
- [ ] Uses `Invoke-RestAPIMethod` (not raw `Invoke-RestMethod`)
- [ ] Has `$Me = $MyInvocation.MyCommand.Name` in Begin{}
- [ ] Has proper `$ErrorObject` PSCustomObject in Process{}
- [ ] All `Write-Verbose` calls use `[$Me]:` prefix
- [ ] No `Write-Output` statements
- [ ] Comment-based help has all required sections
- [ ] Every parameter is documented in help
- [ ] At least one `.EXAMPLE` entry with realistic output
- [ ] `Enable-TrustAllCertsPolicy` called in Begin{}
- [ ] `$Credential` parameter present with `$LrtConfig.LogRhythm.ApiKey` default
- [ ] PascalCase for all variables
- [ ] 4-space indentation (no tabs)
- [ ] `-PassThru` on all mutating cmdlets

### 1.3 Specific Cmdlets Requiring Immediate Attention

#### `./src/Public/LogRhythm/Admin/LogSources/Add-LrLogSource.ps1`
- Uses `Invoke-RestAPIMethod` correctly
- 7.23 adds Log Source Virtualization fields that are currently commented out:
  `virtualSourceRegex`, `virtualSourceSortOrder`, `virtualSourceCatchAllID`,
  `virtualLogSourceParentID`, `virtualLogSourceName`
- Evaluate promoting commented-out UDLA fields to optional parameters
- `autoAcceptanceRuleId = "Manual"` is hardcoded — should this be a parameter?
- Missing `.EXAMPLE` with realistic output — add one

#### `./src/Public/LogRhythm/Admin/LogSources/Update-LrLogSource.ps1`
- Marked "early release" in v1.3.0
- 7.23 now has full PUT (complete update) AND PATCH (partial update) endpoints
- Expand parameter set to cover the full PUT schema
- Consider adding `Set-LrLogSource` as a PATCH variant, or add `-Partial` switch

#### `./src/Public/LogRhythm/Admin/Agents/Update-LrAgentPending.ps1`
- v1.3.0 description mixes associate/reject into one cmdlet
- 7.23 API has distinct endpoints: Accept, Reject, Associate
- Refactor or split into:
  - `Approve-LrAgentPending` for accept operation
  - `Deny-LrAgentPending` for reject operation
  - Keep or rename `Update-LrAgentPending` for associate only
- Update module exports and README table accordingly

#### `./src/Public/LogRhythm/Admin/MPERules/Get-LrMpePolicies.ps1`
- Added in v1.4.0 — verify endpoint path and response schema against 7.23 spec
- 7.23 adds summary variant: add `Get-LrMpePoliciesSummary`

#### `./src/Public/LogRhythm/Admin/MPERules/Get-LrMpeRules.ps1`
- Added in v1.4.0
- 7.23 has expanded query parameters (status filter, policy ID filter)
- Verify if this handles `GET /lr-admin-api/mpeRules/{id}` (single lookup) — if not, add it

#### `./src/Public/LogRhythm/Admin/Identities/Add-LrIdentity.ps1`
- README changelog misspells as `Add-LrIdentitiy` — confirm actual function name in file
  and ensure file name matches exactly (file is `Add-LrIdentity.ps1`)
- 7.23 adds bulk upsert endpoint — add `Add-LrIdentityBulk`

#### `./src/Public/LogRhythm/Admin/Identities/Run-LrTrueIdentityMerger.ps1`
- **BREAKING**: `Run-` is NOT an approved PowerShell verb
- MUST rename function to `Invoke-LrTrueIdentityMerger`
- MUST rename file to `Invoke-LrTrueIdentityMerger.ps1`
- MUST update `./src/LogRhythm.Tools.psm1` export list
- MUST update README cmdlet table

#### `./src/Public/LogRhythm/Admin/Identities/Get-LrIdentityById.ps1`
- README shows `Get-LrIDentityById` (capital D in Identity) — normalize casing in function
  name and file to `Get-LrIdentityById`. Verify the file name matches exactly.

#### `./src/Public/LogRhythm/Case/General/Get-LrCases.ps1`
- Known bug fix in v1.2.0: "Fix defect that would prevent return of exact case matches
  to not return if the submitted request did not include a metrics summary"
- Verify this fix is still correct against 7.23 response schema (metrics field names may differ)

#### `./src/Public/LogRhythm/Admin/NotificationGroups/`
- Only GET cmdlets currently exist
- 7.23 adds full CRUD — see Phase 2.11 for new cmdlets needed

---

## PHASE 2 — NEW CMDLETS TO CREATE

For each new cmdlet, follow the complete pattern from Phase 0. Place files in the
directory structure that mirrors existing conventions.

### 2.1 Admin API — MPE / Knowledgebase (add to `./src/Public/LogRhythm/Admin/MPERules/`)

| Cmdlet | HTTP | Endpoint | Min Version |
|--------|------|----------|-------------|
| `Get-LrMpePoliciesSummary` | GET | `/lr-admin-api/mpePolicies/summary` | 7.5.0 |
| `New-LrMpePolicy` | POST | `/lr-admin-api/mpePolicies` | 7.5.0 |
| `Update-LrMpePolicy` | PUT | `/lr-admin-api/mpePolicies/{id}` | 7.5.0 |
| `Remove-LrMpePolicy` | DEL | `/lr-admin-api/mpePolicies` | 7.5.0 |
| `Get-LrMpeRule` | GET | `/lr-admin-api/mpeRules/{id}` | 7.5.0 |
| `New-LrMpeRule` | POST | `/lr-admin-api/mpeRules` | 7.5.0 |
| `Update-LrMpeRule` | PUT | `/lr-admin-api/mpeRules/{id}` (custom rules only) | 7.5.0 |
| `Set-LrMpeRuleStatus` | PATCH | `/lr-admin-api/mpeRules/{id}` (retire or activate) | 7.5.0 |
| `Get-LrMpePolicyRules` | GET | `/lr-admin-api/mpePolicies/{policyId}/mpeRules` | 7.5.0 |
| `Update-LrMpePolicyRule` | PUT | `/lr-admin-api/mpePolicies/{policyId}/mpeRules/{ruleId}` | 7.5.0 |

### 2.2 Admin API — Log Source Virtualization (new directory: `./src/Public/LogRhythm/Admin/LogSources/LSV/`)

| Cmdlet | HTTP | Endpoint | Min Version |
|--------|------|----------|-------------|
| `Get-LrLsvTemplates` | GET | `/lr-admin-api/lsvTemplates` | 7.8.0 |
| `New-LrLsvTemplate` | POST | `/lr-admin-api/lsvTemplates` | 7.8.0 |
| `Update-LrLsvTemplate` | PUT | `/lr-admin-api/lsvTemplates/{id}` | 7.8.0 |
| `Get-LrLsvTemplate` | GET | `/lr-admin-api/lsvTemplates/{id}` | 7.8.0 |
| `Add-LrLsvTemplateItem` | POST | `/lr-admin-api/lsvTemplates/{id}/items` | 7.8.0 |
| `Get-LrLsvTemplateItems` | GET | `/lr-admin-api/lsvTemplates/{id}/items` | 7.8.0 |
| `Update-LrLsvTemplateItem` | PUT | `/lr-admin-api/lsvTemplates/{id}/items/{itemId}` | 7.8.0 |
| `Remove-LrLsvTemplateItems` | DEL | `/lr-admin-api/lsvTemplates/{id}/items` | 7.8.0 |
| `Set-LrLogSourceVirtualization` | PATCH | `/lr-admin-api/logsources/{id}/virtualization` | 7.8.0 |
| `Remove-LrLsvAssociations` | DEL | `/lr-admin-api/lsvTemplates/{id}/lsvItems` | 7.8.0 |

### 2.3 Admin API — Beats (new directory: `./src/Public/LogRhythm/Admin/Beats/`)

| Cmdlet | HTTP | Endpoint | Min Version |
|--------|------|----------|-------------|
| `Get-LrBeats` | GET | `/lr-admin-api/beats` | 7.8.0 |
| `Get-LrBeat` | GET | `/lr-admin-api/beats/{id}` | 7.8.0 |
| `New-LrBeat` | POST | `/lr-admin-api/beats` | 7.8.0 |
| `Update-LrBeat` | PUT | `/lr-admin-api/beats/{id}` | 7.8.0 |
| `Get-LrBeatTypes` | GET | `/lr-admin-api/beats/types` | 7.8.0 |
| `Get-LrBeatTemplate` | GET | `/lr-admin-api/beats/templates/{beatTypeId}` | 7.8.0 |
| `Set-LrBeatStatus` | PATCH | `/lr-admin-api/beats/status` | 7.8.0 |
| `Update-LrBeatHeartbeat` | PATCH | `/lr-admin-api/beats/heartbeat` | 7.8.0 |

### 2.4 Admin API — Open Collectors
Stub directory `./src/Public/LogRhythm/OC/` exists — evaluate if new cmdlets belong
there or in a new `./src/Public/LogRhythm/Admin/OpenCollectors/` directory.
Recommend the Admin/OpenCollectors/ path for consistency with Admin API grouping.

| Cmdlet | HTTP | Endpoint | Min Version |
|--------|------|----------|-------------|
| `Get-LrOpenCollectors` | GET | `/lr-admin-api/openCollectors` | 7.8.0 |
| `Get-LrOpenCollector` | GET | `/lr-admin-api/openCollectors/{id}` | 7.8.0 |
| `New-LrOpenCollector` | POST | `/lr-admin-api/openCollectors` | 7.8.0 |
| `Update-LrOpenCollector` | PUT | `/lr-admin-api/openCollectors/{id}` | 7.8.0 |
| `Set-LrOpenCollectorStatus` | PATCH | `/lr-admin-api/openCollectors/status` | 7.8.0 |
| `Update-LrOpenCollectorHeartbeat` | PATCH | `/lr-admin-api/openCollectors/{id}/heartbeat` | 7.8.0 |
| `Get-LrOpenCollectorBeats` | GET | `/lr-admin-api/openCollectors/{id}/beats` | 7.8.0 |

### 2.5 Admin API — Log Sources (add to `./src/Public/LogRhythm/Admin/LogSources/`)
NOTE: `Get-LrLogSourcesPending.ps1` already exists in the repo — audit it first
rather than creating a duplicate.

| Cmdlet | HTTP | Endpoint | Min Version |
|--------|------|----------|-------------|
| `New-LrLogSourcePending` | POST | `/lr-admin-api/logsources/pending` | 7.5.0 |
| `Remove-LrLogSourcePending` | DEL | `/lr-admin-api/logsources/pending/{id}` | 7.5.0 |
| `Approve-LrLogSourcePending` | PUT | `/lr-admin-api/logsources/pending/{id}/actions/accept` | 7.5.0 |
| `Deny-LrLogSourcePending` | PUT | `/lr-admin-api/logsources/pending/{id}/actions/reject` | 7.5.0 |
| `Join-LrLogSourcePending` | PUT | `/lr-admin-api/logsources/pending/{id}/actions/associate` | 7.5.0 |
| `Approve-LrLogSourcesPending` | PUT | `/lr-admin-api/logsources/pending/actions/accept` (batch) | 7.5.0 |
| `Deny-LrLogSourcesPending` | PUT | `/lr-admin-api/logsources/pending/actions/reject` (batch) | 7.5.0 |
| `Get-LrLogSourcePendingMatches` | GET | `/lr-admin-api/logsources/pending/{id}/matchingLogSources` | 7.5.0 |
| `Set-LrLogSourceStatus` | PUT | `/lr-admin-api/logsources/status` | 7.5.0 |

### 2.6 Admin API — Agents (add to `./src/Public/LogRhythm/Admin/Agents/`)

| Cmdlet | HTTP | Endpoint | Min Version |
|--------|------|----------|-------------|
| `New-LrAgent` | POST | `/lr-admin-api/agents` | 7.5.0 |
| `Update-LrAgent` | PUT | `/lr-admin-api/agents/{id}` | 7.5.0 |
| `Set-LrAgent` | PATCH | `/lr-admin-api/agents/{id}` | 7.5.0 |

### 2.7 Admin API — Hosts (add to `./src/Public/LogRhythm/Admin/Hosts/`)

| Cmdlet | HTTP | Endpoint | Min Version |
|--------|------|----------|-------------|
| `Update-LrHosts` | PUT | `/lr-admin-api/hosts` (batch update) | 7.5.0 |
| `Add-LrHostRole` | POST | `/lr-admin-api/hosts/{id}/roles` | 7.5.0 |
| `Remove-LrHostRole` | DEL | `/lr-admin-api/hosts/{id}/roles` | 7.5.0 |

### 2.8 Admin API — Entities (add to `./src/Public/LogRhythm/Admin/Entities/`)

| Cmdlet | HTTP | Endpoint | Min Version |
|--------|------|----------|-------------|
| `Import-LrEntities` | POST | `/lr-admin-api/entities/import` (file upload) | 7.5.0 |
| `Import-LrHosts` | POST | `/lr-admin-api/entities/{id}/hosts/import` | 7.5.0 |
| `Import-LrNetworks` | POST | `/lr-admin-api/entities/{id}/networks/import` | 7.5.0 |

### 2.9 Admin API — Networks (add to `./src/Public/LogRhythm/Admin/Networks/`)

| Cmdlet | HTTP | Endpoint | Min Version |
|--------|------|----------|-------------|
| `Update-LrNetworks` | PUT | `/lr-admin-api/networks` (batch update) | 7.5.0 |

### 2.10 Admin API — Users (new directory: `./src/Public/LogRhythm/Admin/Users/`)
NOTE: Existing `Get-LrUsers` in `./src/Public/LogRhythm/Case/Users/` targets the Case API
persons endpoint. These new cmdlets target the ADMIN API users — different service, different path.

| Cmdlet | HTTP | Endpoint | Min Version |
|--------|------|----------|-------------|
| `Get-LrAdminUsers` | GET | `/lr-admin-api/persons` | 7.5.0 |
| `New-LrAdminUser` | POST | `/lr-admin-api/persons` | 7.5.0 |
| `Get-LrAdminUser` | GET | `/lr-admin-api/persons/{id}` | 7.5.0 |
| `Get-LrUserLogins` | GET | `/lr-admin-api/userLogins` | 7.5.0 |
| `New-LrUserLogin` | POST | `/lr-admin-api/userLogins` | 7.5.0 |
| `Get-LrUserLoginsByPerson` | GET | `/lr-admin-api/persons/{id}/userLogins` | 7.5.0 |
| `Get-LrUserPrivileges` | GET | `/lr-admin-api/userLogins/privileges` | 7.5.0 |
| `Get-LrUserProfiles` | GET | `/lr-admin-api/userProfiles` | 7.5.0 |
| `Get-LrUserProfilesSummary` | GET | `/lr-admin-api/userProfiles/summary` | 7.5.0 |
| `New-LrUserProfile` | POST | `/lr-admin-api/userProfiles` | 7.5.0 |
| `Get-LrUserProfile` | GET | `/lr-admin-api/userProfiles/{id}` | 7.5.0 |
| `Copy-LrUserProfile` | POST | `/lr-admin-api/userProfiles/{id}/clone` | 7.5.0 |
| `Remove-LrUserProfile` | DEL | `/lr-admin-api/userProfiles/{id}` | 7.5.0 |
| `Get-LrUserProfilePrivileges` | GET | `/lr-admin-api/userProfiles/{id}/privileges` | 7.5.0 |
| `Get-LrUserProfileLogSources` | GET | `/lr-admin-api/userProfiles/{id}/effectiveLogSources` | 7.5.0 |
| `Get-LrUserPermissions` | GET | `/lr-admin-api/users` | 7.5.0 |

### 2.11 Admin API — Notification Groups (add to `./src/Public/LogRhythm/Admin/NotificationGroups/`)

| Cmdlet | HTTP | Endpoint | Min Version |
|--------|------|----------|-------------|
| `New-LrNotificationGroup` | POST | `/lr-admin-api/notificationGroups` | 7.5.0 |
| `Update-LrNotificationGroup` | PUT | `/lr-admin-api/notificationGroups/{id}` | 7.5.0 |
| `Remove-LrNotificationGroup` | DEL | `/lr-admin-api/notificationGroups/{id}` | 7.5.0 |
| `Add-LrNotificationGroupUsers` | POST | `/lr-admin-api/notificationGroups/{id}/persons` | 7.5.0 |
| `Remove-LrNotificationGroupUsers` | DEL | `/lr-admin-api/notificationGroups/{id}/persons` | 7.5.0 |

### 2.12 Admin API — Message Source Types (new directory: `./src/Public/LogRhythm/Admin/MsgSourceTypes/`)

| Cmdlet | HTTP | Endpoint | Min Version |
|--------|------|----------|-------------|
| `Get-LrMsgSourceTypes` | GET | `/lr-admin-api/msgSourceTypes` | 7.5.0 |
| `New-LrMsgSourceType` | POST | `/lr-admin-api/msgSourceTypes` | 7.5.0 |
| `Get-LrMsgSourceType` | GET | `/lr-admin-api/msgSourceTypes/{id}` | 7.5.0 |
| `Update-LrMsgSourceType` | PUT | `/lr-admin-api/msgSourceTypes/{id}` | 7.5.0 |
| `Remove-LrMsgSourceType` | DEL | `/lr-admin-api/msgSourceTypes/{id}` | 7.5.0 |

### 2.13 Admin API — Licenses (new directory: `./src/Public/LogRhythm/Admin/Licenses/`)

| Cmdlet | HTTP | Endpoint | Min Version |
|--------|------|----------|-------------|
| `Get-LrLicenses` | GET | `/lr-admin-api/licenses` | 7.5.0 |
| `Get-LrLicenseEntitlements` | GET | `/lr-admin-api/licenses/entitlements` | 7.5.0 |

### 2.14 Admin API — Identities (add to `./src/Public/LogRhythm/Admin/Identities/`)

| Cmdlet | HTTP | Endpoint | Min Version |
|--------|------|----------|-------------|
| `Add-LrIdentityBulk` | POST | `/lr-admin-api/identities/bulk` | 7.5.0 |
| `Get-LrIdentityPhoto` | GET | `/lr-admin-api/identities/{id}/photo` | 7.5.0 |
| `Get-LrIdentityMerged` | GET | `/lr-admin-api/identities/{id}/mergedIdentities` | 7.5.0 |
| `Get-LrIdentityFromList` | GET | `/lr-admin-api/identityLists/{listId}/identities/{identityId}` | 7.5.0 |

### 2.15 Admin API — Location (add to `./src/Public/LogRhythm/Admin/Location/`)

| Cmdlet | HTTP | Endpoint | Min Version |
|--------|------|----------|-------------|
| `Get-LrLocationDetails` | GET | `/lr-admin-api/locations/{id}` | 7.5.0 |

### 2.16 Alarm API (add to `./src/Public/LogRhythm/Alarms/`)

| Cmdlet | HTTP | Endpoint | Min Version |
|--------|------|----------|-------------|
| `Get-LrAlarmUrl` | GET | `/lr-alarm-api/alarms/url` | 7.7.0 |

### 2.17 Case API — Evidence (add to `./src/Public/LogRhythm/Case/Evidence/`)

| Cmdlet | HTTP | Endpoint | Min Version |
|--------|------|----------|-------------|
| `Add-LrFileToCase` | POST | `/lr-case-api/cases/{id}/evidence/file` | 7.5.0 |
| `Add-LrUserEventToCase` | POST | `/lr-case-api/cases/{id}/evidence/userEvents` | 7.5.0 |
| `Update-LrCaseEvidence` | PUT | `/lr-case-api/cases/{id}/evidence/{evidenceId}` | 7.5.0 |
| `Remove-LrCaseEvidence` | DEL | `/lr-case-api/cases/{id}/evidence/{evidenceId}` | 7.5.0 |
| `Get-LrCaseEvidenceProgress` | GET | `/lr-case-api/cases/{id}/evidence/{evidenceId}/progress` | 7.5.0 |
| `Get-LrCaseEvidenceFile` | GET | `/lr-case-api/cases/{id}/evidence/{evidenceId}/download` | 7.5.0 |
| `Get-LrCaseEvidenceLogBytes` | GET | `/lr-case-api/cases/{id}/evidence/{evidenceId}/logs` | 7.5.0 |
| `Get-LrCaseUserEvents` | GET | `/lr-case-api/cases/{id}/evidence/userEvents` | 7.5.0 |
| `Update-LrCaseLogsIndex` | PUT | `/lr-case-api/cases/{id}/evidence/logsIndex` | 7.5.0 |
| `Send-LrCaseFile` | POST | `/lr-case-api/files` (upload) | 7.5.0 |
| `Get-LrCaseFileWhitelist` | GET | `/lr-case-api/files/whitelist` | 7.5.0 |
| `Get-LrCaseFileProgress` | GET | `/lr-case-api/files/{id}/progress` | 7.5.0 |

### 2.18 Case API — Playbooks (add to `./src/Public/LogRhythm/Case/Playbooks/`)
NOTE: `Import-LrPlaybook.ps1` already exists — audit it first.

| Cmdlet | HTTP | Endpoint | Min Version |
|--------|------|----------|-------------|
| `Export-LrPlaybook` | GET | `/lr-case-api/playbooks/{id}/export` | 7.5.0 |
| `Update-LrPlaybookPartial` | PATCH | `/lr-case-api/playbooks/{id}` | 7.5.0 |

### 2.19 Case API — Playbook Attachments (new directory: `./src/Public/LogRhythm/Case/Attachments/`)

| Cmdlet | HTTP | Endpoint | Min Version |
|--------|------|----------|-------------|
| `Get-LrPlaybookAttachments` | GET | `/lr-case-api/playbooks/{id}/attachments` | 7.5.0 |
| `Get-LrPlaybookAttachment` | GET | `/lr-case-api/playbooks/{id}/attachments/{attId}` | 7.5.0 |
| `Add-LrPlaybookAttachment` | PUT | `/lr-case-api/playbooks/{id}/attachments/{attId}` | 7.5.0 |
| `Remove-LrPlaybookAttachment` | DEL | `/lr-case-api/playbooks/{id}/attachments/{attId}` | 7.5.0 |
| `Get-LrPlaybookAttachmentFile` | GET | `/lr-case-api/playbooks/{id}/attachments/{attId}/download` | 7.5.0 |
| `Get-LrCasePlaybookAttachments` | GET | `/lr-case-api/cases/{caseId}/playbooks/{pbId}/attachments` | 7.5.0 |
| `Get-LrCasePlaybookAttachment` | GET | `/lr-case-api/cases/{caseId}/playbooks/{pbId}/attachments/{attId}` | 7.5.0 |
| `Get-LrCasePlaybookAttachmentFile` | GET | `/lr-case-api/cases/{caseId}/playbooks/{pbId}/attachments/{attId}/download` | 7.5.0 |

### 2.20 Case API — History & Maintenance
NOTE: `Get-LrCaseHistory.ps1` already exists — audit it first.

| Cmdlet | HTTP | Endpoint | Min Version |
|--------|------|----------|-------------|
| `Get-LrCaseGlobalHistory` | GET | `/lr-case-api/history` | 7.5.0 |
| `Get-LrCaseLogsIndexes` | GET | `/lr-case-api/cases/logsIndexes` (all cases) | 7.5.0 |
| `Get-LrCaseCapabilities` | GET | `/lr-case-api/capabilities` | 7.5.0 |
| `Get-LrCaseFeatureFlags` | GET | `/lr-case-api/featureFlags` | 7.5.0 |
| `Invoke-LrCaseLogMaintenance` | POST | `/lr-case-api/cases/evidence/logs/maintenance` | 7.5.0 |

### 2.21 Case API — Metrics (add to `./src/Public/LogRhythm/Case/Metrics/`)

| Cmdlet | HTTP | Endpoint | Min Version |
|--------|------|----------|-------------|
| `Update-LrCaseMetrics` | PUT | `/lr-case-api/cases/{id}/metrics` | 7.5.0 |

### 2.22 AIE Engine API (new directory: `./src/Public/LogRhythm/AIE/Engine/`)
These are separate from the existing AIE Drilldown cmdlets.

| Cmdlet | HTTP | Endpoint | Min Version |
|--------|------|----------|-------------|
| `Import-LrAieRule` | POST | `/lr-aie-api/aie/rules/import` | 7.5.0 |
| `Set-LrAieRuleStatuses` | PATCH | `/lr-aie-api/aie/rules/status` | 7.5.0 |
| `Restart-LrAieService` | POST | `/lr-aie-api/aie/rules/restartService` | 7.5.0 |

### 2.23 Metrics API (new directory: `./src/Public/LogRhythm/Metrics/`)

| Cmdlet | HTTP | Endpoint | Min Version |
|--------|------|----------|-------------|
| `Get-LrLogVolume` | POST | `/lr-metrics-api/logVolume` | 7.5.0 |
| `Get-LrTtlDetails` | GET | `/lr-metrics-api/ttl` | 7.5.0 |

---

## PHASE 3 — MODULE MANIFEST UPDATE

After all cmdlet work is complete:

### 3.1 Update `./src/LogRhythm.Tools.psm1`
- Add all new cmdlet function names to the FunctionsToExport list (or equivalent)
- Verify file discovery / dot-sourcing will pick up all new subdirectories
- If new directories were added (Beats, OpenCollectors, Metrics, etc.), confirm they
  are included in the module's discovery glob pattern

### 3.2 Update `./dist/ModuleInfo.json`
- Bump version to `1.5.0`
- Update ReleaseNotes with a summary of all changes organized by API area

### 3.3 Update `./README.md`
- Add all new cmdlets to the "Cmdlet Version Requirements" table with correct Min Version
- Add 1.5.0 section to the Change Log organized by category
- Update the renamed cmdlet entry (`Run-LrTrueIdentityMerger` to `Invoke-LrTrueIdentityMerger`)

---

## PHASE 4 — PESTER TEST STUBS

For every new cmdlet, create a Pester test stub in `./tests/` following
`./docs/templates/3-Pester.Tests.ps1`. Each stub must include:

1. `Describe` block named after the cmdlet
2. `Context "Input validation"` with `It` tests for each mandatory parameter
3. `Context "API response handling"` with mocked `Invoke-RestAPIMethod` responses
4. `Context "Error handling"` testing the $ErrorObject return path

---

## PHASE 5 — FINAL CHECKLIST

Before considering work complete, verify every item below:

- [ ] Every new `.ps1` filename exactly matches its function name (case-sensitive)
- [ ] No `Write-Output` anywhere in new or modified files
- [ ] Every LR API cmdlet uses `Invoke-RestAPIMethod` with `-Origin $Me`
- [ ] Every mutating cmdlet (New/Add/Update/Remove/Set) has `-PassThru` switch
- [ ] `$Me = $MyInvocation.MyCommand.Name` in every Begin{} block
- [ ] All new cmdlets have complete comment-based help with all required sections
- [ ] `Run-LrTrueIdentityMerger` renamed to `Invoke-LrTrueIdentityMerger`,
      file renamed, module export updated, README updated
- [ ] `./src/LogRhythm.Tools.psm1` exports all new cmdlets
- [ ] `./README.md` Cmdlet Version Requirements table is complete and accurate
- [ ] Version bumped to 1.5.0 in ModuleInfo.json
- [ ] Pester test stubs exist for all new cmdlets
- [ ] All existing cmdlets still pass their Pester tests

---

## API REFERENCE QUICK GUIDE

All endpoints use the base URL configured in `$LrtConfig.LogRhythm.BaseUrl`.

| API Service       | URL Path Prefix        | Notes |
|-------------------|------------------------|-------|
| Admin API         | `/lr-admin-api/`       | Main config, entities, users, log sources |
| Case API          | `/lr-case-api/`        | Cases, evidence, playbooks, tags |
| Alarm API         | `/lr-alarm-api/`       | Alarm management |
| Search API        | `/lr-search-api/`      | Log search |
| AIE Drilldown     | `/lr-drilldown-api/`   | Check if still using separate AieBaseUrl |
| AIE Engine        | `/lr-aie-api/`         | Rule import, status, service restart |
| Metrics API       | `/lr-metrics-api/`     | Log volume, TTL |

Full API reference: https://developers.exabeam.com/logrhythm-siem/reference
