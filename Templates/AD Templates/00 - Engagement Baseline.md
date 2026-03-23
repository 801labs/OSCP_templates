---
# === ENGAGEMENT METADATA ===
engagement_name:
client:
date:
operator:

# === NETWORK / DOMAIN ===
domain: domain.local
dc_ip: 10.10.10.1
dc_fqdn: dc-01.domain.local
dc_hostname: dc-01
domain_sid: S-1-5-21-

# === CREDENTIALS ===
username:
password:
ntlm_hash:
aes256_hash:
aes128_hash:

# === TARGET ===
target_ip:
target_host:
target_fqdn:
target_user:

# === ATTACKER / C2 ===
lhost: 10.10.10.100
lport: 4444
c2_listener: http

# === TOOL PREFERENCES ===
os_env: windows
win_ticket_tool: rubeus
lin_ticket_tool: impacket
enum_tool: adsearch
cred_tool: mimikatz

# === ATTACK SELECTION ===
selected_attack: 01 - Kerberoasting
---

# Engagement Baseline

> [!tip] How to Use This File
> 1. Fill in all fields below — they are read by every attack template automatically.
> 2. Select an attack from the dropdown, then click **Start Attack Workflow** to create a new guided note.
> 3. Each attack note imports these baseline values so you only need to enter them once.

---

## Engagement Configuration

```dataviewjs
const p = dv.current();

const engInput     = `\`INPUT[text(defaultValue("${p.engagement_name ?? ''}")):engagement_name]\``;
const clientInput  = `\`INPUT[text(defaultValue("${p.client ?? ''}")):client]\``;
const dateInput    = `\`INPUT[text(defaultValue("${p.date ?? ''}")):date]\``;
const opInput      = `\`INPUT[text(defaultValue("${p.operator ?? ''}")):operator]\``;

dv.table(["Field", "Value"], [
  ["Engagement Name", engInput],
  ["Client",          clientInput],
  ["Date",            dateInput],
  ["Operator",        opInput],
]);
```

---

## Domain / Network

```dataviewjs
const p = dv.current();

const domInput    = `\`INPUT[text(defaultValue("${p.domain ?? 'domain.local'}")):domain]\``;
const dcipInput   = `\`INPUT[text(defaultValue("${p.dc_ip ?? ''}")):dc_ip]\``;
const dcfqdnInput = `\`INPUT[text(defaultValue("${p.dc_fqdn ?? ''}")):dc_fqdn]\``;
const dchostInput = `\`INPUT[text(defaultValue("${p.dc_hostname ?? ''}")):dc_hostname]\``;
const sidInput    = `\`INPUT[text(defaultValue("${p.domain_sid ?? 'S-1-5-21-'}")):domain_sid]\``;

dv.table(["Field", "Value"], [
  ["Domain",           domInput],
  ["DC IP",            dcipInput],
  ["DC FQDN",          dcfqdnInput],
  ["DC Hostname",      dchostInput],
  ["Domain SID",       sidInput],
]);
```

---

## Credentials

```dataviewjs
const p = dv.current();

const userInput  = `\`INPUT[text(defaultValue("${p.username ?? ''}")):username]\``;
const passInput  = `\`INPUT[text(defaultValue("${p.password ?? ''}")):password]\``;
const ntlmInput  = `\`INPUT[text(defaultValue("${p.ntlm_hash ?? ''}")):ntlm_hash]\``;
const aes256Input= `\`INPUT[text(defaultValue("${p.aes256_hash ?? ''}")):aes256_hash]\``;
const aes128Input= `\`INPUT[text(defaultValue("${p.aes128_hash ?? ''}")):aes128_hash]\``;

dv.table(["Field", "Value"], [
  ["Username",      userInput],
  ["Password",      passInput],
  ["NTLM Hash",     ntlmInput],
  ["AES-256 Hash",  aes256Input],
  ["AES-128 Hash",  aes128Input],
]);
```

---

## Attacker / C2

```dataviewjs
const p = dv.current();

const lhostInput    = `\`INPUT[text(defaultValue("${p.lhost ?? ''}")):lhost]\``;
const lportInput    = `\`INPUT[text(defaultValue("${p.lport ?? '4444'}")):lport]\``;
const listenerInput = `\`INPUT[text(defaultValue("${p.c2_listener ?? 'http'}")):c2_listener]\``;

dv.table(["Field", "Value"], [
  ["LHOST (Attacker IP)", lhostInput],
  ["LPORT",              lportInput],
  ["C2 Listener",        listenerInput],
]);
```

---

## Tool Preferences

```dataviewjs
const p = dv.current();

const RUBEUS   = "rubeus";
const IMPACKET = "impacket";
const NETEXEC  = "netexec";
const WIN      = "windows";
const LIN      = "linux";

const osSelect      = `\`INPUT[inlineSelect(defaultValue(${p.os_env ?? WIN}),option(${WIN}),option(${LIN})):os_env]\``;
const winTicket     = `\`INPUT[inlineSelect(defaultValue(${p.win_ticket_tool ?? RUBEUS}),option(${RUBEUS}),option(certutil)):win_ticket_tool]\``;
const linTicket     = `\`INPUT[inlineSelect(defaultValue(${p.lin_ticket_tool ?? IMPACKET}),option(${IMPACKET}),option(${NETEXEC})):lin_ticket_tool]\``;
const enumSelect    = `\`INPUT[inlineSelect(defaultValue(${p.enum_tool ?? 'adsearch'}),option(adsearch),option(powerview),option(ldapsearch),option(bloodhound)):enum_tool]\``;
const credSelect    = `\`INPUT[inlineSelect(defaultValue(${p.cred_tool ?? 'mimikatz'}),option(mimikatz),option(nanodump),option(pypykatz)):cred_tool]\``;

dv.table(["Preference", "Selection"], [
  ["OS Environment",       osSelect],
  ["Windows Ticket Tool",  winTicket],
  ["Linux Ticket Tool",    linTicket],
  ["Enumeration Tool",     enumSelect],
  ["Credential Tool",      credSelect],
]);
```

---

## Launch Attack Workflow

Select an attack and click the button to create a new guided workflow note.

```dataviewjs
const p = dv.current();

const attacks = [
  "01 - Kerberoasting",
  "02 - AS-REP Roasting",
  "03 - Unconstrained Delegation",
  "04 - Constrained Delegation",
  "05 - Resource-Based Constrained Delegation",
  "06 - Shadow Credentials",
  "07 - DCSync",
  "08 - Golden Ticket",
  "09 - Silver Ticket",
  "10 - Diamond Ticket",
  "11 - ADCS ESC1 Misconfigured Template",
  "12 - ADCS NTLM Relay",
  "13 - ADCS Forged Certificates",
  "14 - Pass the Hash",
  "15 - Pass the Ticket",
  "16 - Over Pass the Hash",
  "17 - Token Impersonation",
  "18 - Lateral Movement",
  "19 - MS SQL Attacks",
  "20 - Host Privilege Escalation",
  "21 - Credential Theft",
  "22 - Group Policy Abuse",
  "23 - LAPS Abuse",
  "24 - Password Spraying",
  "25 - Persistence",
  "26 - NTLM Relay",
  "27 - DPAPI Secrets",
  "28 - SCCM Attacks",
  "29 - AppLocker Bypass",
  "30 - Forest and Domain Trusts",
  "31 - Azure AD Entra ID Attacks",
  "32 - BloodHound and Attack Path Automation",
  "33 - LLMNR NBT-NS Poisoning",
  "34 - ADCS ESC2 through ESC8",
  "35 - Kerberos Relay KrbRelay",
  "36 - DCShadow",
  "37 - AdminSDHolder Abuse",
  "38 - ACL DACL Abuse",
  "39 - Exchange ProxyShell Attacks",
  "40 - ADFS Golden SAML",
];

const options = attacks.map(a => `option(${a})`).join(',');
const current = p.selected_attack ?? attacks[0];
const selectWidget = `\`INPUT[inlineSelect(defaultValue(${current}),${options}):selected_attack]\``;
dv.paragraph("**Selected Attack:** " + selectWidget);
```

```meta-bind-button
style: primary
label: 🚀 Start Attack Workflow
id: start_attack_workflow
hidden: false
action:
  type: inlineJS
  code: |
    const attack = context.metadata.frontmatter?.selected_attack ?? "01 - Kerberoasting";

    // Resolve folder this baseline file lives in (the engagement folder)
    const currentFolder = context.file.parent.path;
    const folderName    = context.file.parent.name;

    const templatePath = "Templates/AD Templates/" + attack + ".md";
    const attackName   = attack.replace(/^\d+\s*-\s*/, '');
    const newFileName  = attackName + " - " + folderName;
    const newFilePath  = currentFolder + "/" + newFileName + ".md";

    const template = app.vault.getAbstractFileByPath(templatePath);
    if (!template) {
      new Notice("❌ Template not found: " + templatePath);
      return;
    }

    // Read attack template and repoint its baseline reference to THIS engagement baseline
    let content = await app.vault.read(template);
    const oldRef = "Templates/AD Templates/00 - Engagement Baseline";
    const newRef = currentFolder + "/AD Baseline - " + folderName;
    content = content.replaceAll(oldRef, newRef);

    // Avoid overwriting an existing file
    let finalPath = newFilePath;
    let counter = 1;
    while (app.vault.getAbstractFileByPath(finalPath)) {
      finalPath = currentFolder + "/" + newFileName + " (" + counter + ").md";
      counter++;
    }

    const newFile = await app.vault.create(finalPath, content);
    await app.workspace.openLinkText(newFile.basename, currentFolder, true);
    new Notice("✅ Created: " + newFile.basename);
```

---

## Current Baseline Summary

```dataviewjs
const p = dv.current();
dv.table(["Key", "Value"], [
  ["Domain",     p.domain     ?? "—"],
  ["DC IP",      p.dc_ip      ?? "—"],
  ["DC FQDN",    p.dc_fqdn    ?? "—"],
  ["Username",   p.username   ?? "—"],
  ["LHOST",      p.lhost      ?? "—"],
  ["OS Env",     p.os_env     ?? "—"],
]);
```
