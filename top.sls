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
    - certs
    - docker
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
    - jitsi.jibri
    - jitsi.videobridge
  'jicofo*.meet.ffmuc.net':
    - jitsi.prosody
    - jitsi.jicofo
    - nginx
  'call*':
    - jitsi.asterisk
    - jisti.jigasi
  'gw*':
    - fastd
    - dhcp-server
    - knot-resolver.remove
    - pdns-recursor
    - radvd
    - respondd
  'webfrontend03.in.ffmuc.net':
    - cloudflare
  'webfrontend0[3-4].in.ffmuc.net':
    - dns-server/auth
  'vpn0*.in.ffmuc.net':
    - wireguard
