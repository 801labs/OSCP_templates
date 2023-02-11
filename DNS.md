# DNS - <% tp.frontmatter.current_port %>

## Reverse lookup - different methods 
**Note: IP should be of the machine you are looking to do a DNS lookup on**
```bash
dig -x <% tp.frontmatter.target_ip %> @<% tp.frontmatter.target_ip %>
```

```bash
dnsrecon -r <% tp.frontmatter.target_ip %>
```

## zone transfer 
```bash
dnsrecon -d <% tp.frontmatter.target_ip %> -t axfr
```

```bash
dig axfr @<% tp.frontmatter.target_ip %>
```


## Bruteforcing DNS
**Just a simple domain guess**
```bash
dig axfr @dig axfr @<% tp.frontmatter.target_ip %> <% tp.frontmatter.domain %>
```

```bash
dnsrecon -d <% tp.frontmatter.target_ip %> -D /usr/share/seclists/Discovery/DNS/namelist.txt -t brt
```

```bash
gobuster dns -d <% tp.frontmatter.domain %> -w /usr/share/seclists/Discovery/DNS/namelist.txt -i
```

```bash
dnsenum --dnsserver <% tp.frontmatter.target_ip %> --enum -p 0 -s 0 -o subdomains.txt -f /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt --threads 90 <domain>
```
## If those don't work try this command
* -r range for our host
* -n nameserver 
* -d domain, can be anything
```bash
dnsrecon -r 127.0.0.0/24 -n <% tp.frontmatter.target_ip %> -d blah
```
