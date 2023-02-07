<%-* let [domain,tld] = tp.frontmatter.domain.split('.') -%>
# LDAP
get everything
```bash
ldapsearch -x -H ldap://<% tp.frontmatter.dc_ip %> -D '' -w '' -b "DC=<% domain %>,DC=<% tld %>" > <% tp.frontmatter.dc_ip %>_ldap.txt
```

Get all users
```bash
ldapsearch -x -H ldap://<% tp.frontmatter.dc_ip %> -D '' -w '' -b "DC=<% domain %>,DC=<% tld %>"  '(objectClass=person)' > <% tp.frontmatter.dc_ip %>_ldap_users.txt
```
