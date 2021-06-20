base:
  '*':
    # Site wide options
    - globals
    - network

    - net
    - nodes
    - sites
    - regions
    - cert
    - ssh

    #
    # Role/Application specific stuff

    # Automatic Certificate Management
    - acme

    # Burp backup
    - burp

    # Traffic engineering
    - te

    # DNS server
    - dns-server

    # OpenVPN tunnels
    - ovpn

    # Anycast Healthchecker
    - anycast-healthchecker

    # Frontend Config
    - frontend

    # Logging
    - logging

    # LDAP
    - ldap

    # Icinga2
    - monitoring
