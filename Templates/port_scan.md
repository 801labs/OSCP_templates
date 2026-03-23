# Information Gathering — <% tp.frontmatter.target_ip %>
---

## Phase 1 — Fast Full-Port Sweep

### Masscan (fastest — finds all open ports)
```bash
sudo masscan -p1-65535 <% tp.frontmatter.target_ip %> --rate=1000 -e tun0 -oG <% tp.frontmatter.target_ip %>_masscan.txt
```

### Nmap SYN Scan (all ports)
```bash
sudo nmap -sS -p- -T4 --min-rate 5000 <% tp.frontmatter.target_ip %> -oN <% tp.frontmatter.target_ip %>_syn.nmap -vvv -Pn
```

### Extract open ports from nmap output
```bash
awk '/^[0-9]+\/tcp/{sub(/\/.*/,"",$1); if(!tcpVal[$1]++){ a="" }} END{for(j in tcpVal){print j}}' \
  <% tp.frontmatter.target_ip %>_syn.nmap | sort -n | awk '{print}' ORS=',' | sed 's/,$//' | tee <% tp.frontmatter.target_ip %>_ports.txt
```

### Quick port string from masscan output
```bash
grep "open" <% tp.frontmatter.target_ip %>_masscan.txt | awk '{print $4}' | cut -d'/' -f1 | sort -n | tr '\n' ',' | sed 's/,$//' | tee <% tp.frontmatter.target_ip %>_ports.txt
```

---

## Phase 2 — Service / Version Detection

### Full service scan on discovered ports
```bash
nmap -sC -sV -p$(cat <% tp.frontmatter.target_ip %>_ports.txt) <% tp.frontmatter.target_ip %> -oN <% tp.frontmatter.target_ip %>_full.nmap -oX <% tp.frontmatter.target_ip %>_full.xml -Pn
```

### View results
```bash
cat <% tp.frontmatter.target_ip %>_full.nmap
```

---

## Phase 3 — UDP Top Ports

### Top 200 UDP ports (common services: SNMP 161, TFTP 69, DNS 53)
```bash
sudo nmap -sU --top-ports 200 --min-rate 2000 <% tp.frontmatter.target_ip %> -oN <% tp.frontmatter.target_ip %>_udp.nmap -Pn
```

### Targeted UDP (SNMP, TFTP, DNS, NTP)
```bash
sudo nmap -sU -p 53,67,68,69,123,137,138,161,162,500,514,1194 <% tp.frontmatter.target_ip %> -oN <% tp.frontmatter.target_ip %>_udp_targeted.nmap -Pn
```

---

## Phase 4 — Vulnerability Scripts

### Run vuln scripts on all open ports
```bash
nmap --script=vuln -p$(cat <% tp.frontmatter.target_ip %>_ports.txt) <% tp.frontmatter.target_ip %> -oN <% tp.frontmatter.target_ip %>_vuln.nmap -Pn
```

### Default safe scripts
```bash
nmap -sC -p$(cat <% tp.frontmatter.target_ip %>_ports.txt) <% tp.frontmatter.target_ip %> -oN <% tp.frontmatter.target_ip %>_scripts.nmap -Pn
```

---

## Phase 5 — OS Fingerprinting

```bash
sudo nmap -O -p$(cat <% tp.frontmatter.target_ip %>_ports.txt) <% tp.frontmatter.target_ip %> -oN <% tp.frontmatter.target_ip %>_os.nmap -Pn
```

---

> [!tip] Next Step
> Copy the open port list into the `ports:` field in the frontmatter, then click the button below to load the Service Loader.

```meta-bind-button
style: primary
label: ⚙️ Load Service Loader
action:
  type: "replaceSelf"
  replacement: "Templates/service_loader.md"
  templater: true
```
