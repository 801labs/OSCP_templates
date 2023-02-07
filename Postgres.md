# Postgres

### Default creds `postgres:postgres`

### Connecting
```bash
psql -h <% tp.frontmatter.target_ip %> -U <user> -W
```

**Try without password**
```bash
psql -h <% tp.frontmatter.target_ip %> -U <user> -w
```

