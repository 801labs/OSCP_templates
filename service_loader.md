 <%-* let ports = tp.frontmatter.ports.replace(/,\s*$/, "").split(',') -%>

<%-* let playbook = {21:"FTP",22:"SSH",23:"Telnet",53:"DNS",80:"HTTP",161:"SNMP",162:"SNMP",
443:"HTTP",445:"SMB",1433:"MSSQL",3306:"MySQL",3389:"RDP",6379:"Redis",8080:"HTTP"} -%>

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
ports.forEach(function (element) { 
file_include = `[[Templates/${playbook[element]}]]`
if (!file_include.includes('undefined')) {
_%>
<% tp.file.include(file_include) %>
<%*}}) %>
<%* let content = await tp.file.include("[[Templates/Commands]]") + "" %>
<%* let file_exists = await tp.file.exists(tp.file.folder(true) + "/Commands.md") %>
<%-* if (file_exists == false) { %>
<% ( await tp.file.create_new(content, tp.file.folder(true) + "/Commands")).basename %>
<%* } %>
<%* let writeup_exists = await tp.file.exists(tp.file.folder(true) + "/Writeup.md") %>
<%-* if (writeup_exists == false) { %>
<% ( await tp.file.create_new("# Writeup", tp.file.folder(true) + "/Writeup")).basename %>
<%* } %>
