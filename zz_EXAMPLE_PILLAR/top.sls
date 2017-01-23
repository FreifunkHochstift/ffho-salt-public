base:
  '*':
    - nodes
    - sites
    - cert
    - ffho

    #
    # Role/Application specific stuff

    # SSH authorized_keys configuration
    - ssh

    # Traffic engineering
    - te

    # DNS server
    - dns-server

    # OpenVPN tunnels
    - ovpn

    # Anycast Healthchecker
    - anycast-healthchecker
