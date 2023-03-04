<%-*
if ( tp.frontmatter.current_port  == undefined) {
	tp.frontmatter.current_port = await tp.system.prompt('Enter port number: ')
}
-%>
# Postgres - <% tp.frontmatter.current_port %>
<%*
let different_port = ""
if (parseInt(tp.frontmatter.current_port) != 5432) {
	different_port = `--port=${tp.frontmatter.current_port}`
}
-%>
### Default creds `postgres:postgres`

### Connecting
```bash
psql -h <% tp.frontmatter.target_ip %> -U <user> -W <% different_port %>
```

**Try without password**
```bash
psql -h <% tp.frontmatter.target_ip %> -U <user> -w <% different_port %>
```

