# Enumeration
---
<%-*
if ( tp.frontmatter.domain  === "domain.local") {
	tp.frontmatter.domain = await tp.system.prompt('Enter Domain: ')
}
// Let's make sure it isn't just blank
if ( tp.frontmatter.domain  === "") {
	tp.frontmatter.domain = "domain.local"
}
-%>

<%* let ports = tp.frontmatter.ports.replace(/,\s*$/, "").split(',') -%>

<%-* let playbook = {21:"FTP",22:"SSH",23:"Telnet",53:"DNS",80:"HTTP",161:"SNMP",162:"SNMP",
443:"HTTP",445:"SMB",1433:"MSSQL",3306:"MySQL",3389:"RDP",5432:"Postgres",6379:"Redis",8080:"HTTP",2049:"NFS"} -%>

<%-* let check_manually = ports.filter(n => !Object.keys(playbook).includes(String(n))) -%>
<%-* if (check_manually.length > 0 ) { -%>
## Check these ports manually 
```text
<% check_manually %>
```
<%* } -%>
<%-* if (tp.frontmatter.is_ad == 'yes') { _%>
 <% tp.file.include("[[Templates/Active Directory]]") %>
<%*} -%>
<%-* 
let file_include = null
let port = null
for (index in ports) {
port = ports[index]
file_include = `[[Templates/${playbook[port]}]]`
tp.frontmatter.current_port = port
if (!file_include.includes('undefined')) { _%>
<%* let current_template = await tp.file.include(file_include) + "" -%>
<% current_template -%>
<%*}} -%>
<%-* let file_name = tp.file.folder(false) -%>
<%* let file_exists = await tp.file.exists(tp.file.folder(true) + `/Commands - ${file_name}.md`) -%>
<%-* if (file_exists == false) { %>
<%* let content = await tp.file.include("[[Templates/Commands]]") + "" -%>
<%- ( await tp.file.create_new(content, tp.file.folder(true) +  `/Commands - ${file_name}.md`)).basename -%>
<%-* } %>
<%-* let files = ['Writeup', 'Notes']
for (index in files) { 
let extra_file = files[index]
let extras_exists = await tp.file.exists(tp.file.folder(true) + `/${extra_file} - ${file_name}.md`)
extras_exists
if (extras_exists == false) { %>
<%- (await tp.file.create_new(`# ${extra_file} - ${file_name}`, tp.file.folder(true) + `/${extra_file} - ${file_name}.md`)).basename -%>
<%*}} %> 
