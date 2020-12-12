base:
  # Base config for all minions
  '*':
    - fail2ban
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
    - bash
    #- burp
    - certs
    - dns-server/auth
    - docker
    #- docker-containers
    - dphys-swapfile
    - duplicity
    - ff_base
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
