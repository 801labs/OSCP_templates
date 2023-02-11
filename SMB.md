# SMB - <% tp.frontmatter.current_port %>

#### Nmap
```nmap
nmap -p445 --script smb-vuln-* <% tp.frontmatter.target_ip %>
```

#### SMBClient
```SMB
smbclient -N -L //<% tp.frontmatter.target_ip %>
```

#### SMBMAP
```smbmap
smbmap -H <% tp.frontmatter.target_ip %>
```


#### SMBMAP for domain
```bash
smbmap -H <% tp.frontmatter.target_ip %> -d <% tp.frontmatter.domain %>
```

#### smbexec
```smbexec
python smbexec.py <% tp.frontmatter.domain %>/<user>:<password>@<% tp.frontmatter.target_ip %>
```

#### smbexec w/out domain
```smbexec
python smbexec.py <user>:<password>@<% tp.frontmatter.target_ip %>
```