# Information Gathering

```bash
sudo nmap -sS -p- -T4 <% tp.frontmatter.target_ip %> -oN <% tp.frontmatter.target_ip %>_syn.nmap -vvv
```

```bash
awk '
/^[0-9]+\/tcp/{
sub(/\/.*/,"",$1)
if(!tcpVal[$1]++){ a="" }
}
END{
for(j in tcpVal) { print j }
}' <% tp.frontmatter.target_ip %>_syn.nmap | awk '{print}' ORS=',' > <% tp.frontmatter.target_ip %>_ports.txt
```

```shell
nmap -sC -sV -p`cat <% tp.frontmatter.target_ip %>_ports.txt` <% tp.frontmatter.target_ip %> -oN <% tp.frontmatter.target_ip %>_full.nmap && cat <% tp.frontmatter.target_ip %>_ports.txt
```

