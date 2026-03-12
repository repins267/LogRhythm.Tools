# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

LogRhythm.Tools is a PowerShell module (v1.4.0) providing 254+ cmdlets for LogRhythm SIEM automation and third-party integrations (VirusTotal, Shodan, Recorded Future, Mimecast, Proofpoint, Azure/Graph API, etc.). Supports Windows PowerShell 5.0+ (.NET Framework 4.5.2) and PowerShell Core (.NET 6.0+).

## Build & Development Commands

```powershell
# Development build (from repo root):
.\build\New-TestBuild.ps1              # Build and import into current session
.\build\New-TestBuild.ps1 -RemoveOld   # Clean old builds first

# Manual build:
Import-Module .\build\Lrt.Builder.psm1
New-LrtBuild                           # Creates versioned build in build\out\
Get-LrtBuild                           # Get current build info
Publish-LrtBuild                       # Publish to destination

# Install (after build):
.\dist\Setup.ps1                       # Interactive installer
.\dist\Setup.ps1 -SilentInstall ...    # Silent install (see CI workflow for params)
```

Tests use Pester but are currently outdated/removed. Templates exist at `docs/templates/3-Pester.Tests.ps1`.

## Architecture

**Module loading:** `src/LogRhythm.Tools.psm1` recursively dot-sources all `.ps1` files under `src/Public/` and `src/Private/`. File names must exactly match the function name they contain.

**Source layout:**
- `src/Public/` — Exported cmdlets organized by service (LogRhythm/, Azure/, VirusTotal/, Shodan/, etc.)
- `src/Private/` — Internal helpers (REST invocation, error handling, type conversion)
- `build/` — LrtBuilder module and build scripts
- `dist/` — Installer (Setup.ps1) and ModuleInfo.json (version, metadata)
- `docs/templates/` — Function, REST function, Azure REST function, Pester test, and class templates

**LogRhythm cmdlets** (`src/Public/LogRhythm/`) are sub-organized: Admin/ (Agents, Entities, Hosts, Identities, Lists, Locations, LogSources, Networks, Users), Alarms/, AIE/, Case/ (Evidence, Metrics, Playbooks, Tags), Echo/, OC/, Search/, ThreatIntelligence/.

**Configuration:** User-specific config stored in `$env:LocalAppData\LogRhythm.Tools\LogRhythm.Tools.json`. API keys stored as encrypted XML via `Export-Clixml`/`Import-Clixml`.

**Key module variables** (exported): `$LrtConfig`, `$HttpMethod`, `$HttpContentType`, `$LrCaseStatus`.

**REST API pattern:** Cmdlets use `Invoke-RestAPIMethod` (private) as the central HTTP handler with retry logic for 429/500 errors. Error responses use a structured ErrorObject with Code, Error, Type, Note, Raw properties.

## Code Conventions

- **Naming:** `[Verb]-[Lr|Lrt][Class][Description]` using approved PowerShell verbs. PascalCase for functions, variables, and parameters.
- **One function per file.** File name must match function name exactly.
- **Indentation:** 4 spaces, no tabs. Braces on same line as statement.
- **Output:** Never use `Write-Output`. Use `Write-Host` or `Write-Verbose` for user messages. Return objects directly for pipeline output.
- **Error handling:** Use try/catch (not trap). Return structured ErrorObject for API failures.
- **Comment-based help** required: SYNOPSIS, DESCRIPTION, PARAMETER, INPUTS, OUTPUTS, EXAMPLE, LINK.
- **Comments:** Line break at 100 characters. Describe intent, not code.
- **Cmdlet structure:** Use `[CmdletBinding()]`, Begin/Process/End blocks.

## Critical Rules Not to Violate
- **Always use `Invoke-RestAPIMethod`** (not raw `Invoke-RestMethod`) — handles 429/500
  retry automatically. Pass `-Origin $Me` on every call.
- **`$Me = $MyInvocation.MyCommand.Name`** required in every Begin{} block
- **`Enable-TrustAllCertsPolicy`** required in every Begin{} block
- **`-PassThru` switch** required on all mutating cmdlets (New/Add/Update/Remove/Set)
- **`Run-` is not an approved verb** — `Run-LrTrueIdentityMerger` needs renaming to
  `Invoke-LrTrueIdentityMerger`

## Task File
Full audit and update instructions: `./LRTools_ClaudeCode_Prompt.md`
API reference: https://developers.exabeam.com/logrhythm-siem/reference
