[![Last Release](https://badgen.net/badge/release/v1.5.0/green)](https://github.com/LogRhythm-Tools/LogRhythm.Tools/releases)
[![Dev Version](https://badgen.net/badge/dev/v1.5.0/green)](https://github.com/LogRhythm-Tools/LogRhythm.Tools/tree/development/)

LogRhythm.Tools is a PowerShell module that provides a complete abstraction layer over the LogRhythm SIEM API surface. Instead of hand-crafting REST calls, managing authentication headers, handling pagination, or parsing error responses, analysts and developers work with native PowerShell cmdlets that return structured objects ready for the pipeline.

### Why not just call the API directly?

Every cmdlet in the module routes through `Invoke-RestAPIMethod`, a centralized API execution engine that handles the problems you'd otherwise solve yourself on every call:

- **Automatic retry with backoff** — HTTP 429 (rate-limit) and transient 500 errors are retried up to 25 times with configurable delay, so bulk operations and SmartResponse plugins don't fail on momentary throttling.
- **Structured error objects** — Failures return a consistent `[PSCustomObject]` with `.Error`, `.Code`, `.Note`, `.Origin`, `.Uri`, and `.Raw` properties. No unhandled exceptions, no guessing what went wrong — just inspect the object.
- **Origin tracking** — Every request is tagged with the calling cmdlet name (e.g., `[Get-LrHosts]`), so when something fails in a complex pipeline or SmartResponse, the log tells you exactly which cmdlet made the call.
- **TLS & certificate handling** — Self-signed certificates common in on-prem LogRhythm deployments are handled transparently via `Enable-TrustAllCertsPolicy`.
- **Pagination** — List cmdlets automatically aggregate paginated results so you get the full dataset without writing loop logic.

The result: you write `Get-LrHosts | Where-Object { $_.hostStatus -eq 'Active' } | Get-LrHostIdentifiers` and the module handles auth, pagination, retries, TLS, and error normalization behind the scenes. This makes LogRhythm.Tools equally useful for interactive analysis, scripting, and as the foundation for SmartResponse plugin development.

## Testing

LogRhythm.Tools includes two complementary testing approaches:

### Offline Validation
`Test-ModuleValidation.ps1` verifies module structure, parameter compliance, and code standards without requiring API keys or a SIEM connection. Run this first to catch structural issues before going live.

```powershell
.\tests\Test-ModuleValidation.ps1
```

### Live API Test Harness
`Test-LiveApiEndpoints.ps1` runs every GET cmdlet against a live LogRhythm deployment and produces structured JSON results. It exercises `Invoke-RestAPIMethod` end-to-end — proving that authentication, endpoint paths, pagination, retry logic, and error handling all work against your specific SIEM version.

The harness executes in three phases:
1. **Discovery** — Runs ~40 parameterless GET cmdlets (list endpoints) and caches the first result from each.
2. **Id-Dependent** — Runs ~44 cmdlets that require an Id parameter, resolved automatically from the discovery cache.
3. **Complex** — Runs cmdlets needing constructed parameters (date ranges, filters, etc.).

Each call is timed, checked for errors, and recorded with status (`PASS`/`WARN`/`SKIP`/`FAIL`), HTTP code, response time, and result count.

```powershell
# Run all tests (skip known slow endpoints)
.\tests\Test-LiveApiEndpoints.ps1 -SkipSlow

# Run only Admin API tests with verbose output
.\tests\Test-LiveApiEndpoints.ps1 -Category Admin -Detailed

# Results saved automatically to tests/results/ as timestamped JSON
Get-Content tests\results\*.json | ConvertFrom-Json | Select-Object -ExpandProperty metadata
```

For additional testing tiers (write/mutate, third-party integrations) and Postman validation tips, see the [Detailed Testing Guide](tests/README.md).

**LogRhythm Components:**

- Admin (Agents, Beats, Entities, Hosts, Identities, Licenses, Lists, Locations, LogSources, MPE Rules, Message Source Types, Networks, Notification Groups, Open Collectors, Users)
- AI Engine Drilldown for Alarms
- AI Engine Management (Rule Import, Status, Service Restart)
- Cases (Attachments, Evidence, History, Metrics, Playbooks, Tags)
- Search (LR version 7.5 required)
- Alarms (LR version 7.7 required)
- Metrics (Log Volume, TTL)
- Module Configuration (Initialize, Get, Set, Test)
- LogRhythm Echo

**Third Party Integrations:**

LogRhythm.Tools supports API access to various third party vendors.  Access to these services requires authorization keys provided by the third party and is not granted as a part of the LogRhythm.Tools module.  

- Microsoft Active Directory
- Microsoft Graph API
- Microsoft Defender API
- Mimecast
- MACVendors
- Proofpoint
- Recorded Future
- Shodan
- Urlscan
- Virus Total

---------

Each command included in the LogRhythm.Tools module is designed to be modular and built to leverage the power of the PowerShell pipeline.  The output of one LRT command can be sent for processing as input to the another command. And that output can be sent to yet another command. The result is a complex command chain or pipeline that is composed of a series of simple commands.


# Getting Started

## [Requirements](#Requirements)

**Software**

Windows PowerShell
- Windows Management Framework 5.1
- Windows .Net Framework 4.5.2

PowerShell Core
- Windows .Net Framework 6.0 LTS or newer

**Permissions**

- Ability to download resources from Github.com
- Ability to extract archive files from zip
- User level privileges to run PowerShell
- User level privileges to install PowerShell modules

**Credentials**

***Required (Have these ready for Initial Setup)***
- LogRhythm Platform Manager URL (e.g., `https://pm-server:8501`)
- LogRhythm SIEM Version (e.g., `7.11.0`)
- LogRhythm API Key (Third-Party Token)

***Optional (Configured separately for Third-Party Integrations)***
- Exabeam API Key
- Mimecast API Key
- Microsoft Azure App Registration
- Recorded Future API Key
- Proofpoint API Key
- Shodan API Key
- Urlscan API Key
- VirusTotal API Key

> NOTE: For specific Cmdlet requirements reference the section [Cmdlet Version Requirements](#Cmdlet-Version-Requirements)

## Installation & Configuration

> **Note:** As of v1.5.0, the installation and setup process has been modernized natively within the module.

### 1. First-Time Setup (v1.5.0+)
1. Download and extract the LogRhythm.Tools release package, or clone the repository.
2. Open PowerShell and import the module:
   ```powershell
   Import-Module .\src\LogRhythm.Tools.psm1
   ```
3. Run the interactive initialization wizard to set up your primary SIEM connection:
   ```powershell
   Initialize-LrtConfiguration
   ```
   *(This wizard will prompt you for your Platform Manager URL, SIEM version, and API key. It safely encrypts and stores your configuration locally).*

4. Verify your LogRhythm connection:
   ```powershell
   Test-LrtConfiguration -Service LogRhythm -TestConnectivity
   ```

### 2. Configuring Third-Party Integrations
The interactive wizard configures your core SIEM connection. To configure optional third-party integrations (like Exabeam or VirusTotal), use `Set-LrtConfiguration` to target the specific service.

```powershell
# Example: Configuring Exabeam
Set-LrtConfiguration -Service Exabeam -ApiKey (Get-Credential) -BaseUrl "[https://api.us-east.exabeam.cloud/](https://api.us-east.exabeam.cloud/)"

# Example: Configuring VirusTotal
Set-LrtConfiguration -Service VirusTotal -ApiKey (Get-Credential)
```

### 3. Managing Configuration
You can view or update your configuration at any time without leaving your session:

```powershell
# View your current configuration (API keys and secrets are masked by default)
Get-LrtConfiguration

# Update a specific value silently
Set-LrtConfiguration -Service LogRhythm -BaseUrl "https://new-pm-server:8501"
```

For additional examples on how to leverage LogRhythm.Tools check out the [Examples](#examples) section.

---------

## Contributing

Contributions are welcome. Please review the [Contributing](CONTRIBUTING.md) guide and the [Code Style](CODESTYLE.md) guide.

---------

# Additional Details
## Change Log
### 1.5.0
LogRhythm 7.23 GA API Coverage

#### Phase 1 — Compliance Audit
* Fixed 8 logic bugs, 3 critical violations, 27 high priority, and 18 medium/low issues across 50+ existing cmdlets
* Renamed `Run-LrTrueIdentityMerger` to `Invoke-LrTrueIdentityConflictMerger` (approved verb, clearer name)
* Standardized `Invoke-RestAPIMethod -Origin $Me` across all cmdlets
* Added `Enable-TrustAllCertsPolicy` to all Begin blocks
* Added `-PassThru` to all mutating cmdlets

#### Phase 2 — New Cmdlets (~120 new)
##### Admin API — MPE/Knowledgebase
* Get-LrMpePoliciesSummary, New-LrMpePolicy, Update-LrMpePolicy, Remove-LrMpePolicy
* Get-LrMpeRule, New-LrMpeRule, Update-LrMpeRule, Set-LrMpeRuleStatus
* Get-LrMpePolicyRules, Update-LrMpePolicyRule

##### Admin API — Log Source Virtualization
* Get-LrLsvTemplates, Get-LrLsvTemplate, New-LrLsvTemplate, Update-LrLsvTemplate
* Get-LrLsvTemplateItems, Add-LrLsvTemplateItem, Update-LrLsvTemplateItem, Remove-LrLsvTemplateItems
* Set-LrLogSourceVirtualization, Remove-LrLsvAssociations

##### Admin API — Beats
* Get-LrBeats, Get-LrBeat, New-LrBeat, Update-LrBeat
* Get-LrBeatTypes, Get-LrBeatTemplate, Set-LrBeatStatus, Update-LrBeatHeartbeat

##### Admin API — Open Collectors
* Get-LrOpenCollectors, Get-LrOpenCollector, New-LrOpenCollector, Update-LrOpenCollector
* Set-LrOpenCollectorStatus, Update-LrOpenCollectorHeartbeat, Get-LrOpenCollectorBeats

##### Admin API — Pending Log Sources
* New-LrLogSourcePending, Remove-LrLogSourcePending
* Approve-LrLogSourcePending, Deny-LrLogSourcePending, Join-LrLogSourcePending
* Approve-LrLogSourcesPending, Deny-LrLogSourcesPending
* Get-LrLogSourcePendingMatches, Set-LrLogSourceStatus

##### Admin API — Users/Profiles
* Get-LrAdminUsers, Get-LrAdminUser, New-LrAdminUser
* Get-LrUserLogins, New-LrUserLogin, Get-LrUserLoginsByPerson, Get-LrUserPrivileges
* Get-LrUserProfiles, Get-LrUserProfilesSummary, Get-LrUserProfile, New-LrUserProfile
* Copy-LrUserProfile, Remove-LrUserProfile, Get-LrUserProfilePrivileges, Get-LrUserProfileLogSources
* Get-LrUserPermissions

##### Admin API — Agents, Hosts, Entities, Networks
* New-LrAgent, Update-LrAgent, Set-LrAgent
* Update-LrHosts, Add-LrHostRole, Remove-LrHostRole
* Import-LrEntities, Import-LrHosts, Import-LrNetworks
* Update-LrNetworks

##### Admin API — Notification Groups
* New-LrNotificationGroup, Update-LrNotificationGroup, Remove-LrNotificationGroup
* Add-LrNotificationGroupUsers, Remove-LrNotificationGroupUsers

##### Admin API — Message Source Types
* Get-LrMsgSourceTypes, Get-LrMsgSourceType, New-LrMsgSourceType, Update-LrMsgSourceType, Remove-LrMsgSourceType

##### Admin API — Licenses
* Get-LrLicenses, Get-LrLicenseEntitlements

##### Admin API — Identities
* Add-LrIdentityBulk, Get-LrIdentityPhoto, Get-LrIdentityMerged, Get-LrIdentityFromList

##### Admin API — Location
* Get-LrLocationDetails

##### Alarm API
* Get-LrAlarmUrl (7.7.0+)

##### Case API — Evidence
* Add-LrFileToCase, Add-LrUserEventToCase, Update-LrCaseEvidence, Remove-LrCaseEvidence
* Get-LrCaseEvidenceProgress, Get-LrCaseEvidenceFile, Get-LrCaseEvidenceLogBytes, Get-LrCaseUserEvents
* Update-LrCaseLogsIndex, Send-LrCaseFile, Get-LrCaseFileWhitelist, Get-LrCaseFileProgress

##### Case API — Playbooks
* Export-LrPlaybook, Update-LrPlaybookPartial

##### Case API — Playbook Attachments
* Get-LrPlaybookAttachments, Get-LrPlaybookAttachment, Add-LrPlaybookAttachment, Remove-LrPlaybookAttachment
* Get-LrPlaybookAttachmentFile, Get-LrCasePlaybookAttachments, Get-LrCasePlaybookAttachment, Get-LrCasePlaybookAttachmentFile

##### Case API — History & Maintenance
* Get-LrCaseGlobalHistory, Get-LrCaseLogsIndexes, Get-LrCaseCapabilities, Get-LrCaseFeatureFlags
* Invoke-LrCaseLogMaintenance

##### Case API — Metrics
* Update-LrCaseMetrics

##### AIE Engine API
* Import-LrAieRule, Set-LrAieRuleStatuses, Restart-LrAieService

##### Metrics API
* Get-LrLogVolume, Get-LrTtlDetails

#### Phase 6 — Module Configuration Cmdlets
* Initialize-LrtConfiguration — guided first-time setup (replaces separate Setup.ps1 workflow)
* Get-LrtConfiguration — display current config with secrets masked by default
* Set-LrtConfiguration — modify and persist config values per service section
* Test-LrtConfiguration — validate config and optionally test API connectivity
* Module now loads gracefully without pre-existing config (creates defaults automatically)

### 1.4.0
LogRhythm additions:
* Add-LrLogSource
* Get-LrLogSourceTypeDetails
* Get-LrMpePolicies
* Get-LrMpePolicy
* Get-LrMpeRules

Recorded Future additions:
* Get-RfAlerts
* Update-RfAlert

Exabeam additions:
* Add context tables
* Retrieve context tables
* Retrieve context table properties
* Add values to context table
* Remove Context tables
* Download Site Collector Certificates
* Retrieve list of Site Collectors
* Perform Exabeam search
* Get Exabeam Site Agent Install Command
* Get Exabeam Site Agents

> **Note:** For changes from version 1.3.0 and older, please refer to the [ARCHIVE.md](docs/ARCHIVE.md).

---

## [Cmdlet Version Requirements](#Cmdlet-Version-Requirements)
LogRhythm.Tools was developed and has undergone testing leveraging LogRhythm SIEM versions 7.4.X and 7.5.X.  Validate the SIEM version with the Minimum Version specification below prior to submitting Cmdlet issues.

> **Note:** For cmdlet requirements introduced in version 1.3.0 and older, please refer to our [Archived Requirements](docs/ARCHIVE.md).

### Version: 1.5.0

|Cmdlet|API Endpoint|Category|Minimum Version|
|------|------------|--------|---------------|
|Get-LrtConfiguration|Module|Configuration|All versions|
|Initialize-LrtConfiguration|Module|Configuration|All versions|
|Set-LrtConfiguration|Module|Configuration|All versions|
|Test-LrtConfiguration|Module|Configuration|All versions|
|Add-LrFileToCase|Case|Evidence|7.5.0|
|Add-LrHostRole|Admin|Hosts|7.5.0|
|Add-LrIdentityBulk|Admin|Identity|7.5.0|
|Add-LrLsvTemplateItem|Admin|LSV|7.8.0|
|Add-LrNotificationGroupUsers|Admin|Notification|7.5.0|
|Add-LrPlaybookAttachment|Case|Attachments|7.5.0|
|Add-LrUserEventToCase|Case|Evidence|7.5.0|
|Approve-LrLogSourcePending|Admin|LogSources|7.5.0|
|Approve-LrLogSourcesPending|Admin|LogSources|7.5.0|
|Copy-LrUserProfile|Admin|Users|7.5.0|
|Deny-LrLogSourcePending|Admin|LogSources|7.5.0|
|Deny-LrLogSourcesPending|Admin|LogSources|7.5.0|
|Export-LrPlaybook|Case|Playbooks|7.5.0|
|Get-LrAdminUser|Admin|Users|7.5.0|
|Get-LrAdminUsers|Admin|Users|7.5.0|
|Get-LrAlarmUrl|Alarms|Alarms|7.7.0|
|Get-LrBeat|Admin|Beats|7.8.0|
|Get-LrBeats|Admin|Beats|7.8.0|
|Get-LrBeatTemplate|Admin|Beats|7.8.0|
|Get-LrBeatTypes|Admin|Beats|7.8.0|
|Get-LrCaseCapabilities|Case|General|7.5.0|
|Get-LrCaseEvidenceFile|Case|Evidence|7.5.0|
|Get-LrCaseEvidenceLogBytes|Case|Evidence|7.5.0|
|Get-LrCaseEvidenceProgress|Case|Evidence|7.5.0|
|Get-LrCaseFeatureFlags|Case|General|7.5.0|
|Get-LrCaseFileProgress|Case|Evidence|7.5.0|
|Get-LrCaseFileWhitelist|Case|Evidence|7.5.0|
|Get-LrCaseGlobalHistory|Case|History|7.5.0|
|Get-LrCaseLogsIndexes|Case|General|7.5.0|
|Get-LrCasePlaybookAttachment|Case|Attachments|7.5.0|
|Get-LrCasePlaybookAttachmentFile|Case|Attachments|7.5.0|
|Get-LrCasePlaybookAttachments|Case|Attachments|7.5.0|
|Get-LrCaseUserEvents|Case|Evidence|7.5.0|
|Get-LrIdentityFromList|Admin|Identity|7.5.0|
|Get-LrIdentityMerged|Admin|Identity|7.5.0|
|Get-LrIdentityPhoto|Admin|Identity|7.5.0|
|Get-LrLicenseEntitlements|Admin|Licenses|7.5.0|
|Get-LrLicenses|Admin|Licenses|7.5.0|
|Get-LrLocationDetails|Admin|Location|7.5.0|
|Get-LrLogSourcePendingMatches|Admin|LogSources|7.5.0|
|Get-LrLogVolume|Metrics|Metrics|7.5.0|
|Get-LrLsvTemplate|Admin|LSV|7.8.0|
|Get-LrLsvTemplateItems|Admin|LSV|7.8.0|
|Get-LrLsvTemplates|Admin|LSV|7.8.0|
|Get-LrMpePoliciesSummary|Admin|MPE Rules|7.5.0|
|Get-LrMpePolicyRules|Admin|MPE Rules|7.5.0|
|Get-LrMpeRule|Admin|MPE Rules|7.5.0|
|Get-LrMsgSourceType|Admin|MsgSourceTypes|7.5.0|
|Get-LrMsgSourceTypes|Admin|MsgSourceTypes|7.5.0|
|Get-LrOpenCollector|Admin|OpenCollectors|7.8.0|
|Get-LrOpenCollectorBeats|Admin|OpenCollectors|7.8.0|
|Get-LrOpenCollectors|Admin|OpenCollectors|7.8.0|
|Get-LrPlaybookAttachment|Case|Attachments|7.5.0|
|Get-LrPlaybookAttachmentFile|Case|Attachments|7.5.0|
|Get-LrPlaybookAttachments|Case|Attachments|7.5.0|
|Get-LrTtlDetails|Metrics|Metrics|7.5.0|
|Get-LrUserLoginsByPerson|Admin|Users|7.5.0|
|Get-LrUserLogins|Admin|Users|7.5.0|
|Get-LrUserPermissions|Admin|Users|7.5.0|
|Get-LrUserPrivileges|Admin|Users|7.5.0|
|Get-LrUserProfile|Admin|Users|7.5.0|
|Get-LrUserProfileLogSources|Admin|Users|7.5.0|
|Get-LrUserProfilePrivileges|Admin|Users|7.5.0|
|Get-LrUserProfiles|Admin|Users|7.5.0|
|Get-LrUserProfilesSummary|Admin|Users|7.5.0|
|Import-LrAieRule|AIE|Engine|7.5.0|
|Import-LrEntities|Admin|Entities|7.5.0|
|Import-LrHosts|Admin|Entities|7.5.0|
|Import-LrNetworks|Admin|Entities|7.5.0|
|Invoke-LrCaseLogMaintenance|Case|General|7.5.0|
|Invoke-LrTrueIdentityConflictMerger|Admin|Identity|7.5.0|
|Join-LrLogSourcePending|Admin|LogSources|7.5.0|
|New-LrAdminUser|Admin|Users|7.5.0|
|New-LrAgent|Admin|Agents|7.5.0|
|New-LrBeat|Admin|Beats|7.8.0|
|New-LrLogSourcePending|Admin|LogSources|7.5.0|
|New-LrLsvTemplate|Admin|LSV|7.8.0|
|New-LrMpePolicy|Admin|MPE Rules|7.5.0|
|New-LrMpeRule|Admin|MPE Rules|7.5.0|
|New-LrMsgSourceType|Admin|MsgSourceTypes|7.5.0|
|New-LrNotificationGroup|Admin|Notification|7.5.0|
|New-LrOpenCollector|Admin|OpenCollectors|7.8.0|
|New-LrUserLogin|Admin|Users|7.5.0|
|New-LrUserProfile|Admin|Users|7.5.0|
|Remove-LrCaseEvidence|Case|Evidence|7.5.0|
|Remove-LrHostRole|Admin|Hosts|7.5.0|
|Remove-LrLogSourcePending|Admin|LogSources|7.5.0|
|Remove-LrLsvAssociations|Admin|LSV|7.8.0|
|Remove-LrLsvTemplateItems|Admin|LSV|7.8.0|
|Remove-LrMpePolicy|Admin|MPE Rules|7.5.0|
|Remove-LrMsgSourceType|Admin|MsgSourceTypes|7.5.0|
|Remove-LrNotificationGroup|Admin|Notification|7.5.0|
|Remove-LrNotificationGroupUsers|Admin|Notification|7.5.0|
|Remove-LrPlaybookAttachment|Case|Attachments|7.5.0|
|Remove-LrUserProfile|Admin|Users|7.5.0|
|Restart-LrAieService|AIE|Engine|7.5.0|
|Send-LrCaseFile|Case|Evidence|7.5.0|
|Set-LrAgent|Admin|Agents|7.5.0|
|Set-LrAieRuleStatuses|AIE|Engine|7.5.0|
|Set-LrBeatStatus|Admin|Beats|7.8.0|
|Set-LrLogSourceStatus|Admin|LogSources|7.5.0|
|Set-LrLogSourceVirtualization|Admin|LSV|7.8.0|
|Set-LrMpeRuleStatus|Admin|MPE Rules|7.5.0|
|Set-LrOpenCollectorStatus|Admin|OpenCollectors|7.8.0|
|Update-LrAgent|Admin|Agents|7.5.0|
|Update-LrBeat|Admin|Beats|7.8.0|
|Update-LrBeatHeartbeat|Admin|Beats|7.8.0|
|Update-LrCaseEvidence|Case|Evidence|7.5.0|
|Update-LrCaseLogsIndex|Case|Evidence|7.5.0|
|Update-LrCaseMetrics|Case|Metrics|7.5.0|
|Update-LrHosts|Admin|Hosts|7.5.0|
|Update-LrLsvTemplate|Admin|LSV|7.8.0|
|Update-LrLsvTemplateItem|Admin|LSV|7.8.0|
|Update-LrMpePolicy|Admin|MPE Rules|7.5.0|
|Update-LrMpePolicyRule|Admin|MPE Rules|7.5.0|
|Update-LrMpeRule|Admin|MPE Rules|7.5.0|
|Update-LrMsgSourceType|Admin|MsgSourceTypes|7.5.0|
|Update-LrNetworks|Admin|Networks|7.5.0|
|Update-LrNotificationGroup|Admin|Notification|7.5.0|
|Update-LrOpenCollector|Admin|OpenCollectors|7.8.0|
|Update-LrOpenCollectorHeartbeat|Admin|OpenCollectors|7.8.0|
|Update-LrPlaybookPartial|Case|Playbooks|7.5.0|

### Version: 1.4.0

|Cmdlet|API Endpoint|Category|Minimum Version|
|------|------------|--------|---------------|
|Add-LrLogSource|Admin|LogSources|7.5.0|
|Get-LrLogSourceTypeDetails|Admin|LogSources|7.5.0|
|Get-LrMpePolicies|Admin|MPE Rules|7.5.0|
|Get-LrMpePolicy|Admin|MPE Rules|7.5.0|
|Get-LrMpeRules|Admin|MPE Rules|7.5.0|
|Get-RfAlerts|RecordedFuture|Alert|All versions|
|Update-RfAlert|RecordedFuture|Alert|All versions|
|Add-ExaContextRecords|Exabeam|Context|All versions|
|Get-ExaContextTables|Exabeam|Context|All versions|
|Get-ExaContextTableAttributes|Exabeam|Context|All versions|
|New-ExaContextTable|Exabeam|Context|All versions|
|Remove-ExaContextTable|Exabeam|Context|All versions|
|Get-ExaSiteCollectorCerts|Exabeam|Cores|All versions|
|Get-ExaSiteCollectors|Exabeam|Cores|All versions|
|Get-ExaSearch|Exabeam|Search|All versions|
|Get-ExaSiteAgentInstallCommand|Exabeam|Agents|All versions|
|Get-ExaSiteAgents|Exabeam|Agents|All versions|
