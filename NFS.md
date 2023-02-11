# NFS - <% tp.frontmatter.current_port %>

### Show available mounts
```bash
showmount -e <% tp.frontmatter.target_ip %>
```

### Mount 
```bash
sudo mount -t nfs -o nolock,nfsvers=3 <% tp.frontmatter.target_ip %>:/<target_share> <local_folder>
```


