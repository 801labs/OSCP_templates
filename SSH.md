# SSH

### Errors with SSH
Error message: Unable to neotiate with <% tp.frontmatter.target_ip %> port 22: no matching key exchange method found. Their offer: diffie-hellman-group-exchange-sha1,diffie-hellman-group1-sha1

```bash
ssh <% tp.frontmatter.target_ip %> -oKexAlgorithms=+diffie-hellman-group1-sha1
```

Addional errors: Unable to negotiate with <% tp.frontmatter.target_ip %>  port 22: no matching chipher found. Their offer: aes128-cbc,3des-csc,blowfish-cbc,cast128-cbc,arcfour,aes192-cdc....

```bash
ssh <% tp.frontmatter.target_ip %> -oKexAlgorithms=+diffie-hellman-group1-sha1 -c aes128-cbc
```