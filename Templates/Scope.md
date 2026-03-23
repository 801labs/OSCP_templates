---
date: <% tp.date.now("YYYY-MM-DD", 0) %>
my_ip:
target_ip:
domain: domain.local
ports:
OS: linux
is_ad: no
dc_ip:
username:
password:
ntlm_hash:
notes:
---

```meta-bind-button
style: primary
label: 🔍 Run Port Scanner
action:
  type: "replaceSelf"
  replacement: "Templates/port_scan.md"
  templater: true
```

<%-* let file_name = `Services - ${tp.file.folder(false)}` -%>
<% await tp.file.rename(file_name) -%>
