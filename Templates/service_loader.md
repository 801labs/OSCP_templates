# Enumeration — <% tp.frontmatter.target_ip %>
---
<%-*
if (tp.frontmatter.domain === "domain.local" || !tp.frontmatter.domain) {
  const ans = await tp.system.prompt('Enter Domain (leave blank to keep domain.local): ')
  if (ans && ans.trim() !== "") tp.frontmatter.domain = ans.trim()
}
if (!tp.frontmatter.domain || tp.frontmatter.domain === "") tp.frontmatter.domain = "domain.local"
-%>

<%* let ports = tp.frontmatter.ports.replace(/,\s*$/, "").split(',').map(p => p.trim()).filter(Boolean) -%>

<%*
// ─────────────────────────────────────────────
// PORT → TEMPLATE MAPPING
// Add new ports here — point to existing .md files in Templates/
// ─────────────────────────────────────────────
let playbook = {
  // FTP
  21:"FTP", 990:"FTP",
  // SSH
  22:"SSH",
  // Telnet
  23:"Telnet",
  // SMTP
  25:"SMTP", 465:"SMTP", 587:"SMTP",
  // DNS
  53:"DNS",
  // HTTP / HTTPS
  80:"HTTP", 443:"HTTP", 8080:"HTTP", 8443:"HTTP",
  8000:"HTTP", 8008:"HTTP", 8888:"HTTP", 8081:"HTTP",
  8181:"HTTP", 9090:"HTTP", 9443:"HTTP", 10000:"HTTP",
  // Kerberos
  88:"Kerberos",
  // POP3 / IMAP
  110:"IMAP", 143:"IMAP", 993:"IMAP", 995:"IMAP",
  // RPC / NetBIOS
  111:"MSRPC", 135:"MSRPC", 139:"SMB",
  // SNMP
  161:"SNMP", 162:"SNMP",
  // LDAP / LDAPS
  389:"LDAP", 636:"LDAP", 3268:"LDAP", 3269:"LDAP",
  // SMB
  445:"SMB",
  // LDAP Global Catalog already handled above
  // Rsync
  873:"Rsync",
  // MSSQL
  1433:"MSSQL",
  // Oracle
  1521:"Oracle",
  // NFS
  2049:"NFS",
  // MySQL
  3306:"MySQL",
  // RDP
  3389:"RDP",
  // PostgreSQL
  5432:"Postgres",
  // VNC
  5800:"VNC", 5900:"VNC", 5901:"VNC", 5902:"VNC",
  // WinRM
  5985:"WinRM", 5986:"WinRM",
  // Redis
  6379:"Redis",
  // MongoDB
  27017:"MongoDB", 27018:"MongoDB", 27019:"MongoDB",
  // Elasticsearch
  9200:"Elasticsearch", 9300:"Elasticsearch",
}
-%>

<%* let check_manually = ports.filter(n => !Object.keys(playbook).includes(String(n.trim()))) -%>
<%* if (check_manually.length > 0) { -%>
> [!warning] Manually investigate these ports (no template match)
> ```
> <% check_manually.join(', ') %>
> ```
> Run: `nmap -sV -sC -p<% check_manually.join(',') %> <% tp.frontmatter.target_ip %> -Pn`
<%* } -%>

---

<%* if (tp.frontmatter.is_ad?.toLowerCase() == 'yes') { _%>
<% tp.file.include("[[Templates/Active Directory]]") %>
<%*
// ── Create engagement-specific AD Baseline in target folder ──
const _folderPath = tp.file.folder(true)
const _folderName = tp.file.folder(false)
const _baselineName = `AD Baseline - ${_folderName}`
const _baselinePath = `${_folderPath}/${_baselineName}.md`
const _baselineExists = await tp.file.exists(_baselinePath)
if (!_baselineExists) {
  const _src = app.vault.getAbstractFileByPath("Templates/AD Templates/00 - Engagement Baseline.md")
  if (_src) {
    const _raw = await app.vault.read(_src)
    await app.vault.create(_baselinePath, _raw)
    new Notice(`AD Baseline created: ${_baselineName}`)
  } else {
    new Notice("Could not find: Templates/AD Templates/00 - Engagement Baseline.md")
  }
}
_%>
<%* } -%>

<%*
let seen = {}
for (let index in ports) {
  let port = ports[index].trim()
  let templateName = playbook[port]
  if (!templateName) continue
  let file_include = `[[Templates/${templateName}]]`
  if (!file_include.includes('undefined')) {
    tp.frontmatter.current_port = port
    let current_template = await tp.file.include(file_include) + ""
    tR += current_template
  }
}
-%>

---

<%* let file_name = tp.file.folder(false) -%>
<%* let file_exists = await tp.file.exists(tp.file.folder(true) + `/Commands - ${file_name}.md`) -%>
<%* if (file_exists == false) { %>
<%* let content = await tp.file.include("[[Templates/Commands]]") + "" -%>
<%- (await tp.file.create_new(content, tp.file.folder(true) + `/Commands - ${file_name}.md`)).basename -%>
<%* } %>

<%* let extras = ['Writeup', 'Notes', 'Loot']
for (let index in extras) {
  let extra_file = extras[index]
  let extras_exists = await tp.file.exists(tp.file.folder(true) + `/${extra_file} - ${file_name}.md`)
  if (extras_exists == false) {
    await tp.file.create_new(`# ${extra_file} — ${file_name}\n\n`, tp.file.folder(true) + `/${extra_file} - ${file_name}.md`)
  }
} %>
