# Bulk Host Import with Both IP and Hostname Identifiers

## Problem

LogRhythm hosts created with only a Type=1 (IP) identifier are
vulnerable to duplicate host record creation when DHCP changes the
IP. The Mediator's host resolution searches Type=3 (hostname) first;
if no Type=3 exists, resolution falls through to IP, and a new IP
means a new Host record.

The EMDB stored procedures fully support creating hosts with multiple
identifier types. This document shows how to use the API to import
hosts with both Type=1 (IP) and Type=3 (hostname) identifiers.

## HostIdentifier Type Reference

| Type | API Name    | Description                |
|------|-------------|----------------------------|
| 1    | IPAddress   | IPv4 or IPv6 address       |
| 2    | DNSName     | Fully qualified DNS name   |
| 3    | WindowsName | NetBIOS / machine hostname |

## Method 1: New-LrHost with -IPAddress and -Hostname

The simplest approach for individual hosts:

```powershell
New-LrHost -Entity "Primary Site" -Name "FIREWALL-01" `
    -IPAddress "10.0.1.1" -Hostname "FIREWALL-01" `
    -Zone "internal" -OS "Unknown" -OSType "Server" -PassThru
```

This creates the Host record, then adds both Type=1 and Type=3
identifiers in a single call.

## Method 2: Pipeline Bulk Import

```powershell
$hosts = Import-Csv "C:\imports\hosts.csv"
# CSV columns: Entity, Name, IPAddress, Hostname, Zone, OS, OSType

$hosts | ForEach-Object {
    New-LrHost -Entity $_.Entity -Name $_.Name `
        -IPAddress $_.IPAddress -Hostname $_.Hostname `
        -Zone $_.Zone -OS $_.OS -OSType $_.OSType
}
```

## Method 3: Admin API Direct (Host_InsertSMAcceptanceHosts)

For bulk import via the Admin API JSON endpoint, send two array
elements per host with the same `HostName` but different
`HostIdentifierType` values:

```json
[
  {
    "EntityID": 1,
    "HostName": "FIREWALL-01",
    "ShortDesc": "",
    "LongDesc": "",
    "HostZone": 1,
    "RiskThreshold": 0,
    "RecordStatus": 1,
    "OS": 0,
    "OSVersion": "",
    "LocationID": null,
    "UseEventLogCredentials": 0,
    "EventLogUsername": "",
    "EventLogPassword": "",
    "OSType": 0,
    "HostIdentifierType": 1,
    "HostIdentifierValue": "10.0.1.1"
  },
  {
    "EntityID": 1,
    "HostName": "FIREWALL-01",
    "ShortDesc": "",
    "LongDesc": "",
    "HostZone": 1,
    "RiskThreshold": 0,
    "RecordStatus": 1,
    "OS": 0,
    "OSVersion": "",
    "LocationID": null,
    "UseEventLogCredentials": 0,
    "EventLogUsername": "",
    "EventLogPassword": "",
    "OSType": 0,
    "HostIdentifierType": 3,
    "HostIdentifierValue": "FIREWALL-01"
  }
]
```

The Host MERGE key is `(EntityID, HostName)`. The second row matches
the same host and only adds the Type=3 identifier.

## Method 4: Admin API Host_Import (Identifiers Array)

```json
// @ImportHosts:
[{
  "ID": 0, "EntityID": 1, "Name": "FIREWALL-01",
  "ShortDescription": "", "LongDescription": "",
  "RecordStatus": 1, "RiskLevel": 0, "ThreatLevel": 0,
  "ThreatLevelComments": "", "HostZone": 1,
  "OperatingSystem": 0, "OSVesrsion": "", "Location": 0
}]

// @HosttoHostIdentifiers:
{
  "HostsToHostIdentifiers": [{
    "HostID": 0,
    "HostName": "FIREWALL-01",
    "Identifiers": [
      { "Type": 1, "Value": "10.0.1.1" },
      { "Type": 3, "Value": "FIREWALL-01" }
    ]
  }]
}
```

## Validation Query

After import, confirm both identifier types were created:

```sql
SELECT h.HostID, h.EntityID, h.Name,
       hi.Type,
       CASE hi.Type WHEN 1 THEN 'IPAddress'
                    WHEN 2 THEN 'DNSName'
                    WHEN 3 THEN 'WindowsName' END AS TypeName,
       hi.Value, hi.DateAssigned, hi.DateRetired
FROM Host h
INNER JOIN HostIdentifier hi ON h.HostID = hi.HostID
WHERE h.Name = 'FIREWALL-01'
ORDER BY hi.Type;
```

Expected: two rows per host (Type=1 with IP, Type=3 with hostname).

## Notes

- The LogRhythm Console import UI does NOT expose the Type=3
  identifier field. Use the API or PowerShell for correct bulk import.
- The `Host_UniqueName` constraint enforces uniqueness on
  `(EntityID, Host.Name)`. Two entities CAN share the same hostname.
- If `tr_HostIdentifier_RetireConflictingIPs` is deployed, it will
  automatically retire conflicting Type=1 IPs within the same entity.
