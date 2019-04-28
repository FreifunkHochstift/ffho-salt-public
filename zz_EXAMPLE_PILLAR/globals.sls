# Global configuration items

globals:

  # Mail address of the operators of this fine backbone?
  ops_mail: "rootmail@ffho.net"

  # SNMP setting
  snmp:
    # read-only community string for snmpd
    ro_community: "not_public"

  # DNS settings
  dns:
    # IP address of DNS resolver for nodes (should be anycasted)
    resolver_v4: 10.132.251.53
    resolver_v6: 2a03:2260:2342:f251::53

    # Search domain
    search: in.ffho.net
