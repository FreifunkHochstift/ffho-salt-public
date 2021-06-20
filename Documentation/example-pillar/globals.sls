# Global configuration items

globals:

  # Mail address of the operators of this fine backbone?
  ops_mail: "<ops mail address>"

  # SNMP setting
  snmp:
    # read-only community string for snmpd
    ro_community: "<community string>"

    # List of IPs allowed to query snmpd
    nms_list:
      - "<IPv4 / IPv6 address(es)>"

  # DNS settings
  dns:
    # IP address of DNS resolver for nodes (should be anycasted)
    resolver_v4: "<IPv4 address>"
    resolver_v6: "<IPv6 address>"

    # Search domain
    search: "<search domain>"

  # Salt (minion) configuration
  salt:
    master: "<salt master FQDN>"
    master_port: 4506
    ipv6: "<True / False>"
