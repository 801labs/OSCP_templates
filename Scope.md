---
date: <% tp.date.now("YYYY-MM-DD", -1) %>
my_ip: x.x.x.x
target_ip: x.x.x.x
domain: domain.local
ports: x,x,x
OS: linux|windows
is_ad: yes|no
dc_ip: x.x.x.x
---
<% await tp.file.rename("Services") -%>


---

# Enumeration