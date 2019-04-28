base:
  '*':
    # Site wide options
    - globals

    - net
    - nodes
    - sites
    - regions
    - cert

    # SSH authorized_keys configuration
    - ssh

    #
    # Role/Application specific stuff

    # Automatic Certificate Management
    - acme

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
