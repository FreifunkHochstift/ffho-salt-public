base:
  # Base config for all minions
  '*':
    - bash
    - fail2ban
    - ff_base
    - graylog-sidecar
    - locales
    - logrotate
    - mosh
    - motd
    - nebula
    - screen
    - sudo
    - sysctl
    - telegraf
    - timezone
    - tmux
    - unattended-upgrades
    - vim
  '*.in.ffmuc.net':
    - apt
    #- burp
    - certs
    - dns-server/auth
    - docker
    #- docker-containers
    - dphys-swapfile
    - duplicity
    - grafana
    - icinga2
    - influxdb
    - jenkins
    - kvm
    - ntp
    - snmpd
    - ssh
  '*.meet.ffmuc.net':
    - nebula-meet
    - jitsi.base
    - jitsi.prosody
    - jitsi.jicofo
    - jitsi.jibri
    - jitsi.videobridge
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
