<%-*
if ( tp.frontmatter.current_port  == undefined) {
	tp.frontmatter.current_port = await tp.system.prompt('Enter port number: ')
}
-%>
# HTTP - <% tp.frontmatter.current_port %>
### make sure look at EVERYTHING that comes back
<%* 
let url = `http://${tp.frontmatter.target_ip}`
let subdomain_fuzz = `http://FUZZ.${tp.frontmatter.domain}`
if (parseInt(tp.frontmatter.current_port) == 443) {
	url = url.replace('http', 'https')
	subdomain_fuzz = url.replace('http', 'https')
} else {
	url += `:${tp.frontmatter.current_port}`
	subdomain_fuzz += `:${tp.frontmatter.current_port}`
}
-%>
## Directory discovery

Get all headers
```bash
curl -I <% url %>
```

Fuzz directories
```bash
ffuf -u <% url %>/FUZZ -w /usr/share/seclists/Discovery/Web-Content/raft-large-directories.txt
```

**Feroxbuster**
```
feroxbuster -u <% url %> -d 1 -w /usr/share/seclists/Discovery/Web-Content/raft-large-directories.txt
```

**Follow redirects**
```bash
ffuf -u <% url %>/FUZZ -w /usr/share/seclists/Discovery/Web-Content/raft-large-directories.txt -r
```

**If everything returns a 200 and almost everything is the same size, filter by response size**
```bash
ffuf -u <% url %>/FUZZ -w /usr/share/seclists/Discovery/Web-Content/raft-large-directories.txt -fs <size>
```

**Filter on number of words**
```bash
ffuf -u <% url %>/FUZZ -w /usr/share/seclists/Discovery/Web-Content/raft-large-directories.txt -fw <num of words>
```

**Adding file extensions**
**you can add multiple `.txt,.php,.js`**
```bash
ffuf -u <% url %>/FUZZ -w /usr/share/seclists/Discovery/Web-Content/raft-large-directories.txt -e <ext>
```

**Recursive search**
**You can adjust the depth by changing the variable**
```bash
ffuf -u <% url %>/FUZZ -w /usr/share/seclists/Discovery/Web-Content/raft-large-directories.txt -recursion -recursion-depth 2
```

## Subdomain fuzzing

vhost
```bash
ffuf -u <% url %> -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-110000.txt -H 'HOST: FUZZ.<% tp.frontmatter.domain %>'
```

requires something like [dnsmasq](https://www.tutorialspoint.com/unix_commands/dnsmasq.htm)or something similar 
```bash
ffuf -u <% subdomain_fuzz %> -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-110000.txt
```

### HEAVY DUTY subdomain fuzzing
has about significantly more domains in this list 
vhost
```bash
ffuf -u <% url %> -w /usr/share/seclists/Discovery/DNS/dns-Jhaddix.txt -H 'HOST: FUZZ.<% tp.frontmatter.domain %>'
```

requires something like [dnsmasq](https://www.tutorialspoint.com/unix_commands/dnsmasq.htm)or something similar 
```bash
ffuf -u <% subdomain_fuzz %> -w /usr/share/seclists/Discovery/DNS/dns-Jhaddix.txt
```


## Nikto
**Basic nikto scan**
```bash
nikto -h <% url %>
```
