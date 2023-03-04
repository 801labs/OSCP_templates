<%-*
if ( tp.frontmatter.current_port  == undefined) {
	tp.frontmatter.current_port = await tp.system.prompt('Enter port number: ')
}
-%>
# HTTP - <% tp.frontmatter.current_port %>
### make sure look at EVERYTHING that comes back
<%* 
let url = `http://${tp.frontmatter.target_ip}`
if (parseInt(tp.frontmatter.current_port) == 443) {
url = url.replace('http', 'https')
} else {
url += `:${tp.frontmatter.current_port}`
}
-%>
## Directory discovery

Get all headers
```bash
curl -I <% url %>
```

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

## Nikto
**Basic nikto scan**
```bash
nikto -h <% url %>
```
