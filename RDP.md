# RDP

## Connecting

```bash
rdesktop -E -u <user> -p <password> <% tp.frontmatter.target_ip %> -g 95% 
```

**WIth domain**
```bash
rdesktop -E -u <user> -p <password> <% tp.frontmatter.target_ip %> -g 95% -d <% tp.frontmatter.domain %>
```

