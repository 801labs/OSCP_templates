window.buildQueryForTool = function ({ tool, domain, domainParts, base, filter, attributes, username = "", password = "" }) {
  switch (tool?.toLowerCase()) {
    case "ldapsearch":
      return `ldapsearch ${filter} --attributes ${attributes} --dn ${base} --hostname ${domain}`;
    case "impacket":
      if (!username || !password) return "[-] Missing credentials for Impacket";
      return `impacket-ldapsearch ${username}:${password}@${domain} -base "${base}" -filter "${filter}" -attributes ${attributes}`;
    case "powerview":
      return `Get-DomainObject -LDAPFilter "${filter}" -Domain ${domain} -Properties ${attributes}`;
    case "sharpldap":
      return `SharpLDAP.exe query -filter "${filter}" -attributes "${attributes}" -baseDN "${base}" -server ${domain}`;
    default:
      return `[-] Unknown tool: "${tool}"`;
  }
}
