# SNMP — Port <% tp.frontmatter.current_port %>
<%* let ip = tp.frontmatter.target_ip -%>

> [!info] SNMP runs on UDP. If discovered on TCP it's unusual — check both. Community strings act as passwords (v1/v2c have no encryption).

---

## Community String Discovery
```bash
onesixtyone -c /usr/share/seclists/Discovery/SNMP/common-snmp-community-strings-onesixtyone.txt <% ip %>
```

```bash
onesixtyone -c /usr/share/seclists/Discovery/SNMP/snmp.txt <% ip %> -w 100
```

```bash
hydra -P /usr/share/seclists/Discovery/SNMP/common-snmp-community-strings.txt -v <% ip %> snmp
```

```bash
nmap -sU -p 161 --script=snmp-brute <% ip %>
```

---

## Basic Enumeration

### snmpwalk (v1/v2c)
```bash
# Full walk with public community
snmpwalk -v2c -c public <% ip %>
```

```bash
# Save output
snmpwalk -v2c -c public <% ip %> > snmp_<% ip %>.txt 2>&1
```

```bash
# Targeted OIDs
snmpwalk -v2c -c public <% ip %> 1.3.6.1.2.1.1.5.0   # Hostname
snmpwalk -v2c -c public <% ip %> 1.3.6.1.2.1.1.1.0   # System description
snmpwalk -v2c -c public <% ip %> 1.3.6.1.2.1.25.1.6.0 # Total processes
```

### snmpbulkwalk (faster)
```bash
snmpbulkwalk -v2c -c public <% ip %> > snmp_bulk_<% ip %>.txt
```

---

## Key OID Targets

```bash
# System info
snmpwalk -v2c -c public <% ip %> 1.3.6.1.2.1.1

# Running processes
snmpwalk -v2c -c public <% ip %> 1.3.6.1.2.1.25.4.2.1.2

# Process paths (look for credentials in args!)
snmpwalk -v2c -c public <% ip %> 1.3.6.1.2.1.25.4.2.1.5

# Installed software
snmpwalk -v2c -c public <% ip %> 1.3.6.1.2.1.25.6.3.1.2

# Open TCP ports
snmpwalk -v2c -c public <% ip %> 1.3.6.1.2.1.6.13.1.3

# Network interfaces
snmpwalk -v2c -c public <% ip %> 1.3.6.1.2.1.2.2.1.2

# IP routing table
snmpwalk -v2c -c public <% ip %> 1.3.6.1.2.1.4.21.1.1

# User accounts (Windows)
snmpwalk -v2c -c public <% ip %> 1.3.6.1.4.1.77.1.2.25

# Windows shares
snmpwalk -v2c -c public <% ip %> 1.3.6.1.4.1.77.1.2.27

# Hostname
snmpwalk -v2c -c public <% ip %> 1.3.6.1.2.1.1.5.0
```

---

## Dedicated Enumeration Tools
```bash
# snmp-check — all-in-one enum
snmp-check <% ip %> -c public
```

```bash
# snmpenum
perl snmpenum.pl <% ip %> public windows.txt
```

```bash
# nmap scripts
nmap -sU -p 161 --script=snmp-info,snmp-interfaces,snmp-netstat,snmp-processes,snmp-sysdescr,snmp-win32-services,snmp-win32-shares,snmp-win32-software,snmp-win32-users <% ip %>
```

---

## SNMP v3 Enumeration
```bash
# v3 requires auth (MD5/SHA) and optionally privacy (DES/AES)
snmpwalk -v3 -l authPriv -u <username> -a SHA -A <authpass> -x AES -X <privpass> <% ip %>
```

```bash
# Brute force v3 users
nmap -sU -p 161 --script=snmp-brute --script-args snmp-brute.communitiesdb=/usr/share/seclists/Discovery/SNMP/common-snmp-community-strings.txt <% ip %>
```

---

## Write Community String (if writable — rare but dangerous)
```bash
# Test write access
snmpset -v2c -c <write_community> <% ip %> 1.3.6.1.2.1.1.6.0 s "Pwned"

# Verify
snmpget -v2c -c public <% ip %> 1.3.6.1.2.1.1.6.0
```

---

## Parse Interesting Data
```bash
# Extract all strings that look like passwords from snmpwalk output
grep -i 'pass\|pwd\|secret\|key\|auth\|cred' snmp_<% ip %>.txt
```

---

## SNMP Config Locations
```
/etc/snmp/snmpd.conf          — Linux daemon config (community strings)
/etc/snmp/snmp.conf
C:\Windows\System32\snmp.exe  — Windows SNMP service
```

---

## Notes
