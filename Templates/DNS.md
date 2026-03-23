# DNS — Port <% tp.frontmatter.current_port %>
<%* let ip = tp.frontmatter.target_ip; let domain = tp.frontmatter.domain -%>

---

## Banner / Version
```bash
nmap -p<% tp.frontmatter.current_port %> --script=dns-nsid,dns-recursion,dns-zone-transfer <% ip %>
```

```bash
dig version.bind CH TXT @<% ip %>
```

---

## Reverse Lookup
```bash
dig -x <% ip %> @<% ip %>
```

```bash
dnsrecon -r <% ip %>/32 -n <% ip %>
```

```bash
host <% ip %> <% ip %>
```

---

## Forward Lookup / Record Enumeration
```bash
# All record types for domain
dig any <% domain %> @<% ip %>
```

```bash
# Specific record types
dig A <% domain %> @<% ip %>
dig AAAA <% domain %> @<% ip %>
dig MX <% domain %> @<% ip %>
dig NS <% domain %> @<% ip %>
dig TXT <% domain %> @<% ip %>
dig SRV _ldap._tcp.<% domain %> @<% ip %>
dig SRV _kerberos._tcp.<% domain %> @<% ip %>
dig SRV _kpasswd._tcp.<% domain %> @<% ip %>
```

```bash
# AD-specific SRV records (very useful for AD recon)
dig SRV _ldap._tcp.dc._msdcs.<% domain %> @<% ip %>
dig SRV _kerberos._tcp.dc._msdcs.<% domain %> @<% ip %>
dig A dc.<% domain %> @<% ip %>
dig A domaindnszones.<% domain %> @<% ip %>
dig A forestdnszones.<% domain %> @<% ip %>
```

---

## Zone Transfer
```bash
dig axfr <% domain %> @<% ip %>
```

```bash
dig axfr @<% ip %>
```

```bash
dnsrecon -d <% domain %> -t axfr -n <% ip %>
```

```bash
host -l <% domain %> <% ip %>
```

```bash
fierce --domain <% domain %> --dns-servers <% ip %>
```

---

## DNS Brute Force / Subdomain Enumeration
```bash
dnsrecon -d <% domain %> -D /usr/share/seclists/Discovery/DNS/namelist.txt -t brt -n <% ip %>
```

```bash
dnsenum --dnsserver <% ip %> --enum -p 0 -s 0 -f /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt -o subdomains.xml <% domain %>
```

```bash
gobuster dns -d <% domain %> -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt -t 50 -i --wildcard
```

```bash
amass enum -d <% domain %> -src -ip -brute -min-for-recursive 2
```

```bash
dnsx -d <% domain %> -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt -o dns_results.txt
```

---

## Internal DNS Reconnaissance (from inside network)
```bash
# Discover all hosts in a subnet via PTR records
dnsrecon -r <% ip %>/24 -n <% ip %>
```

```bash
for i in $(seq 1 254); do host 10.10.10.$i <% ip %> 2>/dev/null | grep -v "not found"; done
```

---

## DNS Cache Snooping
```bash
# Check if DNS server has cached a domain (non-recursive)
dig @<% ip %> <% domain %> A +norecurse
```

---

## DNS Amplification Check
```bash
nmap -p<% tp.frontmatter.current_port %> --script=dns-recursion <% ip %>
```

---

## DNSSEC
```bash
dig DNSKEY <% domain %> @<% ip %>
dig DS <% domain %> @<% ip %>
```

---

## Interesting Internal Names to Try
```bash
for host in dc dc01 dc02 vpn mail smtp ftp www intranet internal dev test backup admin helpdesk; do
  echo -n "$host.<% domain %>: "
  dig +short $host.<% domain %> @<% ip %>
done
```

---

## Notes
