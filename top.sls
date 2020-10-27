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
    - nebula
    #- ntp
    - screen
    #- snmpd
    - ssh
    - sudo
    - sysctl
    - telegraf
    - timezone
    - tmux
    #- unattended-upgrades
    - vim
  'gw*':
    - fastd
    - dhcp-server
    - knot-resolver.remove
    - pdns-recursor
    - radvd
    - respondd
  'jvb*':
    - telegraf
    - jitsi.base
    - jitsi.videobridge
    - jitsi.jicofo
  'jibri*':
    - telegraf
    - jitsi.base
    - jitsi.jibri
  'dns01.in.ffmuc.net':
    - cloudflare
  'vpn0*.in.ffmuc.net':
    - wireguard
  '*.meet.ffmuc.net':
    - nebula.meet
