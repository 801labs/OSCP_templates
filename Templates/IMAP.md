<%-*
if (tp.frontmatter.current_port == undefined) {
  tp.frontmatter.current_port = await tp.system.prompt('Enter IMAP/POP3 port: ')
}
-%>
# IMAP / POP3 — Port <% tp.frontmatter.current_port %>
<%*
let port = parseInt(tp.frontmatter.current_port)
let ip = tp.frontmatter.target_ip
let user = tp.frontmatter.username || '<user>'
let pass = tp.frontmatter.password || '<pass>'
let proto = (port === 110 || port === 995) ? 'POP3' : 'IMAP'
let tls = (port === 993 || port === 995)
-%>

> [!info] Port mapping: 110=POP3, 143=IMAP, 993=IMAPS(TLS), 995=POP3S(TLS). These protocols expose **email inboxes** — look for credentials, internal info, and PII.

---

## Nmap
```bash
nmap -p<% port %> --script=imap-capabilities,imap-ntlm-info,pop3-capabilities,pop3-ntlm-info <% ip %>
```

---

## Banner Grab
```bash
nc -nv <% ip %> <% port %>
```

```bash
# TLS version (993 / 995)
openssl s_client -connect <% ip %>:<% port %>
```

```bash
# STARTTLS (IMAP 143)
openssl s_client -starttls imap -connect <% ip %>:143
```

---

## IMAP Manual Commands
```bash
nc -nv <% ip %> <% port %>
# After banner:
A001 CAPABILITY
A001 LOGIN <% user %> <% pass %>
A001 LIST "" "*"
A001 SELECT INBOX
A001 FETCH 1:* (FLAGS BODY[HEADER.FIELDS (SUBJECT FROM DATE)])
A001 FETCH 1 BODY[]
A001 LOGOUT
```

---

## POP3 Manual Commands
```bash
nc -nv <% ip %> <% port %>
# After banner:
USER <% user %>
PASS <% pass %>
LIST
RETR 1
DELE 1
QUIT
```

---

## Automated Tools

### Curl (IMAP)
```bash
# List mailboxes
curl -k imaps://<% ip %>/ --user '<% user %>:<% pass %>'

# List inbox
curl -k imaps://<% ip %>/INBOX --user '<% user %>:<% pass %>'

# Download specific email
curl -k 'imaps://<% ip %>/INBOX;MAILINDEX=1' --user '<% user %>:<% pass %>'
```

```bash
# Plain IMAP
curl imap://<% ip %>/ --user '<% user %>:<% pass %>'
curl 'imap://<% ip %>/INBOX' --user '<% user %>:<% pass %>'
curl 'imap://<% ip %>/INBOX;UID=1' --user '<% user %>:<% pass %>'
```

### Curl (POP3)
```bash
# List messages
curl pop3://<% ip %>/ --user '<% user %>:<% pass %>'

# Download first message
curl pop3://<% ip %>/1 --user '<% user %>:<% pass %>'
```

---

## Dump All Mail (Python)
```python
import imaplib, email

mail = imaplib.IMAP4_SSL('<% ip %>')
mail.login('<% user %>', '<% pass %>')

mail.select('inbox')
_, msg_ids = mail.search(None, 'ALL')
for msg_id in msg_ids[0].split():
    _, msg_data = mail.fetch(msg_id, '(RFC822)')
    msg = email.message_from_bytes(msg_data[0][1])
    print(f"From: {msg['From']}\nSubject: {msg['Subject']}\nDate: {msg['Date']}\n")
    if msg.is_multipart():
        for part in msg.walk():
            if part.get_content_type() == 'text/plain':
                print(part.get_payload(decode=True).decode('utf-8', errors='ignore'))
    else:
        print(msg.get_payload(decode=True).decode('utf-8', errors='ignore'))
    print('---')

mail.logout()
```

---

## Brute Force
```bash
hydra -l '<% user %>' -P /usr/share/wordlists/rockyou.txt imap://<% ip %> -s <% port %> -t 4 -V
```

```bash
hydra -l '<% user %>' -P /usr/share/wordlists/rockyou.txt pop3://<% ip %> -s <% port %> -t 4
```

```bash
nxc imap <% ip %> -u users.txt -p passwords.txt
```

---

## What to Look For in Email
```
- Password reset emails (internal systems, credentials in body)
- Shared credentials / onboarding docs
- HR emails with PII
- Internal network diagrams / documentation
- API keys, tokens
- References to other internal systems
- VPN / SSL certificates
```

---

## Notes
