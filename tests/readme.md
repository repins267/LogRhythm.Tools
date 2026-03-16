# LogRhythm.Tools — Testing Guide

## Overview

LogRhythm.Tools uses a three-layer testing strategy:

| Layer | Script | Requires API? | What it validates |
|-------|--------|---------------|-------------------|
| **Structure** | `Test-ModuleValidation.ps1` | No | Module load, exports, parameter compliance, code standards |
| **Unit** | `Run-Tests.ps1` (Pester 5.x) | No | Cmdlet logic with mocked API responses |
| **Integration** | `Test-LiveApiEndpoints.ps1` | Yes | Real endpoint paths, auth, pagination against live SIEM |

## Quick Start

```powershell
# 1. Run offline validation (no API key needed)
.\tests\Test-ModuleValidation.ps1

# 2. Run Pester unit tests
.\tests\Run-Tests.ps1

# 3. Run live integration tests (requires configured SIEM)
.\tests\Test-LiveApiEndpoints.ps1 -SkipSlow
```

## Pester Unit Tests

### Requirements
- PowerShell 7.x (or Windows PowerShell 5.1)
- Pester 5.x (auto-installed by `Run-Tests.ps1` if missing)

### Running Tests

```powershell
# All unit tests
.\tests\Run-Tests.ps1

# Specific directory
.\tests\Run-Tests.ps1 -Path .\tests\Admin\Agents\

# With detailed output
.\tests\Run-Tests.ps1 -Tag Unit -Detailed

# CI mode (NUnit XML output)
.\tests\Run-Tests.ps1 -OutputFile .\test-results.xml
```

### Test Structure

Each `.Tests.ps1` file follows this pattern:

```powershell
Describe "LogRhythm.Tools: <CmdletName>" -Tag 'Unit' {
    BeforeAll {
        Mock Invoke-RestAPIMethod { return <mock data> }
        Mock Enable-TrustAllCertsPolicy { }
    }

    Context "Input validation" {
        # Parameter existence, types, mandatory flags
    }

    Context "API response handling" {
        # URL construction, HTTP method, response passthrough
    }

    Context "Error handling" {
        # ErrorObject propagation on API failures
    }
}
```

### Test File Locations

```
tests/
├── Private/              # Invoke-RestAPIMethod, Enable-TrustAllCertsPolicy, helpers
├── General/              # Configuration cmdlets (Get/Set/Test/Initialize-LrtConfiguration)
├── Admin/                # Admin API cmdlets (Agents, Beats, Hosts, etc.)
│   ├── Agents/
│   ├── Beats/
│   ├── Entities/
│   ├── Hosts/
│   ├── Identities/
│   ├── Licenses/
│   ├── Location/
│   ├── LogSources/
│   │   └── LSV/
│   ├── MPERules/
│   ├── MsgSourceTypes/
│   ├── Networks/
│   ├── NotificationGroups/
│   ├── OpenCollectors/
│   └── Users/
├── AIE/Engine/           # AIE management cmdlets
├── Alarms/               # Alarm API cmdlets
├── Case/                 # Case API cmdlets
│   ├── Attachments/
│   ├── Evidence/
│   ├── General/
│   ├── History/
│   ├── Metrics/
│   └── Playbooks/
└── Metrics/              # Metrics API cmdlets
```

## Module Validation

`Test-ModuleValidation.ps1` runs 7 phases of offline checks:

1. **Module Load** — imports module, verifies no errors
2. **Cmdlet Discovery** — all expected cmdlets are exported
3. **Parameter Validation** — CmdletBinding, -PassThru on mutating cmdlets
4. **Help Completeness** — SYNOPSIS, DESCRIPTION, EXAMPLE, LINK required
5. **Code Standards** — no Write-Output, $Me pattern, Enable-TrustAllCertsPolicy, -Origin $Me, no raw Invoke-RestMethod
6. **Config Cmdlets** — Get/Set/Test/Initialize-LrtConfiguration validation
7. **Connectivity (optional)** — live API check with `-TestConnectivity`

```powershell
# Offline only
.\tests\Test-ModuleValidation.ps1

# Include connectivity check
.\tests\Test-ModuleValidation.ps1 -TestConnectivity
```

## Live API Test Harness

`Test-LiveApiEndpoints.ps1` runs every GET cmdlet against a live LogRhythm deployment.

### Usage

```powershell
# All services, skip slow endpoints
.\tests\Test-LiveApiEndpoints.ps1 -SkipSlow

# LogRhythm only
.\tests\Test-LiveApiEndpoints.ps1 -Service LogRhythm

# Admin category with verbose
.\tests\Test-LiveApiEndpoints.ps1 -Category Admin -Detailed
```

### Result Statuses

| Status | Meaning |
|--------|---------|
| **PASS** | Returned data, HTTP 200 |
| **WARN** | HTTP 200 but 0 results (empty data set — normal on fresh labs) |
| **SKIP** | Parent discovery returned 0 results, no Id to test with |
| **FAIL** | HTTP error or ErrorObject returned |

### JSON Output

Results saved to `tests/results/` with timestamps:
```
tests/results/2026-03-15T2140_lr_all.json
```

## Baseline Comparison

`Compare-TestBaseline.ps1` detects regressions between test runs.

```powershell
# Set current results as the baseline
.\tests\Compare-TestBaseline.ps1 -SetBaseline

# Compare latest run against baseline
.\tests\Compare-TestBaseline.ps1

# Compare specific file
.\tests\Compare-TestBaseline.ps1 -CurrentPath .\tests\results\2026-03-16_all.json
```

Exit code 1 if any regressions (PASS → FAIL) are detected.

## CI/CD

GitHub Actions runs structure validation and Pester unit tests on every push to `main`, `development`, and `v1.5.0-update`. See `.github/workflows/main.yml`.

No API credentials are needed in CI — only offline and mocked tests run automatically.
