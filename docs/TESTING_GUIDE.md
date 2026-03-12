# LogRhythm.Tools Testing Guide

A practical guide for SIEM administrators who want to validate that LogRhythm.Tools works correctly in their environment. You do not need to be a developer to follow this guide -- just PowerShell and your SIEM.

---

## Table of Contents

- [Getting Started](#getting-started)
- [Tier 0-2: Offline Tests (No API Needed)](#tier-0-2-offline-tests-no-api-needed)
- [Tier 3: Read-Only API Tests](#tier-3-read-only-api-tests)
- [Tier 4: Write Tests (Use Test Objects)](#tier-4-write-tests-use-test-objects)
- [Tier 5: Third-Party Tests](#tier-5-third-party-tests)
- [When a Cmdlet Fails](#when-a-cmdlet-fails)
- [Postman as a Companion](#postman-as-a-companion)

---

## Getting Started

### 1. Fork and Clone the Repo

Go to [https://github.com/LogRhythm-Tools/LogRhythm.Tools](https://github.com/LogRhythm-Tools/LogRhythm.Tools), click **Fork**, then clone your fork:

```powershell
git clone https://github.com/YOUR-USERNAME/LogRhythm.Tools.git
cd LogRhythm.Tools
```

### 2. Run the Offline Validation First

Before touching any API, confirm the module loads and passes basic checks. This catches broken files, missing parameters, and code standard violations without needing any credentials:

```powershell
.\tests\Test-ModuleValidation.ps1
```

If everything passes, you will see `All checks passed!` at the end. If something fails, fix it before moving on -- there is no point testing API calls if the module itself is broken.

### 3. Build and Import the Module

The fastest way to get a working copy into your session:

```powershell
.\build\New-TestBuild.ps1
```

This builds the module from source and imports it into your current PowerShell session. Add `-RemoveOld` to clean up previous builds first:

```powershell
.\build\New-TestBuild.ps1 -RemoveOld
```

### 4. Set Up Configuration

If this is your first time, you need to configure the module with your SIEM connection details:

```powershell
# Interactive setup -- walks you through each field
Initialize-LrtConfiguration
```

This will prompt you for:
- Your LogRhythm Platform Manager (PM) URL (e.g., `https://pm-server:8501`)
- Your API key (generated from the LogRhythm Client Console under Third Party Applications)
- Optional third-party API keys (VirusTotal, Shodan, etc.)

Configuration is stored per-user at `$env:LocalAppData\LogRhythm.Tools\LogRhythm.Tools.json`. API keys are encrypted, so they only work for your Windows account on your machine.

Verify your configuration loaded correctly:

```powershell
Get-LrtConfiguration
```

---

## Tier 0-2: Offline Tests (No API Needed)

These tests validate that the module is structurally sound. They check code, not connectivity.

### Run the Full Validation

```powershell
.\tests\Test-ModuleValidation.ps1
```

### Run with Per-Cmdlet Details

If you want to see exactly what passed and what failed on each cmdlet:

```powershell
.\tests\Test-ModuleValidation.ps1 -Detailed
```

### What the Phases Mean

| Phase | What It Checks | Common Failures |
|-------|---------------|-----------------|
| **Phase 1 - Module Load** | Can PowerShell import the module without errors? | Syntax errors in .ps1 files, missing dependencies |
| **Phase 2 - Cmdlet Discovery** | Do all filenames match their function names? Are all public functions exported? | A file named `Get-LrHosts.ps1` containing `Function Get-LrHost` (mismatch) |
| **Phase 3 - Parameter Validation** | Do all functions use `[CmdletBinding()]`? Do mutating cmdlets have `-PassThru`? | Missing `-PassThru` on a `New-*` or `Update-*` cmdlet |
| **Phase 4 - Help Completeness** | Do API cmdlets have SYNOPSIS, DESCRIPTION, EXAMPLE, and LINK? | Missing `.EXAMPLE` block |
| **Phase 5 - Code Standards** | No `Write-Output`, has `$Me`, has `Enable-TrustAllCertsPolicy`, uses `Invoke-RestAPIMethod` (not raw `Invoke-RestMethod`) | Using `Write-Output` instead of returning objects directly |
| **Phase 6 - Config Cmdlets** | Can the configuration cmdlets be found and called? | Missing config file after a fresh clone |

**PASS** = working as expected.
**FAIL** = something is wrong and needs to be fixed.
**WARN** = not critical, but worth investigating.
**SKIP** = test did not apply (e.g., connectivity tests skipped when not requested).

If all six phases pass, you are ready to test against your SIEM.

---

## Tier 3: Read-Only API Tests

These commands only **read** data from your SIEM. They do not create, modify, or delete anything. They are safe to run in production, though we recommend using your test environment.

Before running these, make sure your configuration is set:

```powershell
# Quick sanity check -- does the module know where your SIEM is?
$LrtConfig.LogRhythm | Select-Object BaseUrl, Version
```

### Admin API

These prove your API key works and your SIEM is reachable:

```powershell
# List accepted agents -- proves Admin API auth works
Get-LrAgentsAccepted

# Look up a specific host by name
Get-LrHosts -Name "your-hostname-here"

# List all entities
Get-LrEntities

# Check license info (v1.5.0+)
Get-LrLicenses

# List log source types
Get-LrLogSourceTypes

# List admin users (v1.5.0+)
Get-LrAdminUsers
```

If `Get-LrAgentsAccepted` returns a list of your System Monitor agents, your Admin API connection is working.

### Case API

```powershell
# List recent cases
Get-LrCases

# List playbooks
Get-LrPlaybooks

# List tags
Get-LrTags

# Check case capabilities (v1.5.0+)
Get-LrCaseCapabilities
```

### Alarm API

```powershell
# List recent alarms (requires SIEM 7.7+)
Get-LrAlarms
```

### Search API

```powershell
# Create a disposable search task -- this does create a search job,
# but it is read-only and the task is cleaned up automatically
New-LrSearch
```

### AIE API

```powershell
# View AIE drilldown data (requires an active AIE alarm ID)
Get-LrAieDrilldown -AlarmId 12345
```

Replace `12345` with an actual alarm ID from your environment. You can get one from `Get-LrAlarms`.

### Metrics API (v1.5.0+)

```powershell
# Time-to-qualify/time-to-resolve details
Get-LrTtlDetails

# Log volume over the last 7 days
Get-LrLogVolume -StartDate (Get-Date).AddDays(-7) -EndDate (Get-Date)
```

### What Success Looks Like

Each command should return PowerShell objects (tables or lists of data). If you get back objects with properties like `id`, `name`, `status`, etc., it is working.

If you get an error, jump to [When a Cmdlet Fails](#when-a-cmdlet-fails).

---

## Tier 4: Write Tests (Use Test Objects)

These tests create, modify, and delete objects in your SIEM. **Run these in a test environment.** Each block creates throwaway objects and cleans up after itself.

### Case Lifecycle Test

This creates a test case, adds evidence, tags it, verifies it, then closes it:

```powershell
# Create a test case with a timestamped name so it is easy to find
$TestCase = New-LrCase -Name "LRT-Test-$(Get-Date -Format 'yyyyMMdd-HHmm')" `
    -Priority 4 `
    -Summary "Module validation test -- safe to delete" `
    -PassThru

Write-Host "Created case: $($TestCase.number) - $($TestCase.name)"

# Add a note to the case
Add-LrNoteToCase -Id $TestCase.id -Text "Test note from LogRhythm.Tools validation" -PassThru

# Add tags
Add-LrCaseTags -Id $TestCase.id -Tags @("test", "lrt-validation") -PassThru

# Verify everything stuck
$Verify = Get-LrCaseById -Id $TestCase.id
Write-Host "Case status: $($Verify.status.name)"
Write-Host "Tags: $(($Verify.tags | ForEach-Object { $_.text }) -join ', ')"

# Clean up -- resolve the case (status 5 = Resolved, -Force walks through required transitions)
Update-LrCaseStatus -Id $TestCase.id -StatusNumber 5 -Force -PassThru
Write-Host "Case resolved."
```

### Host Lifecycle Test

```powershell
# Create a test host
$TestHost = New-LrHost -Entity "Primary Site" `
    -Name "LRT-TestHost-$(Get-Date -Format 'yyyyMMdd')" `
    -ShortDescription "Module validation test host" `
    -HostZone "Internal" `
    -OS "Windows" `
    -OSType "Server" `
    -PassThru

Write-Host "Created host: $($TestHost.id) - $($TestHost.name)"

# Update the host
Update-LrHost -Id $TestHost.id `
    -ShortDescription "Updated by LRT validation" `
    -PassThru

# Verify
$VerifyHost = Get-LrHostDetails -Id $TestHost.id
Write-Host "Host: $($VerifyHost.name) - $($VerifyHost.shortDesc)"

# Clean up -- retire the host
Update-LrHost -Id $TestHost.id -RecordStatus "Retired" -PassThru
Write-Host "Host retired."
```

### List Lifecycle Test

```powershell
# Create a test list (GeneralValue type for simple string values)
$TestList = New-LrList -Name "LRT-TestList-$(Get-Date -Format 'yyyyMMdd-HHmm')" `
    -ListType "generalvalue" `
    -ShortDescription "Module validation test list" `
    -PassThru

Write-Host "Created list: $($TestList.name) (GUID: $($TestList.guid))"

# Add items to the list
Add-LrListItem -Name $TestList.name -Value "test-value-001" -PassThru
Add-LrListItem -Name $TestList.name -Value "test-value-002" -PassThru

# Verify items
$Items = Get-LrListItems -Name $TestList.name
Write-Host "List has $($Items.Count) items"

# Remove an item
Remove-LrListItem -Name $TestList.name -Value "test-value-001" -PassThru

# Verify removal
$ItemsAfter = Get-LrListItems -Name $TestList.name
Write-Host "List now has $($ItemsAfter.Count) items"

# Note: Lists cannot be deleted via the API. Mark it as inactive or leave it.
# The timestamped name makes it obvious this was a test.
Write-Host "Done. Test list '$($TestList.name)' can be manually removed from the Client Console."
```

### Playbook Lifecycle Test

```powershell
# Create a test playbook
$TestPlaybook = New-LrPlaybook -Name "LRT-TestPlaybook-$(Get-Date -Format 'yyyyMMdd-HHmm')" `
    -Description "Module validation test playbook" `
    -PassThru

Write-Host "Created playbook: $($TestPlaybook.id) - $($TestPlaybook.name)"

# Copy it
$CopiedPlaybook = Copy-LrPlaybook -Id $TestPlaybook.id `
    -Name "LRT-TestPlaybook-Copy-$(Get-Date -Format 'yyyyMMdd-HHmm')" `
    -PassThru

Write-Host "Copied playbook: $($CopiedPlaybook.id) - $($CopiedPlaybook.name)"

# Clean up -- delete both
Remove-LrPlaybook -Id $CopiedPlaybook.id -PassThru
Remove-LrPlaybook -Id $TestPlaybook.id -PassThru
Write-Host "Both playbooks deleted."
```

### Checklist

After running all four blocks, verify:
- [ ] Cases: create, note, tag, status update, resolve
- [ ] Hosts: create, update, retrieve details, retire
- [ ] Lists: create, add items, retrieve items, remove items
- [ ] Playbooks: create, copy, delete

---

## Tier 5: Third-Party Tests

These are optional. Only test services you have API keys configured for.

### VirusTotal

If you configured a VirusTotal API key during `Initialize-LrtConfiguration`:

```powershell
# Look up the EICAR test file hash (a known safe test signature)
Get-VTHashReport -Hash "275a021bbfb6489e54d471899f7db9d1663fc695ec2fe2a2c4538aabf651fd0f"
```

You should see scan results from multiple AV engines. If you get an error about rate limiting, the free VT API allows 4 requests per minute -- just wait and try again.

### Shodan

If you configured a Shodan API key:

```powershell
# Look up a well-known public IP (Google DNS)
Get-ShodanHostIp -IPAddress "8.8.8.8"
```

You should get back host information including open ports, organization, and location data.

### Skip What You Do Not Have

If you do not have keys for VirusTotal, Shodan, Recorded Future, or any other third-party service, skip those tests. The LogRhythm SIEM cmdlets (Tiers 3 and 4) are the core of the module and do not depend on third-party integrations.

---

## When a Cmdlet Fails

### Step 1: Add -Verbose

Every cmdlet supports `-Verbose`. This shows you the exact URL, headers, and request body being sent:

```powershell
Get-LrHosts -Name "myhost" -Verbose
```

Look for lines like:
```
VERBOSE: [Get-LrHosts]: Request URL: https://pm-server:8501/lr-admin-api/hosts?name=myhost
VERBOSE: [Get-LrHosts]: Response Status: 200
```

This tells you exactly what endpoint is being called.

### Step 2: Check the Error Object

When a cmdlet fails, it returns a structured error object. Inspect it:

```powershell
$Result = Get-LrHosts -Name "myhost"

# If it failed, check these properties:
$Result.Error       # Error message from the API
$Result.Code        # HTTP status code (401 = auth, 403 = permissions, 404 = not found)
$Result.Note        # Additional context from the cmdlet
$Result.Raw         # The raw API response
```

Common error codes:
| Code | Meaning | Fix |
|------|---------|-----|
| 401 | Unauthorized | Your API key is wrong or expired. Re-run `Initialize-LrtConfiguration`. |
| 403 | Forbidden | Your API user does not have permission for this endpoint. Check roles in the Client Console. |
| 404 | Not Found | The object ID or name does not exist, or the API endpoint is not available on your SIEM version. |
| 429 | Rate Limited | Too many requests. The module retries automatically, but if you see this repeatedly, slow down. |
| 500 | Server Error | Something went wrong on the SIEM side. Check the SIEM logs. |

### Step 3: Verify Your SIEM Version

Some cmdlets require specific SIEM versions. Check what the module thinks your version is:

```powershell
$LrtConfig.LogRhythm.Version
```

If this is blank or wrong, update it with `Initialize-LrtConfiguration`. For example, `Get-LrAlarms` requires SIEM 7.7+, and the Metrics cmdlets are new in v1.5.0.

### Step 4: Test the Same Endpoint in Postman or a Browser

If the cmdlet fails but you are not sure whether the issue is the module or the API, test the endpoint directly. See the next section.

---

## Postman as a Companion

Postman is useful for isolating whether a problem is in the module code or in the API itself. If the same request works in Postman but fails in PowerShell, the issue is in the cmdlet. If it fails in both, the issue is on the SIEM side.

### When to Use Postman

- A cmdlet returns an unexpected error and `-Verbose` is not giving enough detail
- You want to explore what the raw API response looks like before writing PowerShell
- You are debugging a new or undocumented endpoint

### Setting Up Postman for LogRhythm

1. **Get your base URL from the module config:**

```powershell
$LrtConfig.LogRhythm.BaseUrl
# Example output: https://pm-server:8501
```

2. **Set up authentication.** In Postman, add a header to every request:

| Header | Value |
|--------|-------|
| `Authorization` | `Bearer your-api-token-here` |

Your API token is the same one you configured with `Initialize-LrtConfiguration`. If you need to retrieve it:

```powershell
# This shows the decrypted token (treat it like a password)
$LrtConfig.LogRhythm.ApiKey
```

3. **Disable SSL verification.** If your SIEM uses a self-signed certificate (most test environments do):
   - In Postman: **Settings** (gear icon) > **General** > Turn off **SSL certificate verification**
   - This matches what `Enable-TrustAllCertsPolicy` does in the module

4. **Try a test request.** Create a GET request to:

```
https://your-pm-server:8501/lr-admin-api/hosts?count=5
```

With the `Authorization: Bearer <token>` header. If you get back a JSON array of hosts, your connection is good.

### Common API Base Paths

| API Category | Base Path |
|-------------|-----------|
| Admin (hosts, agents, entities, lists) | `/lr-admin-api/` |
| Cases | `/lr-case-api/cases/` |
| Alarms | `/lr-alarm-api/alarms/` |
| Search | `/lr-search-api/` |
| AIE | `/lr-drilldown-cache-api/` |

### Example: Testing Host Lookup in Both

**PowerShell:**
```powershell
Get-LrHosts -Name "webserver01" -Verbose
```

**Postman:**
```
GET https://pm-server:8501/lr-admin-api/hosts?name=webserver01
Authorization: Bearer <your-token>
```

If both return the same data, the module is working correctly. If Postman works but PowerShell does not, you have found a module bug -- file an issue on GitHub.

---

## Quick Reference: Test Order

| Tier | What | Risk | Time |
|------|------|------|------|
| 0-2 | Offline validation | None | 30 seconds |
| 3 | Read-only API calls | None | 5 minutes |
| 4 | Create/update/delete test objects | Low (test env) | 15 minutes |
| 5 | Third-party integrations | None | 5 minutes per service |

Start at Tier 0. If it passes, move to Tier 3. If that works, move to Tier 4. Do not skip tiers -- each one builds confidence that the previous layer is working.
