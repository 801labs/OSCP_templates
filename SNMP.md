# SNMP

Used to query OIDs with their information
```snmp
snmpwalk -v2c -c public <% tp.frontmatter.target_ip %> 1.3.6.1.2.1.1.5.0
```

```snmp
onesixtyone -c /usr/share/seclists/Discovery/SNMP/common-snmp-community-strings-onesixtyone.txt  <% tp.frontmatter.target_ip %>
```

