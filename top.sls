base:
  # Base config for all minions
  '*':
    - apt
    - bash
    - burp
    - certs
    - dns-server/auth
    - docker
    #- docker-containers
    - dphys-swapfile
    - graylog-sidecar
    - fail2ban
    - ff_base
    - grafana
    - icinga2
    - influxdb
    - jenkins
    - locales
    - logrotate
    - kvm
    - mosh
    - motd
    - network
    - ntp
    - screen
    - snmpd
    - ssh
    - sudo
    - sysctl
    - timezone
    - tmux
    - unattended-upgrades
    - vim
  'gw*':
    - fastd
    - dhcp-server
    - knot-resolver.remove
    - pdns-recursor
    - radvd
    - respondd
  'dns01.in.ffmuc.net':
    - cloudflare
  'vpn0*.in.ffmuc.net':
    - wireguard
